
import 'dart:convert';

import '../configcat_client.dart';

class Utils{

  Utils._();

  static Config deserializeConfig(String configJson) {
    final decoded = jsonDecode(configJson);
    Config config = Config.fromJson(decoded);
    String salt = config.preferences.salt;
    if (salt.isEmpty) {
      throw ArgumentError("Config JSON salt is missing.");
    }
    List<Segment> segments = config.segments;

    for (Setting setting in config.entries.values) {
      setting.salt = salt;
      setting.segments = segments;
    }
    return config;
  }

}