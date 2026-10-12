"""CodeBug API. Run: uvicorn app:app --host 127.0.0.1 --port 8000."""
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Request, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field, field_validator

ROOT = Path(__file__).resolve().parent
SCHEMA = """
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS users (
 id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
 password_hash TEXT NOT NULL, salt TEXT NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sessions (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 expires_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS exercises (id TEXT PRIMARY KEY, data TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS attempts (
 user_id TEXT NOT NULL REFERENCES users(id), request_id TEXT NOT NULL,
 exercise_id TEXT NOT NULL REFERENCES exercises(id), line INTEGER NOT NULL,
 correct INTEGER NOT NULL, awarded INTEGER NOT NULL, created_at INTEGER NOT NULL,
 PRIMARY KEY(user_id, request_id));
CREATE TABLE IF NOT EXISTS completions (
 user_id TEXT NOT NULL REFERENCES users(id), exercise_id TEXT NOT NULL REFERENCES exercises(id),
 xp INTEGER NOT NULL, day TEXT NOT NULL, PRIMARY KEY(user_id, exercise_id));
CREATE TABLE IF NOT EXISTS marks (
 user_id TEXT NOT NULL REFERENCES users(id), kind TEXT NOT NULL, value TEXT NOT NULL,
 PRIMARY KEY(user_id, kind, value));
CREATE TABLE IF NOT EXISTS auth_limits (
 ip TEXT PRIMARY KEY, window INTEGER NOT NULL, count INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS favorites (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 exercise_id TEXT NOT NULL REFERENCES exercises(id), PRIMARY KEY(user_id, exercise_id));
CREATE TABLE IF NOT EXISTS notes (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 exercise_id TEXT REFERENCES exercises(id), title TEXT NOT NULL, body TEXT NOT NULL,
 revision INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS notes_owner ON notes(user_id, updated_at);
CREATE INDEX IF NOT EXISTS attempts_history ON attempts(user_id, created_at);
PRAGMA user_version=2;
"""


class Payload(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)


class Credentials(Payload):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)

    @field_validator('email')
    @classmethod
    def email_address(cls, value):
        value = value.strip().lower()
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', value):
            raise ValueError('Укажи корректный email')
        return value


class Registration(Credentials):
    name: str = Field(min_length=1, max_length=24)

    @field_validator('name')
    @classmethod
    def nonempty(cls, value):
        if not value.strip():
            raise ValueError('Укажи имя')
        return value.strip()


class Profile(Payload):
    name: str = Field(min_length=1, max_length=24)
    read: list[str] = Field(max_length=100)
    hinted: list[str] = Field(max_length=100)

    _name = field_validator('name')(Registration.nonempty.__func__)


class Answer(Payload):
    line: int = Field(ge=1, le=10000)
    request_id: str = Field(min_length=16, max_length=80, pattern=r'^[a-zA-Z0-9-]+$')


class Favorite(Payload):
    saved: bool


class NoteContent(Payload):
    title: str = Field(min_length=1, max_length=80)
    body: str = Field(min_length=1, max_length=4000)
    exercise_id: str | None = Field(default=None, max_length=80)

    @field_validator('title', 'body')
    @classmethod
    def nonempty(cls, value):
        value = value.strip()
        if not value or '\x00' in value:
            raise ValueError('Заполни заголовок и текст заметки')
        return value


class NewNote(NoteContent):
    id: str = Field(min_length=16, max_length=80, pattern=r'^[a-zA-Z0-9-]+$')


class EditNote(NoteContent):
    revision: int = Field(ge=1)


def password_hash(password, salt):
    return hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt),
                          n=32768, r=8, p=1, maxmem=64 * 1024 * 1024).hex()


