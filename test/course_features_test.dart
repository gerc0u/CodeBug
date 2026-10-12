import 'dart:convert';
import 'dart:async';

import 'package:debug_lab/data/api.dart';
import 'package:debug_lab/data/exercises.dart';
import 'package:debug_lab/main.dart';
import 'package:debug_lab/models/notebook.dart';
import 'package:debug_lab/models/progress.dart';
import 'package:debug_lab/ui/library.dart';
import 'package:debug_lab/ui/notebook.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    exercises
      ..clear()
      ..addAll(fixtureExercises);
  });
  testWidgets('Splash appears once and leads to login', (tester) async {
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: CodeBugApi(),
    );
    await tester.pumpWidget(DebugLabApp(store: store));
    expect(find.text('CodeBug'), findsOneWidget);
    expect(find.text('Войти в аккаунт'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Войти в аккаунт'), findsOneWidget);
  });

  test(
    'Failed favorite request leaves state unchanged, then persists on retry',
    () async {
      var fails = true;
      final store = ProgressStore(
        await SharedPreferences.getInstance(),
        api: CodeBugApi(
          client: MockClient((r) async {
            expect(r.url.path, '/api/favorites/dart-index');
            expect(jsonDecode(r.body), {'saved': true});
            return fails
                ? json({'detail': 'Offline'}, 503)
                : json({'saved': true});
          }),
          baseUrl: 'http://test',
        ),
      );
      await expectLater(
        store.setFavorite('dart-index', true),
        throwsA(isA<ApiException>()),
      );
      expect(store.favorites, isEmpty);
      expect(store.savingFavorites, isEmpty);
      fails = false;
      await store.setFavorite('dart-index', true);
      expect(store.favorites, {'dart-index'});
    },
  );

  testWidgets('Favorites filter and reset work on 320px screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProgressStore(await SharedPreferences.getInstance());
    store.favorites.add(exercises.first.id);
    await tester.pumpWidget(
      MaterialApp(home: CatalogPage(store: store, favoritesOnly: true)),
    );
    expect(find.text('Найдено: 1'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('favorite-${exercises.first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Ничего не нашлось'), findsOneWidget);
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Найдено: ${exercises.length}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notes UI creates, reads, edits, confirms and deletes a note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = <String, Map<String, dynamic>>{};
    final client = MockClient((r) async {
      if (r.method == 'GET') return json(saved.values.toList());
      if (r.method == 'DELETE') {
        saved.remove(r.url.pathSegments.last);
        return http.Response('', 204);
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final id = data['id'] as String? ?? r.url.pathSegments.last;
      final note = {
        ...data,
        'id': id,
        'revision': (data['revision'] ?? 0) + 1,
        'created_at': 1700000000,
        'updated_at': 1700000000,
      };
      saved[id] = note;
      return json(note);
    });
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: CodeBugApi(client: client, baseUrl: 'http://test'),
    );
    await tester.pumpWidget(MaterialApp(home: NotesPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Здесь будут твои открытия'), findsOneWidget);
    await tester.tap(find.text('Новая заметка'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-title')),
      'Мой вывод',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Проверяй границы массива.',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить заметку'));
    await tester.tap(find.text('Сохранить заметку'));
    await tester.pumpAndSettle();
    expect(saved.length, 1);
    expect(find.text('Мой вывод'), findsOneWidget);
    await tester.tap(find.text('Мой вывод'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-body')),
      'Уточнённый вывод.',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить заметку'));
    await tester.tap(find.text('Сохранить заметку'));
    await tester.pumpAndSettle();
    expect(saved.values.single['revision'], 2);
    expect(find.text('Уточнённый вывод.'), findsOneWidget);
    await tester.tap(find.byTooltip('Удалить заметку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(saved.length, 1);
    await tester.tap(find.byTooltip('Удалить заметку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.text('Здесь будут твои открытия'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Failed note save preserves draft and back asks before discarding',
    (tester) async {
      final repo = Notebook(
        CodeBugApi(
          baseUrl: 'http://test',
          client: MockClient((_) async => json({'detail': 'Нет связи'}, 503)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoteEditor(repository: repo),
                  ),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Черновик',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-body')),
        'Не терять этот текст',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить заметку'));
      await tester.tap(find.text('Сохранить заметку'));
      await tester.pumpAndSettle();
      expect(find.text('Нет связи'), findsOneWidget);
      expect(find.text('Не терять этот текст'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Выйти без сохранения?'), findsOneWidget);
      await tester.tap(find.text('Продолжить редактирование'));
      await tester.pumpAndSettle();
      expect(find.text('Не терять этот текст'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Expired session removes private routes and returns to login', (
    tester,
  ) async {
    final api = CodeBugApi(
      baseUrl: 'http://test',
      client: MockClient((_) async => json({'detail': 'Войди заново'}, 401)),
    );
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: api,
    );
    store.authenticated = true;
    store.userId = 'one';
    api.token = 'expired';
    await tester.pumpWidget(DebugLabApp(store: store, showSplash: false));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('CodeBug'));
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => CatalogPage(store: store)),
    );
    await tester.pumpAndSettle();
    await expectLater(store.refresh(), throwsA(isA<ApiException>()));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogPage), findsNothing);
    expect(find.text('Войти в аккаунт'), findsOneWidget);
    expect(store.authenticated, false);
    expect(store.api!.token, isNull);
    expect(tester.takeException(), isNull);
  });
  test('Late response cannot restore data after changing account', () async {
    final response = Completer<http.Response>();
    final api = CodeBugApi(
      baseUrl: 'http://test',
      client: MockClient((_) => response.future),
    );
    api.token = 'old-token';
    final pending = api.request('GET', '/me');
    api.token = 'new-token';
    response.complete(json({'name': 'Previous account'}));
    await expectLater(pending, throwsA(isA<ApiException>()));
    expect(api.token, 'new-token');
  });

  testWidgets('History shows real results, filters and loads older attempts', (
    tester,
  ) async {
    final api = CodeBugApi(
      baseUrl: 'http://test',
      client: MockClient((r) async {
        final older = r.url.queryParameters['offset'] == '1';
        return json({
          'total': 2,
          'items': [
            {
              'id': older ? 'old' : 'new',
              'exercise_id': exercises.first.id,
              'title': older ? 'Старая попытка' : 'Новая попытка',
              'language': 'Dart',
              'line': older ? 1 : 4,
              'correct': !older,
              'awarded_xp': older ? 0 : 25,
              'created_at': 1700000000,
            },
          ],
        });
      }),
    );
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      api: api,
    );
    await tester.pumpWidget(MaterialApp(home: HistoryPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('+25 XP'), findsOneWidget);
    await tester.tap(find.text('Загрузить ещё'));
    await tester.pumpAndSettle();
    expect(find.text('Старая попытка'), findsOneWidget);
    await tester.tap(find.text('Ошибки'));
    await tester.pumpAndSettle();
    expect(find.text('Старая попытка'), findsOneWidget);
    expect(find.text('Новая попытка'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('All main screens fit narrow and wide layouts in both themes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ProgressStore(await SharedPreferences.getInstance());
    for (final dark in [true, false]) {
      store.dark = dark;
      for (final width in [320.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          DebugLabApp(
            key: ValueKey('$dark-$width'),
            store: store,
            showSplash: false,
          ),
        );
        await tester.pumpAndSettle();
        for (final tab in ['Теория', 'Рейтинг', 'Профиль', 'Тренажёр']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab, width=$width, dark=$dark',
          );
        }
      }
    }
  });
}
