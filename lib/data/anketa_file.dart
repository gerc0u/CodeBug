import '../models/anketa.dart';
import 'anketa_file_io.dart'
    if (dart.library.js_interop) 'anketa_file_web.dart'
    as platform;

/// Returns a native absolute file path, or the browser's suggested filename.
Future<String> saveAnketa(AnketaData data) => platform.saveText(data.toText());
