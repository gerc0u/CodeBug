import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> saveText(String text) async {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'anketa.txt';
  try {
    web.document.body!.append(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    // Let the browser start reading the Blob before releasing its URL.
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }
  return 'anketa.txt';
}
