import 'dart:convert';

import '../log/configcat_logger.dart';
import 'config.dart';

class ConfigJsonCache {
  Config? config;
  final ConfigCatLogger logger;

  ConfigJsonCache(this.logger);

  Config? getConfigFromJson(String json) {
    if (json.isEmpty) {
      return null;
    }

    try {
      if (json == config?.jsonString) {
        return config;
      }

      final decoded = jsonDecode(json);
      config = Config.fromJson(decoded);
      config!.jsonString = json;

      return config;
    } catch (e, s) {
      logger.error("Config JSON parsing failed.", e, s);
      return null;
    }
  }
}
