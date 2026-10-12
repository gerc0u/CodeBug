import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:debug_lab/data/anketa_file_io.dart' as files;
import 'package:debug_lab/models/anketa.dart';
import 'package:debug_lab/ui/anketa_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AnketaData example() => AnketaData.fromInput(
  name: ' Иван Иванов ',
  age: '25',
  email: 'ivan@mail.com ',
  phone: '+7 (700) 123-45-67',
);

void main() {
  test('All four fields reject invalid values and preserve valid text', () {
    for (final name in ['', '  ', 'Иван\nEmail: other@example.com']) {
      expect(AnketaData.validateName(name), isNotNull);
    }
    for (final age in ['', '-1', '0', '121', '2.5', 'abc']) {
      expect(AnketaData.validateAge(age), isNotNull);
    }
    for (final email in ['', 'mail', '@mail.com', 'a@b', 'a b@c.com']) {
      expect(AnketaData.validateEmail(email), isNotNull);
    }
    for (final phone in [
      '',
      '123',
      '+7700abc4567',
      '++77001234567',
      '+1234567890123456',
    ]) {
      expect(AnketaData.validatePhone(phone), isNotNull);
    }
    expect(
      example().toText(),
      'Имя: Иван Иванов\nВозраст: 25\nEmail: ivan@mail.com\nТелефон: +77001234567\n---\n',
    );
    expect(
      () => AnketaData.fromInput(
        name: '',
        age: '25',
        email: 'a@b.com',
        phone: '+77001234567',
      ),
      throwsFormatException,
    );
  });

  test(
    'Real UTF-8 anketa.txt appends records and survives reopening',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'codebug-anketa-test-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final folder = Directory('${temp.path}/documents');
      final first = example().toText();
      final second = AnketaData.fromInput(
        name: 'Анна',
        age: '19',
        email: 'anna@example.com',
        phone: '+77007654321',
      ).toText();
      final path = await files.saveText(first, directory: folder);
      expect(path.split(Platform.pathSeparator).last, 'anketa.txt');
      await files.saveText(second, directory: folder);
      expect(utf8.decode(await File(path).readAsBytes()), first + second);
      expect(
        await File(path).readAsString(encoding: utf8),
        contains('Телефон: +77001234567'),
      );
    },
  );

  test('File write errors reach the UI instead of reporting success', () async {
    final temp = await Directory.systemTemp.createTemp('codebug-anketa-error-');
    addTearDown(() => temp.delete(recursive: true));
    final blocker = File('${temp.path}/not-a-directory');
    await blocker.writeAsString('occupied');
    await expectLater(
      files.saveText(example().toText(), directory: Directory(blocker.path)),
      throwsA(isA<FileSystemException>()),
    );
  });

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget(find.byKey(const ValueKey('anketa-save')));

  testWidgets(
    'Save requires all valid fields, blocks duplicates, and clears prefilled fields',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final pending = Completer<String>();
      await tester.pumpWidget(
        MaterialApp(
          home: AnketaPage(
            initialName: 'Иван Иванов',
            initialEmail: 'ivan@mail.com',
            save: (data) {
              calls++;
              expect(data.phone, '+77001234567');
              return pending.future;
            },
          ),
        ),
      );
      expect(saveButton(tester).onPressed, isNull);
      await fill(tester, 'anketa-age', '25');
      await fill(tester, 'anketa-phone', '+77001234567');
      expect(saveButton(tester).onPressed, isNotNull);
      await fill(tester, 'anketa-email', 'wrong');
      expect(saveButton(tester).onPressed, isNull);
      await fill(tester, 'anketa-email', 'ivan@mail.com');
      await tester.ensureVisible(find.byKey(const ValueKey('anketa-save')));
      await tester.tap(find.byKey(const ValueKey('anketa-save')));
      await tester.pump();
      expect(calls, 1);
      expect(saveButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('anketa-name')))
            .enabled,
        isFalse,
      );
      pending.complete('/documents/anketa.txt');
      await tester.pumpAndSettle();
      expect(find.text('Данные успешно сохранены!'), findsWidgets);
      expect(find.text('/documents/anketa.txt'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('anketa-clear')));
      await tester.tap(find.byKey(const ValueKey('anketa-clear')));
      await tester.pumpAndSettle();
      for (final key in ['name', 'age', 'email', 'phone']) {
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey('anketa-$key')))
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(saveButton(tester).onPressed, isNull);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Failed save keeps entered values and permits retry at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AnketaPage(
          save: (_) async => throw const FileSystemException('No space'),
        ),
      ),
    );
    await fill(tester, 'anketa-name', 'Иван Иванов');
    await fill(tester, 'anketa-age', '25');
    await fill(tester, 'anketa-email', 'ivan@mail.com');
    await fill(tester, 'anketa-phone', '+77001234567');
    await tester.ensureVisible(find.byKey(const ValueKey('anketa-save')));
    await tester.tap(find.byKey(const ValueKey('anketa-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось сохранить файл'), findsOneWidget);
    expect(find.text('Данные успешно сохранены!'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('anketa-name')))
          .controller!
          .text,
      'Иван Иванов',
    );
    expect(saveButton(tester).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
