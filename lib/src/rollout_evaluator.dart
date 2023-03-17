import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pub_semver/pub_semver.dart';

import 'json/rollout_rule.dart';
import 'json/percentage_rule.dart';
import 'configcat_user.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';

class EvaluationResult<T> {
  final String key;
  final String variationId;
  final T value;
  final RolloutRule? matchedEvaluationRule;
  final PercentageRule? matchedEvaluationPercentageRule;

  EvaluationResult(
      {required this.key,
      required this.variationId,
      required this.value,
      required this.matchedEvaluationRule,
      required this.matchedEvaluationPercentageRule});
}

class RolloutEvaluator {
  static const _comparatorTexts = [
    'IS ONE OF',
    'IS NOT ONE OF',
    'CONTAINS',
    'DOES NOT CONTAIN',
    'IS ONE OF (SemVer)',
    'IS NOT ONE OF (SemVer)',
    '< (SemVer)',
    '<= (SemVer)',
    '> (SemVer)',
    '>= (SemVer)',
    '= (Number)',
    '<> (Number)',
    '< (Number)',
    '<= (Number)',
    '> (Number)',
    '>= (Number',
    'IS ONE OF (Sensitive)',
    'IS NOT ONE OF (Sensitive)',
  ];

  final ConfigCatLogger _logger;

  RolloutEvaluator(this._logger);

