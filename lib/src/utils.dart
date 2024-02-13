import 'dart:convert';

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

  // Dart syntax doesn't allow expressions like `T == int?` because that conflicts with ternary operator syntax.
  // This is a workaround for that limitation (see also https://stackoverflow.com/a/73120173/8656352)
  static bool typesEqual<T, U>() => T == U;
}
