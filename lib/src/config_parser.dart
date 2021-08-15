import 'dart:convert';

import 'package:dart_sdk/src/config.dart';
import 'package:dart_sdk/src/rollout_evaluator.dart';
import 'package:logging/logging.dart';

import 'config_cat_user.dart';

class ParserError implements Exception {
  String cause;
  ParserError(this.cause);
}

class ConfigParser {
  final Logger logger;
  final RolloutEvaluator evaluator;

  ConfigParser(this.logger, this.evaluator);

  Value parseValue<Value>(
      {required String key, required String json, ConfigCatUser? user = null}) {
    if (Value != String && Value != int && Value != double && Value != bool) {
      logger.severe('Only String, int, double or bool types can be parsed.');
      throw ParserError('Invalid Requested Type');
    }

    final jsonObject = _parseEntries(json: json);
    final value = evaluator.evaluate(jsonObject?[key], key, user)?.item1;

    if (value == null) {
      logger.severe('''
        Parsing the json value for the key $key failed
        Returning defaultValue.
        Here are the available keys: ${jsonObject?.keys}
      ''');
    } else {
      return value;
    }

    throw ParserError('Parse Failure');
  }

  static Map<String, dynamic>? _parseEntries({required String json}) {
    final jsonObject = jsonDecode(json);
    return jsonObject[Config.entries] as Map<String, dynamic>;
  }

  static Map<String, dynamic>? _parsePreferences({required String json}) {
    final jsonObject = jsonDecode(json);
    return jsonObject[Config.preferences] as Map<String, dynamic>;
  }
}
