import 'dart:convert';
import 'dart:io';

import '../configcat_client.dart';

class Utils {
  Utils._();

  static Config deserializeConfig(String configJson) {
    final decoded = jsonDecode(configJson);
    Config config = Config.fromJson(decoded);
    String? salt = config.preferences.salt;
    List<Segment> segments = config.segments;

    for (Setting setting in config.entries.values) {
      setting.salt = salt;
      setting.segments = segments;
    }
    return config;
  }

  // Copy of the implementation of `Platform.lineTerminator`, which is available only since Dart 3.2.0 (see also https://stackoverflow.com/a/77295824/8656352)
  @pragma("vm:platform-const")
  static String get lineTerminator => Platform.isWindows ? '\r\n' : '\n';

  // Dart syntax doesn't allow expressions like `T == int?` because that conflicts with ternary operator syntax.
  // This is a workaround for that limitation (see also https://stackoverflow.com/a/73120173/8656352)
  static bool typesEqual<T, U>() => T == U;
}
