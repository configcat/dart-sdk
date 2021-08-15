import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:tuple/tuple.dart';
import 'package:version/version.dart';

import 'config.dart';
import 'config_cat_user.dart';

extension VersionString on String {
  Version? toVersion() {
    try {
      return Version.parse(this);
    } catch (_) {
      return null;
    }
  }
}

class RolloutEvaluator {
  static const comparatorTexts = [
    "IS ONE OF",
    "IS NOT ONE OF",
    "CONTAINS",
    "DOES NOT CONTAIN",
    "IS ONE OF (SemVer)",
    "IS NOT ONE OF (SemVer)",
    "< (SemVer)",
    "<= (SemVer)",
    "> (SemVer)",
    ">= (SemVer)",
    "= (Number)",
    "<> (Number)",
    "< (Number)",
    "<= (Number)",
    "> (Number)",
    ">= (Number",
    "IS ONE OF (Sensitive)",
    "IS NOT ONE OF (Sensitive)",
  ];

  final Logger logger;

  RolloutEvaluator({required this.logger});

  Tuple2<Value, String>? evaluate<Value>(
      Map<String, dynamic> json, String key, ConfigCatUser? user) {
    final rolloutRules =
        json[Config.rolloutRules] as List<Map<String, dynamic>>;
    final rolloutPercentageItems =
        json[Config.rolloutPercentageItems] as List<Map<String, dynamic>>;

    if (user == null) {
      if (rolloutRules.length > 0 || rolloutPercentageItems.length > 0) {
        logger.warning('''
                    Evaluating getValue($key). UserObject missing!
                    You should pass a UserObject to get_value(),
                    in order to make targeting work properly.
                    Read more: https://configcat.com/docs/advanced/user-object/
                    ''');
      }
      return Tuple2(json[Config.value], json[Config.variationId]);
    }

    logger.info('User object: $user');

    for (final rule in rolloutRules) {
      final comparisonAttribute = rule[Config.comparisonAttribute] as String;
      final comparisonValue = rule[Config.comparisonValue] as String;
      final comparator = rule[Config.comparator] as int;
      final userValue = user.getAttribute(key: comparisonAttribute);

      if (userValue == null) {
        logger.info('userValue is null');
        continue;
      }

      if ((comparisonValue.isEmpty || userValue.isEmpty)) {
        logger.info(_formatNoMatchRule(
            comparisonAttribute: comparisonAttribute,
            userValue: userValue,
            comparator: comparator,
            comparisonValue: comparisonValue));
        continue;
      }

      switch (comparator) {
        // IS ONE OF
        case 0:
          final splitted =
              comparisonValue.split(',').map((value) => value.trim());
          if (splitted.contains(userValue)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // IS NOT ONE OF
        case 1:
          final splitted =
              comparisonValue.split(',').map((value) => value.trim());
          if (!splitted.contains(userValue)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // CONTAINS
        case 2:
          if (userValue.contains(comparisonValue)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // DOES NOT CONTAIN
        case 3:
          if (!userValue.contains(comparisonValue)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // IS ONE OF (Semantic version), IS NOT ONE OF (Semantic version)
        case 4:
        case 5:
          final splitted = comparisonValue
              .split(',')
              .map((value) => value.trim())
              .where((value) => !value.isEmpty);

          // The rule will be ignored if we found an invalid semantic version
          final invalidVersion = splitted.firstWhere(
              (value) => value.toVersion() == null,
              orElse: () => '');
          if (invalidVersion != '') {
            logger.severe(_formatValidationErrorRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                error: 'Invalid semantic version $invalidVersion'));
            continue;
          }

          if (userValue.toVersion() == null) {
            logger.severe(_formatValidationErrorRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                error: 'Invalid semantic version $userValue'));
            continue;
          }

          if (comparator == 4) {
            // IS ONE OF
            final userValueVersion = userValue.toVersion();
            if (userValueVersion != null &&
                splitted.contains(
                    (value) => value.toVersion() == userValueVersion)) {
              final returnValue = rule[Config.value] as Value;
              logger.info(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return Tuple2(returnValue, rule[Config.variationId] as String);
            }
          } else {
            // IS NOT ONE OF
            final userValueVersion = userValue.toVersion();
            if (userValueVersion != null) {
              final returnValue = rule[Config.value] as Value;
              logger.info(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return Tuple2(returnValue, rule[Config.variationId] as String);
            }
          }
          break;
        // LESS THAN, LESS THAN OR EQUALS TO, GREATER THAN, GREATER THAN OR EQUALS TO (Semantic version)
        case 6:
        case 7:
        case 8:
        case 9:
          final userValueVersion = userValue.toVersion();
          final comparison = comparisonValue.trim();
          final comparisonVersion = comparison.toVersion();

          if (userValueVersion == null) {
            logger.severe(_formatValidationErrorRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                error: 'Invalid semantic version $userValue'));
            continue;
          }

          if (comparisonVersion == null) {
            logger.severe(_formatValidationErrorRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                error: 'Invalid semantic version $comparison'));
            continue;
          }

          final userValueVersionWithoutMetadata = Version(
              userValueVersion.major,
              userValueVersion.minor,
              userValueVersion.patch,
              preRelease: userValueVersion.preRelease);
          final comparisonValueVersionWithoutMetadata = Version(
              comparisonVersion.major,
              comparisonVersion.minor,
              comparisonVersion.patch,
              preRelease: comparisonVersion.preRelease);

          if ((comparator == 6 && userValueVersionWithoutMetadata < comparisonValueVersionWithoutMetadata) ||
              (comparator == 7 &&
                  userValueVersionWithoutMetadata <=
                      comparisonValueVersionWithoutMetadata) ||
              (comparator == 8 &&
                  userValueVersionWithoutMetadata >
                      comparisonValueVersionWithoutMetadata) ||
              (comparator == 9 &&
                  userValueVersionWithoutMetadata >=
                      comparisonValueVersionWithoutMetadata)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
          final userValueDouble = double.parse(userValue.replaceAll(',', '.'));
          final comparisonValueDouble =
              double.parse(comparisonValue.replaceAll(',', '.'));
          if ((comparator == 10 && userValueDouble == comparisonValueDouble) ||
              (comparator == 11 && userValueDouble != comparisonValueDouble) ||
              (comparator == 12 && userValueDouble < comparisonValueDouble) ||
              (comparator == 13 && userValueDouble <= comparisonValueDouble) ||
              (comparator == 14 && userValueDouble > comparisonValueDouble) ||
              (comparator == 15 && userValueDouble >= comparisonValueDouble)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // IS ONE OF (Sensitive)
        case 16:
          final splitted =
              comparisonValue.split(',').map((value) => value.trim());
          final userValueHash = sha1.convert(utf8.encode(userValue));
          if (splitted.contains(userValueHash)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        // IS NOT ONE OF (Sensitive)
        case 17:
          final splitted =
              comparisonValue.split(',').map((value) => value.trim());
          final userValueHash = sha1.convert(utf8.encode(userValue));
          if (!splitted.contains(userValueHash)) {
            final returnValue = rule[Config.value] as Value;
            logger.info(_formatMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue,
                value: returnValue));
            return Tuple2(returnValue, rule[Config.variationId] as String);
          }
          break;
        default:
          continue;
      }
      logger.info(_formatNoMatchRule(
          comparisonAttribute: comparisonAttribute,
          userValue: userValue,
          comparator: comparator,
          comparisonValue: comparisonValue));
    }

    if (rolloutPercentageItems.length > 0) {
      final hasCandidate = key + user.identifier;
      final userValueHash = sha1.convert(utf8.encode(hasCandidate));
      final hash = userValueHash.toString().substring(0, 8);
      final num = int.parse(hash, radix: 16);
      final scaled = num % 100;
      int bucket = 0;
      for (final rule in rolloutPercentageItems) {
        final percentage = rule[Config.percentage] as int;
        bucket += percentage;
        if (scaled < bucket) {
          logger.info('Evaluating %% options. Returning ${rule[Config.value] as String}');
          return Tuple2(rule[Config.value] as Value, rule[Config.variationId] as String);
        }
      }

      logger.info('Returning ${json[Config.value] as String}');
      return Tuple2(json[Config.value] as Value, json[Config.variationId] as String);
    }
  }

  String _formatMatchRule<Value>(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue,
      required Value? value}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator.comparatorTexts[comparator]}] [$comparisonValue] => match, returning: $value';
  }

  String _formatNoMatchRule(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator.comparatorTexts[comparator]}] [$comparisonValue] => no match';
  }

  String _formatValidationErrorRule(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue,
      required String error}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator.comparatorTexts[comparator]}] [$comparisonValue] => Skip rule. Validation error: $error';
  }
}
