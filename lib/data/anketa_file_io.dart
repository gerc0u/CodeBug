import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveText(String text, {Directory? directory}) async {
  final folder = directory ?? await getApplicationDocumentsDirectory();
  await folder.create(recursive: true);
  final file = File('${folder.path}${Platform.pathSeparator}anketa.txt');
  await file.writeAsString(
    text,
    mode: FileMode.append,
    encoding: utf8,
    flush: true,
  );
  return file.path;
}
