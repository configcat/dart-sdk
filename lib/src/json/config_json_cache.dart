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
      if (json == this.config?.jsonString) {
        return this.config;
      }

      final decoded = jsonDecode(json);
      this.config = Config.fromJson(decoded);
      this.config!.jsonString = json;

      return this.config;
    } catch (e, s) {
      this.logger.error("Config JSON parsing failed.", e, s);
      return null;
    }
  }
}
