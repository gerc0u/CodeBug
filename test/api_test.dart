import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debug_lab/data/api.dart';
import 'package:debug_lab/data/exercises.dart';
import 'package:debug_lab/models/progress.dart';
import 'package:debug_lab/main.dart';

Map<String, dynamic> profile({int xp = 0}) => {
  'id': 'user-1',
  'email': 'test@example.com',
  'name': 'Ученик',
  'xp': xp,
  'solved': xp > 0 ? ['one'] : [],
  'activity': {},
  'attempts': xp > 0 ? 1 : 0,
  'correct': xp > 0 ? 1 : 0,
  'read': [],
  'hinted': [],
};
final task = {
  'id': 'one',
  'language': 'Dart',
  'title': 'Test',
  'topic': 'Types',
  'level': 1,
  'minutes': 2,
  'description': 'Find bug',
  'code': ['bad();'],
  'hint': 'Look carefully',
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    exercises.clear();
  });
  test(
    'Server score and solution are authoritative; logout clears account data',
    () async {
      final client = MockClient((request) async {
        dynamic response;
        switch (request.url.path) {
          case '/api/auth/login':
            response = {'token': 'test-token', 'profile': profile()};
          case '/api/exercises':
            response = [task];
          case '/api/exercises/one/attempts':
            expect(request.headers['Authorization'], 'Bearer test-token');
            expect(
              jsonDecode(request.body).keys,
              unorderedEquals(['line', 'request_id']),
            );
            response = {
              'correct': true,
              'awarded_xp': 25,
              'profile': profile(xp: 25),
              'solution': {
                'errorLine': 1,
                'explanation': 'Server explanation',
                'correctedLine': 'good();',
              },
            };
          case '/api/auth/logout':
            return http.Response('', 204);
          default:
            throw StateError(request.url.toString());
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final store = ProgressStore(
        await SharedPreferences.getInstance(),
        api: CodeBugApi(client: client, baseUrl: 'http://test'),
      );
      await store.signIn('test@example.com', 'password');
      expect(exercises.single.errorLine, 0);
      expect(await store.answer(exercises.single, 1), true);
      expect(store.xp, 25);
      expect(exercises.single.explanation, 'Server explanation');
      expect(store.prefs.getString('progress_v1'), isNull);
      await store.logout();
      expect(store.authenticated, false);
      expect(store.solved, isEmpty);
      expect(exercises, isEmpty);
    },
  );
  test('Connection failure never awards XP and preserves request id on caller retry', () async {
    final ids = <String>[];
    final api = CodeBugApi(
      baseUrl: 'http://test',
      client: MockClient((r) async {
        ids.add(jsonDecode(r.body)['request_id']);
        throw http.ClientException('offline');
      }),
    );
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: api,
    );
    final e = Exercise.fromJson(task);
    final id = ProgressStore.newRequestId();
    for (var i = 0; i < 2; i++) {
      await expectLater(
        store.answer(e, 1, requestId: id),
        throwsA(isA<ApiException>()),
      );
    }
    expect(ids, [id, id]);
    expect(store.xp, 0);
    expect(store.solved, isEmpty);
  });
  test(
    'Failed sync survives server refresh and reset failure, then retries',
    () async {
      var unavailable = true;
      final store = ProgressStore(
        await SharedPreferences.getInstance(),
        api: CodeBugApi(
          baseUrl: 'http://test',
          client: MockClient((r) async {
            if (r.method == 'GET') {
              return http.Response(
                jsonEncode(profile()),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (unavailable) {
              return http.Response('{"detail":"Server unavailable"}', 503);
            }
            return http.Response(
              jsonEncode(profile()),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      store.authenticated = true;
      store.solved.add('one');
      store.read.add('Новый урок');
      store.name = 'Новое имя';
      await store.save();
      expect(store.saveFailed, true);
      await expectLater(store.reset(), throwsA(isA<ApiException>()));
      expect(store.solved, contains('one'));
      await store.refresh();
      expect(store.read, contains('Новый урок'));
      expect(store.name, 'Новое имя');
      expect(store.saveFailed, true);
      unavailable = false;
      await store.save();
      expect(store.saveFailed, false);
    },
  );
  testWidgets('Login screen validates inputs on small mobile layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: CodeBugApi(),
    );
    await tester.pumpWidget(DebugLabApp(store: store, showSplash: false));
    expect(find.text('Войти в аккаунт'), findsOneWidget);
    await tester.ensureVisible(find.text('Войти'));
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Укажи корректный email'), findsOneWidget);
    await tester.ensureVisible(find.text('Нет аккаунта? Создать'));
    await tester.tap(find.text('Нет аккаунта? Создать'));
    await tester.pumpAndSettle();
    final nameField = find.byKey(const ValueKey('registration-name'));
    expect(nameField, findsOneWidget);
    expect(
      find.descendant(
        of: nameField,
        matching: find.text('Укажи корректный email'),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Зарегистрироваться'));
    await tester.tap(find.text('Зарегистрироваться'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: nameField, matching: find.text('Укажи имя')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
