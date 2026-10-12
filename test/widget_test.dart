import 'package:flutter/material.dart';

import 'fixtures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:debug_lab/main.dart';
import 'package:debug_lab/models/progress.dart';
import 'package:debug_lab/data/exercises.dart';
import 'package:debug_lab/ui/exercise_page.dart';
import 'package:debug_lab/ui/library.dart';

void main() {
  late ProgressStore store;
  setUp(() async {
    exercises
      ..clear()
      ..addAll(fixtureExercises);
    SharedPreferences.setMockInitialValues({});
    store = ProgressStore(await SharedPreferences.getInstance());
  });
  test('Answer scoring, repeat protection and persistence', () async {
    final task = exercises.first;
    expect(await store.answer(task, 1), false);
    expect(store.xp, 0);
    expect(await store.answer(task, task.errorLine), true);
    expect(store.xp, task.xp);
    await store.answer(task, task.errorLine);
    expect(store.xp, task.xp);
    expect(store.todayCount, 1);
    expect(store.streak, 1);
    await store.save();
    final restored = ProgressStore(await SharedPreferences.getInstance());
    expect(restored.solved, contains(task.id));
    expect(restored.attempts, 3);
    expect(restored.correct, 2);
    await restored.reset();
    expect(restored.xp, 0);
    expect(restored.streak, 0);
  });
  test('Every exercise has a valid distinct replacement line', () {
    expect(exercises.map((e) => e.id).toSet().length, exercises.length);
    for (final e in exercises) {
      expect(e.errorLine, inInclusiveRange(1, e.code.length));
      expect(e.correctedCode[e.errorLine - 1], isNot(e.code[e.errorLine - 1]));
    }
  });
  testWidgets(
    'Mobile training: incorrect answer, hint, success and explanation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(DebugLabApp(store: store, showSplash: false));
      await tester.pumpAndSettle();
      expect(find.text('CodeBug'), findsOneWidget);
      await tester.tap(find.text('Начать тренировку'));
      await tester.pumpAndSettle();
      expect(find.byType(ExercisePage), findsOneWidget);
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('line-1'))) +
            const Offset(55, 22),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Проверить'));
      await tester.tap(find.text('Проверить'));
      await tester.pumpAndSettle();
      expect(store.xp, 0);
      expect(find.textContaining('Не совсем.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Подсказка'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Подсказка'));
      await tester.pumpAndSettle();
      expect(find.text('Небольшая подсказка'), findsOneWidget);
      await tester.tap(find.text('Попробую ещё'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('line-4')),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('line-4'))) +
            const Offset(55, 22),
      );
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.text('Проверить'));
      await tester.tap(find.text('Проверить'));
      await tester.pumpAndSettle();
      expect(find.text('Ошибка найдена!'), findsOneWidget);
      expect(store.xp, 25);
      await tester.tap(find.text('Посмотреть разбор'));
      await tester.pumpAndSettle();
      expect(find.text(exercises.first.explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Catalog search and empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CatalogPage(store: store)));
    await tester.enterText(find.byType(TextField), 'ничегонет');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не нашлось'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Лишний');
    await tester.pumpAndSettle();
    expect(find.text('Лишний шаг'), findsOneWidget);
  });
  testWidgets('Small and wide layouts do not overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(DebugLabApp(store: store, showSplash: false));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });
}