def create_app(db_path=None, web_dir=None):
    database = Path(db_path or os.environ.get('CODEBUG_DB', ROOT / 'data/codebug.sqlite3'))
    database.parent.mkdir(parents=True, exist_ok=True)

    @contextmanager
    def db():
        connection = sqlite3.connect(database, timeout=15)
        connection.row_factory = sqlite3.Row
        connection.execute('PRAGMA foreign_keys=ON')
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    seed = json.loads((ROOT / 'seed.json').read_text())
    with db() as c:
        c.executescript(SCHEMA)
        for e in seed['exercises']:
            c.execute('INSERT OR IGNORE INTO exercises VALUES (?,?)', (e['id'], json.dumps(e)))
    os.chmod(database, 0o600)
    api = FastAPI(title='CodeBug API', version='3.0.0', description='Учебный тренажёр: аккаунты, задания, серверная проверка, прогресс и рейтинг.')
    api.add_middleware(CORSMiddleware,
        allow_origins=os.environ.get('CODEBUG_ORIGINS', 'http://127.0.0.1:8765,http://localhost:8765,http://127.0.0.1:8000,http://localhost:8000').split(','),
        allow_methods=['GET', 'POST', 'PATCH', 'DELETE'], allow_headers=['Authorization', 'Content-Type'])
    bearer = HTTPBearer(auto_error=False)

    @api.middleware('http')
    async def headers(request, call_next):
        if len(await request.body()) > 65536:
            from fastapi.responses import JSONResponse
            return JSONResponse({'detail': 'Слишком большой запрос'}, status_code=413)
        response = await call_next(request)
        response.headers['X-Content-Type-Options'] = 'nosniff'
        if request.url.path.startswith('/api'):
            response.headers['Cache-Control'] = 'no-store'
        return response

    def user(auth: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        digest = hashlib.sha256(auth.credentials.encode()).hexdigest() if auth else ''
        with db() as c:
            row = c.execute('SELECT u.* FROM users u JOIN sessions s ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>?', (digest, int(time.time()))).fetchone()
        if row is None:
            raise HTTPException(401, 'Войди в аккаунт заново', headers={'WWW-Authenticate': 'Bearer'})
        return dict(row)

    def throttle(request):
        ip = request.client.host if request.client else 'unknown'
        now = int(time.time())
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            c.execute('DELETE FROM auth_limits WHERE window<?', (now - 900,))
            c.execute('INSERT INTO auth_limits VALUES (?,?,1) ON CONFLICT(ip) DO UPDATE SET count=count+1', (ip, now))
            count = c.execute('SELECT count FROM auth_limits WHERE ip=?', (ip,)).fetchone()[0]
        if count > 40:
            raise HTTPException(429, 'Слишком много попыток входа. Повтори через 15 минут.', headers={'Retry-After': '900'})

    def snapshot(c, uid):
        row = c.execute('SELECT id,email,name FROM users WHERE id=?', (uid,)).fetchone()
        completions = c.execute('SELECT * FROM completions WHERE user_id=?', (uid,)).fetchall()
        counts = c.execute('SELECT COUNT(*),COALESCE(SUM(correct),0) FROM attempts WHERE user_id=?', (uid,)).fetchone()
        marks = c.execute('SELECT kind,value FROM marks WHERE user_id=?', (uid,)).fetchall()
        activity = {}
        for e in completions:
            activity[e['day']] = activity.get(e['day'], 0) + 1
        return {**dict(row), 'solved': [e['exercise_id'] for e in completions],
            'xp': sum(e['xp'] for e in completions), 'attempts': counts[0], 'correct': counts[1],
            'activity': activity, 'read': [m['value'] for m in marks if m['kind'] == 'read'],
            'hinted': [m['value'] for m in marks if m['kind'] == 'hinted'],
            'favorites': [r[0] for r in c.execute('SELECT exercise_id FROM favorites WHERE user_id=?', (uid,))]}

    def session(c, uid):
        token = secrets.token_urlsafe(32)
        c.execute('DELETE FROM sessions WHERE expires_at<=?', (int(time.time()),))
        c.execute('INSERT INTO sessions VALUES (?,?,?)', (hashlib.sha256(token.encode()).hexdigest(), uid, int(time.time()) + 7 * 86400))
        return {'token': token, 'profile': snapshot(c, uid)}

    def exercise(c, eid):
        row = c.execute('SELECT data FROM exercises WHERE id=?', (eid,)).fetchone()
        if not row:
            raise HTTPException(404, 'Задание не найдено')
        return json.loads(row['data'])

    @api.get('/api/health')
    def health():
        with db() as c:
            c.execute('SELECT 1').fetchone()
        return {'status': 'ok', 'version': '3.0.0'}

    @api.post('/api/auth/register', status_code=201)
    def register(body: Registration, request: Request):
        throttle(request)
        uid, salt = secrets.token_hex(16), secrets.token_hex(16)
        hashed = password_hash(body.password, salt)
        with db() as c:
            try:
                c.execute('INSERT INTO users VALUES (?,?,?,?,?,?)', (uid, body.email, body.name, hashed, salt, int(time.time())))
            except sqlite3.IntegrityError:
                raise HTTPException(409, 'Этот email уже зарегистрирован')
            return session(c, uid)

    @api.post('/api/auth/login')
    def login(body: Credentials, request: Request):
        throttle(request)
        with db() as c:
            row = c.execute('SELECT * FROM users WHERE email=?', (body.email,)).fetchone()
            salt = row['salt'] if row else '00' * 16
            hashed = password_hash(body.password, salt)
            if row is None or not hmac.compare_digest(row['password_hash'], hashed):
                raise HTTPException(401, 'Неверный email или пароль')
            return session(c, row['id'])

    @api.post('/api/auth/logout', status_code=204)
    def logout(auth: Annotated[HTTPAuthorizationCredentials, Depends(bearer)], current=Depends(user)):
        with db() as c:
            c.execute('DELETE FROM sessions WHERE token_hash=?', (hashlib.sha256(auth.credentials.encode()).hexdigest(),))

    @api.get('/api/me')
    def me(current=Depends(user)):
        with db() as c:
            return snapshot(c, current['id'])

    @api.patch('/api/me')
    def update(body: Profile, current=Depends(user)):
        if not set(body.read) <= set(seed['lessons']):
            raise HTTPException(422, 'Неизвестный урок')
        with db() as c:
            ids = {r[0] for r in c.execute('SELECT id FROM exercises')}
            if not set(body.hinted) <= ids:
                raise HTTPException(422, 'Неизвестное задание')
            c.execute('UPDATE users SET name=? WHERE id=?', (body.name, current['id']))
            # Marks merge across devices; only explicit reset removes them.
            for kind, values in [('read', body.read), ('hinted', body.hinted)]:
                c.executemany('INSERT OR IGNORE INTO marks VALUES (?,?,?)', [(current['id'], kind, v) for v in values])
            return snapshot(c, current['id'])

    @api.delete('/api/me/progress')
    def reset(current=Depends(user)):
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            for table in ['attempts', 'completions', 'marks']:
                c.execute(f'DELETE FROM {table} WHERE user_id=?', (current['id'],))
            return snapshot(c, current['id'])

    @api.get('/api/exercises')
    def catalog(current=Depends(user)):
        with db() as c:
            return [{k: v for k, v in json.loads(row[0]).items() if k not in ['errorLine', 'explanation', 'correctedLine']}
                    for row in c.execute('SELECT data FROM exercises ORDER BY rowid')]

    @api.post('/api/exercises/{eid}/attempts')
    def attempt(eid: str, body: Answer, current=Depends(user)):
        uid = current['id']
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            e = exercise(c, eid)
            if body.line > len(e['code']):
                raise HTTPException(422, 'Такой строки нет в задании')
            old = c.execute('SELECT * FROM attempts WHERE user_id=? AND request_id=?', (uid, body.request_id)).fetchone()
            if old:
                if old['exercise_id'] != eid or old['line'] != body.line:
                    raise HTTPException(409, 'Идентификатор запроса уже использован')
                correct, awarded = bool(old['correct']), old['awarded']
            else:
                correct = body.line == e['errorLine']
                awarded = 0
                if correct:
                    inserted = c.execute('INSERT OR IGNORE INTO completions VALUES (?,?,?,?)',
                        (uid, eid, e['xp'], datetime.now(timezone.utc).date().isoformat())).rowcount
                    awarded = e['xp'] if inserted else 0
                c.execute('INSERT INTO attempts VALUES (?,?,?,?,?,?,?)',
                    (uid, body.request_id, eid, body.line, int(correct), awarded, int(time.time())))
            result = {'correct': correct, 'awarded_xp': awarded, 'profile': snapshot(c, uid)}
            if correct:
                result['solution'] = {k: e[k] for k in ['errorLine', 'explanation', 'correctedLine']}
            return result

    @api.patch('/api/favorites/{eid}')
    def favorite(eid: str, body: Favorite, current=Depends(user)):
        with db() as c:
            exercise(c, eid)
            if body.saved:
                c.execute('INSERT OR IGNORE INTO favorites VALUES (?,?)', (current['id'], eid))
            else:
                c.execute('DELETE FROM favorites WHERE user_id=? AND exercise_id=?', (current['id'], eid))
        return {'exercise_id': eid, 'saved': body.saved}

    @api.get('/api/notes')
    def notes(current=Depends(user)):
        with db() as c:
            return [dict(r) for r in c.execute(
                'SELECT id,exercise_id,title,body,revision,created_at,updated_at FROM notes WHERE user_id=? ORDER BY updated_at DESC,id', (current['id'],))]

    @api.post('/api/notes', status_code=201)
    def create_note(body: NewNote, current=Depends(user)):
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            if body.exercise_id is not None:
                exercise(c, body.exercise_id)
            old = c.execute('SELECT * FROM notes WHERE id=?', (body.id,)).fetchone()
            if old:
                if old['user_id'] != current['id'] or any(old[k] != getattr(body, k) for k in ['title', 'body', 'exercise_id']):
                    raise HTTPException(409, 'Идентификатор заметки уже использован')
            else:
                if c.execute('SELECT COUNT(*) FROM notes WHERE user_id=?', (current['id'],)).fetchone()[0] >= 200:
                    raise HTTPException(409, 'Достигнут лимит 200 заметок. Удали ненужные записи.')
                now = int(time.time())
                c.execute('INSERT INTO notes VALUES (?,?,?,?,?,1,?,?)',
                    (body.id, current['id'], body.exercise_id, body.title, body.body, now, now))
            return dict(c.execute('SELECT id,exercise_id,title,body,revision,created_at,updated_at FROM notes WHERE id=?', (body.id,)).fetchone())

    @api.patch('/api/notes/{nid}')
    def edit_note(nid: str, body: EditNote, current=Depends(user)):
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            old = c.execute('SELECT * FROM notes WHERE id=? AND user_id=?', (nid, current['id'])).fetchone()
            if not old:
                raise HTTPException(404, 'Заметка не найдена')
            if old['revision'] != body.revision:
                raise HTTPException(409, 'Заметка изменена на другом устройстве. Скопируй свой текст и открой заметку заново.')
            if body.exercise_id is not None:
                exercise(c, body.exercise_id)
            c.execute('UPDATE notes SET title=?,body=?,exercise_id=?,revision=revision+1,updated_at=? WHERE id=? AND user_id=?',
                (body.title, body.body, body.exercise_id, int(time.time()), nid, current['id']))
            return dict(c.execute('SELECT id,exercise_id,title,body,revision,created_at,updated_at FROM notes WHERE id=?', (nid,)).fetchone())

    @api.delete('/api/notes/{nid}', status_code=204)
    def delete_note(nid: str, revision: Annotated[int, Query(ge=1)], current=Depends(user)):
        with db() as c:
            c.execute('BEGIN IMMEDIATE')
            row = c.execute('SELECT revision FROM notes WHERE id=? AND user_id=?', (nid, current['id'])).fetchone()
            if not row:
                raise HTTPException(404, 'Заметка не найдена')
            if row['revision'] != revision:
                raise HTTPException(409, 'Заметка изменилась. Обнови список перед удалением.')
            c.execute('DELETE FROM notes WHERE id=? AND user_id=?', (nid, current['id']))

    @api.get('/api/history')
    def history(offset: Annotated[int, Query(ge=0)] = 0,
                limit: Annotated[int, Query(ge=1, le=100)] = 30, current=Depends(user)):
        with db() as c:
            total = c.execute('SELECT COUNT(*) FROM attempts WHERE user_id=?', (current['id'],)).fetchone()[0]
            rows = c.execute('SELECT a.*,e.data FROM attempts a JOIN exercises e ON e.id=a.exercise_id WHERE a.user_id=? ORDER BY a.created_at DESC,a.rowid DESC LIMIT ? OFFSET ?',
                (current['id'], limit, offset)).fetchall()
            items = []
            for r in rows:
                e = json.loads(r['data'])
                items.append({'id': r['request_id'], 'exercise_id': r['exercise_id'], 'title': e['title'],
                    'language': e['language'], 'line': r['line'], 'correct': bool(r['correct']),
                    'awarded_xp': r['awarded'], 'created_at': r['created_at']})
            return {'items': items, 'total': total}

    @api.get('/api/leaderboard')
    def leaderboard(current=Depends(user)):
        with db() as c:
            rows = c.execute('SELECT u.id,u.name,COALESCE(SUM(c.xp),0) AS xp FROM users u LEFT JOIN completions c ON c.user_id=u.id GROUP BY u.id ORDER BY xp DESC,u.created_at,u.id LIMIT 50').fetchall()
            return [{'name': r['name'], 'xp': r['xp'], 'you': r['id'] == current['id']} for r in rows]

    static = Path(web_dir) if web_dir else ROOT.parent / 'build/web'
    if static.is_dir():
        api.mount('/', StaticFiles(directory=static, html=True), name='web')
    return api


app = create_app()
