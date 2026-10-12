from concurrent.futures import ThreadPoolExecutor
import sqlite3
import uuid
import pytest
from fastapi.testclient import TestClient
from app import create_app

@pytest.fixture
def env(tmp_path):
    path = tmp_path / 'test.sqlite3'
    with TestClient(create_app(path)) as client:
        yield client, path

def register(c, email='learner@example.com'):
    r = c.post('/api/auth/register', json={'email': email, 'password': 'Password-123', 'name': 'Ученик'})
    assert r.status_code == 201, r.text
    return {'Authorization': 'Bearer ' + r.json()['token']}

def answer(c, h, line=4, rid=None):
    return c.post('/api/exercises/dart-index/attempts', headers=h, json={'line': line, 'request_id': rid or uuid.uuid4().hex})

def test_auth_validation_and_logout(env):
    c, path = env
    assert c.get('/api/me').status_code == 401
    assert c.post('/api/auth/register', json={'email':'bad', 'name':' ', 'password':'123'}).status_code == 422
    h = register(c)
    assert c.post('/api/auth/register', json={'email':'LEARNER@example.com', 'name':'Name', 'password':'Password-123'}).status_code == 409
    assert c.post('/api/auth/login', json={'email':'learner@example.com', 'password':'wrong-password'}).status_code == 401
    with sqlite3.connect(path) as db:
        row = db.execute('SELECT password_hash,salt FROM users').fetchone()
        assert 'Password-123' not in row
        assert db.execute('SELECT token_hash FROM sessions').fetchone()[0] != h['Authorization'].split()[1]
    assert c.post('/api/auth/logout', headers=h).status_code == 204
    assert c.get('/api/me', headers=h).status_code == 401

def test_catalog_no_solution_and_server_scoring(env):
    c, _ = env; h = register(c)
    catalog = c.get('/api/exercises', headers=h).json()
    assert len(catalog) == 12
    for e in catalog:
        assert not {'errorLine','explanation','correctedLine'} & e.keys()
    bad = answer(c, h, 1).json()
    assert not bad['correct'] and 'solution' not in bad and bad['profile']['xp'] == 0
    good = answer(c, h).json()
    assert good['correct'] and good['solution']['errorLine'] == 4 and good['awarded_xp'] == 25
    repeat = answer(c, h).json()
    assert repeat['awarded_xp'] == 0 and repeat['profile']['xp'] == 25
    assert repeat['profile']['attempts'] == 3 and repeat['profile']['correct'] == 2
    assert answer(c, h, 999).status_code == 422
    assert c.patch('/api/me', headers=h, json={'name':'Ученик','read':[],'hinted':[], 'xp':999999}).status_code == 422

def test_idempotency_and_concurrent_awards(env):
    c, _ = env; h = register(c); rid = uuid.uuid4().hex
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(lambda _: answer(c, h, rid=rid), range(6)))
    assert all(r.status_code == 200 for r in results)
    assert c.get('/api/me', headers=h).json()['attempts'] == 1
    assert answer(c, h, line=1, rid=rid).status_code == 409
    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(lambda _: answer(c, h), range(6)))
    me = c.get('/api/me', headers=h).json()
    assert me['xp'] == 25 and len(me['solved']) == 1 and me['attempts'] == 7

def test_cross_device_isolation_restart_and_reset(env):
    c, path = env; h = register(c); second = register(c, 'other@example.com')
    answer(c, h)
    r = c.post('/api/auth/login', json={'email':'learner@example.com','password':'Password-123'})
    another = {'Authorization': 'Bearer ' + r.json()['token']}
    assert c.get('/api/me', headers=another).json()['xp'] == 25
    assert c.get('/api/me', headers=second).json()['xp'] == 0
    board = c.get('/api/leaderboard', headers=h).json()
    assert board[0]['xp'] == 25 and board[0]['you']
    assert all('email' not in e for e in board)
    with TestClient(create_app(path)) as restarted:
        assert restarted.get('/api/me', headers=another).json()['xp'] == 25
    reset = c.delete('/api/me/progress', headers=another).json()
    assert reset['xp'] == 0 and reset['attempts'] == 0 and reset['read'] == []
    assert c.get('/api/me', headers=h).json()['xp'] == 0

def test_marks_merge_validation_and_expiration(env):
    c, path = env; h = register(c)
    assert c.patch('/api/me', headers=h, json={'name':'New', 'read':['unknown'], 'hinted':[]}).status_code == 422
    assert c.patch('/api/me', headers=h, json={'name':' ', 'read':[], 'hinted':[]}).status_code == 422
    assert c.patch('/api/me', headers=h, json={'name':'New', 'read':[], 'hinted':['dart-index']}).status_code == 200
    assert c.patch('/api/me', headers=h, json={'name':'New', 'read':[], 'hinted':[]}).json()['hinted'] == ['dart-index']
    with sqlite3.connect(path) as db:
        db.execute('UPDATE sessions SET expires_at=0')
    assert c.get('/api/me', headers=h).status_code == 401

def test_rate_limit_and_cors(env):
    c, path = env
    with sqlite3.connect(path) as db:
        import time
        db.execute('INSERT INTO auth_limits VALUES (?,?,40)', ('testclient', int(time.time())))
    assert c.post('/api/auth/login', json={'email':'a@example.com','password':'password'}).status_code == 429
    r = c.options('/api/me', headers={'Origin':'http://127.0.0.1:8765','Access-Control-Request-Method':'GET','Access-Control-Request-Headers':'authorization'})
    assert r.status_code == 200
    r = c.options('/api/me', headers={'Origin':'https://untrusted.example','Access-Control-Request-Method':'GET'})
    assert r.status_code == 400