  EvaluationResult<Value> evaluate<Value>(
      Setting setting, String key, ConfigCatUser? user) {
    final logEntries = _LogEntries();
    logEntries.add('Evaluating getValue($key)');

    EvaluationResult<Value> produceResult(
        {RolloutRule? rolloutRule, PercentageRule? percentageItem}) {
      return EvaluationResult(
          key: key,
          variationId: rolloutRule?.variationId ??
              percentageItem?.variationId ??
              setting.variationId,
          value: rolloutRule?.value ?? percentageItem?.value ?? setting.value,
          matchedEvaluationRule: rolloutRule,
          matchedEvaluationPercentageRule: percentageItem);
    }

    try {
      if (user == null) {
        if (setting.rolloutRules.isNotEmpty ||
            setting.percentageItems.isNotEmpty) {
          _logger.warning(3001,
              'Cannot evaluate targeting rules and % options for setting \'$key\' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/');
        }
        logEntries.add('Returning ${setting.value}');
        return produceResult();
      }

      logEntries.add('User object: $user');

      for (final rule in setting.rolloutRules) {
        final comparisonAttribute = rule.comparisonAttribute;
        final comparisonValue = rule.comparisonValue;
        final comparator = rule.comparator;
        final userValue = user.getAttribute(comparisonAttribute);
        final returnValue = rule.value as Value;

        if (userValue == null || comparisonValue.isEmpty || userValue.isEmpty) {
          logEntries.add(_formatNoMatchRule(
              comparisonAttribute: comparisonAttribute,
              userValue: userValue ?? '',
              comparator: comparator,
              comparisonValue: comparisonValue));
          continue;
        }

        switch (comparator) {
          // IS ONE OF
          case 0:
            final split =
                comparisonValue.split(',').map((value) => value.trim());
            if (split.contains(userValue)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          // IS NOT ONE OF
          case 1:
            final split =
                comparisonValue.split(',').map((value) => value.trim());
            if (!split.contains(userValue)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          // CONTAINS
          case 2:
            if (userValue.contains(comparisonValue)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          // DOES NOT CONTAIN
          case 3:
            if (!userValue.contains(comparisonValue)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          // IS ONE OF (Semantic version), IS NOT ONE OF (Semantic version)
          case 4:
          case 5:
            final split = comparisonValue
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty);

            try {
              final userVersion = _parseVersion(userValue);
              var matched = false;
              for (final value in split) {
                matched = _parseVersion(value) == userVersion || matched;
              }

              if ((matched && comparator == 4) ||
                  (!matched && comparator == 5)) {
                logEntries.add(_formatMatchRule(
                    comparisonAttribute: comparisonAttribute,
                    userValue: userValue,
                    comparator: comparator,
                    comparisonValue: comparisonValue,
                    value: returnValue));
                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              final message = _formatValidationErrorRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  error: e);
              _logger.warning(0, message);
              logEntries.add(message);
            }
            break;
          // LESS THAN, LESS THAN OR EQUALS TO, GREATER THAN, GREATER THAN OR EQUALS TO (Semantic version)
          case 6:
          case 7:
          case 8:
          case 9:
            try {
              final userValueVersion = _parseVersion(userValue);
              final comparisonVersion = _parseVersion(comparisonValue.trim());

              if ((comparator == 6 && userValueVersion < comparisonVersion) ||
                  (comparator == 7 && userValueVersion <= comparisonVersion) ||
                  (comparator == 8 && userValueVersion > comparisonVersion) ||
                  (comparator == 9 && userValueVersion >= comparisonVersion)) {
                logEntries.add(_formatMatchRule(
                    comparisonAttribute: comparisonAttribute,
                    userValue: userValue,
                    comparator: comparator,
                    comparisonValue: comparisonValue,
                    value: returnValue));
                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              final message = _formatValidationErrorRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  error: e);
              _logger.warning(0, message);
              logEntries.add(message);
            }
            break;
          case 10:
          case 11:
          case 12:
          case 13:
          case 14:
          case 15:
            try {
              final uvDouble = double.parse(userValue.replaceAll(',', '.'));
              final cvDouble =
                  double.parse(comparisonValue.replaceAll(',', '.'));
              if ((comparator == 10 && uvDouble == cvDouble) ||
                  (comparator == 11 && uvDouble != cvDouble) ||
                  (comparator == 12 && uvDouble < cvDouble) ||
                  (comparator == 13 && uvDouble <= cvDouble) ||
                  (comparator == 14 && uvDouble > cvDouble) ||
                  (comparator == 15 && uvDouble >= cvDouble)) {
                logEntries.add(_formatMatchRule(
                    comparisonAttribute: comparisonAttribute,
                    userValue: userValue,
                    comparator: comparator,
                    comparisonValue: comparisonValue,
                    value: returnValue));
                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              final message = _formatValidationErrorRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  error: e);
              _logger.warning(0, message);
              logEntries.add(message);
            }
            break;
          // IS ONE OF (Sensitive)
          case 16:
            final split = comparisonValue
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty);
            final userValueHash =
                sha1.convert(utf8.encode(userValue)).toString();
            if (split.contains(userValueHash)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          // IS NOT ONE OF (Sensitive)
          case 17:
            final split = comparisonValue
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty);
            final userValueHash =
                sha1.convert(utf8.encode(userValue)).toString();
            if (!split.contains(userValueHash)) {
              logEntries.add(_formatMatchRule(
                  comparisonAttribute: comparisonAttribute,
                  userValue: userValue,
                  comparator: comparator,
                  comparisonValue: comparisonValue,
                  value: returnValue));
              return produceResult(rolloutRule: rule);
            }
            break;
          default:
            logEntries.add(_formatNoMatchRule(
                comparisonAttribute: comparisonAttribute,
                userValue: userValue,
                comparator: comparator,
                comparisonValue: comparisonValue));
        }
      }

      if (setting.percentageItems.isNotEmpty) {
        final hashCandidate = key + user.identifier;
        final userValueHash = sha1.convert(utf8.encode(hashCandidate));
        final hash = userValueHash.toString().substring(0, 7);
        final num = int.parse(hash, radix: 16);
        final scaled = num % 100;
        double bucket = 0;
        for (final rule in setting.percentageItems) {
          bucket += rule.percentage;
          if (scaled < bucket) {
            logEntries.add('Evaluating %% options. Returning ${rule.value}');
            return produceResult(percentageItem: rule);
          }
        }
      }

      logEntries.add('Returning ${setting.value}');
      return produceResult();
    } finally {
      _logger.info(5000, logEntries);
    }
  }

  String _formatMatchRule<Value>(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue,
      required Value? value}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator._comparatorTexts[comparator]}] [$comparisonValue] => match, returning: $value';
  }

  String _formatNoMatchRule(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator._comparatorTexts[comparator]}] [$comparisonValue] => no match';
  }

  String _formatValidationErrorRule(
      {required String comparisonAttribute,
      required String userValue,
      required int comparator,
      required String comparisonValue,
      required dynamic error}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${RolloutEvaluator._comparatorTexts[comparator]}] [$comparisonValue] => Skip rule. Validation error: $error';
  }

  Version _parseVersion(String text) {
    // remove build parts, we don't want to compare by them.
    final buildCharPos = text.indexOf('+');
    return Version.parse(
        buildCharPos != -1 ? text.substring(0, buildCharPos) : text);
  }
}

class _LogEntries {
  final List<String> entries = [];

  add(String entry) {
    entries.add(entry);
  }

  @override
  String toString() {
    return entries.join('\n');
  }
}