def test_favorites_persist_isolate_and_survive_progress_reset(env):
    c, path = env
    h = register(c)
    other = register(c, 'private@example.com')
    url = '/api/favorites/dart-index'
    assert c.patch(url, json={'saved': True}).status_code == 401
    for _ in range(2):
        assert c.patch(url, headers=h, json={'saved': True}).json()['saved'] is True
    assert c.get('/api/me', headers=h).json()['favorites'] == ['dart-index']
    assert c.get('/api/me', headers=other).json()['favorites'] == []
    assert c.patch('/api/favorites/missing', headers=h, json={'saved': True}).status_code == 404
    assert c.patch(url, headers=h, json={'saved': 'yes'}).status_code == 422
    assert c.delete('/api/me/progress', headers=h).json()['favorites'] == ['dart-index']
    with TestClient(create_app(path)) as restarted:
        assert restarted.get('/api/me', headers=h).json()['favorites'] == ['dart-index']
    assert c.patch(url, headers=h, json={'saved': False}).status_code == 200
    assert c.get('/api/me', headers=h).json()['favorites'] == []


def test_note_crud_owner_isolation_validation_conflicts_and_restart(env):
    c, path = env
    h = register(c)
    other = register(c, 'private@example.com')
    body = {'id': uuid.uuid4().hex, 'title': '  Границы массива  ', 'body': 'Индекс должен быть меньше длины.', 'exercise_id': 'dart-index'}
    assert c.get('/api/notes').status_code == 401
    for field in ['title', 'body']:
        assert c.post('/api/notes', headers=h, json={**body, field: '  '}).status_code == 422
    assert c.post('/api/notes', headers=h, json={**body, 'exercise_id':'unknown'}).status_code == 404
    assert c.post('/api/notes', headers=h, json={**body, 'user_id':'another'}).status_code == 422
    response = c.post('/api/notes', headers=h, json=body)
    assert response.status_code == 201
    note = response.json()
    assert note['title'] == 'Границы массива' and note['revision'] == 1
    # A retried creation with the same id cannot duplicate the note.
    assert c.post('/api/notes', headers=h, json=body).json()['id'] == note['id']
    assert len(c.get('/api/notes', headers=h).json()) == 1
    assert c.get('/api/notes', headers=other).json() == []
    changes = {'title':'Исправлено', 'body':'Новый текст', 'exercise_id':None, 'revision':1}
    url = '/api/notes/' + note['id']
    assert c.patch(url, headers=other, json=changes).status_code == 404
    assert c.delete(url+'?revision=1', headers=other).status_code == 404
    assert c.post('/api/notes', headers=other, json=body).status_code == 409
    assert c.patch(url, headers=h, json=changes).json()['revision'] == 2
    assert c.patch(url, headers=h, json=changes).status_code == 409
    assert c.delete(url+'?revision=1', headers=h).status_code == 409
    c.delete('/api/me/progress', headers=h)
    with TestClient(create_app(path)) as restarted:
        persisted = restarted.get('/api/notes', headers=h).json()[0]
        assert persisted['title'] == 'Исправлено' and persisted['body'] == 'Новый текст'
    assert c.delete(url+'?revision=2', headers=h).status_code == 204
    assert c.get('/api/notes', headers=h).json() == []


def test_history_order_paging_isolation_and_no_answers(env):
    c, _ = env
    h = register(c)
    other = register(c, 'private@example.com')
    first, second, third = [uuid.uuid4().hex for _ in range(3)]
    answer(c, h, 1, first)
    answer(c, h, 4, second)
    answer(c, h, 4, third)
    answer(c, h, 4, third)
    assert c.get('/api/history').status_code == 401
    page = c.get('/api/history?limit=2', headers=h).json()
    assert page['total'] == 3
    assert [r['id'] for r in page['items']] == [third, second]
    assert [r['awarded_xp'] for r in page['items']] == [0, 25]
    assert all(not {'explanation', 'errorLine', 'data', 'user_id'} & r.keys() for r in page['items'])
    older = c.get('/api/history?offset=2', headers=h).json()['items'][0]
    assert older['id'] == first and older['correct'] is False and older['line'] == 1
    assert c.get('/api/history', headers=other).json()['total'] == 0
    assert c.get('/api/history?limit=500', headers=h).status_code == 422
    assert c.get('/api/history?offset=-1', headers=h).status_code == 422
    c.delete('/api/me/progress', headers=h)
    assert c.get('/api/history', headers=h).json() == {'items':[], 'total':0}


def test_migration_keeps_existing_accounts_and_long_unicode_note(env):
    c, path = env
    h = register(c)
    answer(c, h)
    with sqlite3.connect(path) as db:
        db.executescript('DROP TABLE favorites; DROP TABLE notes; PRAGMA user_version=1;')
    with TestClient(create_app(path)) as migrated:
        assert migrated.get('/api/me', headers=h).json()['xp'] == 25
        body = {'id':uuid.uuid4().hex, 'title':'Кириллица', 'body':'Я' * 4000}
        r = migrated.post('/api/notes', headers=h, json=body)
        assert r.status_code == 201, r.text
        assert migrated.get('/api/notes', headers=h).json()[0]['body'] == body['body']
        assert migrated.get('/api/health').json()['version'] == '3.0.0'
