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
enum SegmentComparator {
  isInSegment(id: 0,name:  "IS IN SEGMENT"),
  isNotInSegment(id: 1,name: "IS NOT IN SEGMENT");

  final int id;
  final String name;

  const SegmentComparator({
    required this.id,
    required this.name
  });
}

enum PrerequisiteComparator {
  equals(id: 0, name: "EQUALS"),
  notEquals(id: 1, name: "NOT EQUALS");

  final int id;
  final String name;

  const PrerequisiteComparator({
    required this.id,
    required this.name
  });
}

enum UserComparator {
  isOneOf(id: 0,name: "IS ONE OF"),
  isNotOneOf(id: 1,  name:"IS NOT ONE OF"),
  containsAnyOf(id:2,  name:"CONTAINS ANY OF"),
  notContainsAnyOf(id:3,  name:"NOT CONTAINS ANY OF"),
  semverIsOneOf(id:4,  name:"IS ONE OF"),
  semverIsNotOneOf(id:5,  name:"IS NOT ONE OF"),
  semverLess(id:6,  name:"<"),
  semverLessEquals(id:7,  name:"<="),
  semverGreater(id:8,  name:">"),
  semverGreaterEquals(id:9,  name:">="),
  numberEquals(id:10,  name:"="),
  numberNotEquals(id:11,  name:"!="),
  numberLess(id:12, name: "<"),
  numberLessEquals(id: 13,  name:"<="),
  numberGreater(id:14,  name:">"),
  numberGreaterEquals(id:15,  name:">="),
  sensitiveIsOneOf(id:16,  name:"IS ONE OF"),
  sensitiveIsNotOneOf(id:17, name: "IS NOT ONE OF"),
  dateBefore(id:18, name: "BEFORE"),
  dateAfter(id:19,  name:"AFTER"),
  hashedEquals(id:20,  name:"EQUALS"),
  hashedNotEquals(id:21, name: "NOT EQUALS"),
  hashedStartsWith(id:22,  name:"STARTS WITH ANY OF"),
  hashedNotStartsWith(id:23,  name:"NOT STARTS WITH ANY OF"),
  hashedEndsWith(id:24, name: "ENDS WITH ANY OF"),
  hashedNotEndsWith(id:25,  name:"NOT ENDS WITH ANY OF"),
  hashedArrayContains(id:26,  name:"ARRAY CONTAINS ANY OF"),
  hashedArrayNotContains(id:27,  name:"ARRAY NOT CONTAINS ANY OF"),
  textEquals(id:28, name: "EQUALS"),
  textNotEquals(id:29, name: "NOT EQUALS"),
  textStartsWith(id:30,  name:"STARTS WITH ANY OF"),
  textNotStartsWith(id:31,  name:"NOT STARTS WITH ANY OF"),
  textEndsWith(id:32,  name:"ENDS WITH ANY OF"),
  textNotEndsWith(id:33,  name:"NOT ENDS WITH ANY OF"),
  textArrayContains(id:34, name: "ARRAY CONTAINS ANY OF"),
  textArrayNotContains(id:35, name: "ARRAY NOT CONTAINS ANY OF");

  final int id;
  final String name;

  const UserComparator({
    required this.id,
    required this.name
  });
}



class RolloutEvaluator {

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
        final comparator = UserComparator.values.firstWhere((element) => element.id == rule.comparator);
        final userValue = user.getAttribute(comparisonAttribute);
        final returnValue = rule.value as Value;

        if (userValue == null || comparisonValue.isEmpty || userValue.isEmpty) {
          continue;
        }

        switch (comparator) {
          case UserComparator.containsAnyOf:
          case UserComparator.notContainsAnyOf:
            bool negateContainsAnyOf = UserComparator.notContainsAnyOf == comparator;
            //TODO fix me. we need the new models to implement properly the changes
            if (userValue.contains(comparisonValue)) {
              return produceResult(rolloutRule: rule);
            }
            break;
          case UserComparator.semverIsOneOf:
          case UserComparator.semverIsNotOneOf:
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

              if ((matched && comparator == UserComparator.semverIsOneOf) ||
                  (!matched && comparator == UserComparator.semverIsNotOneOf)) {
                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              //TODO fix message
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
          case UserComparator.semverLess:
          case UserComparator.semverLessEquals:
          case UserComparator.semverGreater:
          case UserComparator.semverGreaterEquals:
            try {
              final userValueVersion = _parseVersion(userValue);
              final comparisonVersion = _parseVersion(comparisonValue.trim());

              if ((comparator == UserComparator.semverLess && userValueVersion < comparisonVersion) ||
                  (comparator == UserComparator.semverLessEquals && userValueVersion <= comparisonVersion) ||
                  (comparator == UserComparator.semverGreater && userValueVersion > comparisonVersion) ||
                  (comparator == UserComparator.semverGreaterEquals && userValueVersion >= comparisonVersion)) {

                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              //TODO fix message
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
          case UserComparator.numberEquals:
          case UserComparator.numberNotEquals:
          case UserComparator.numberLess:
          case UserComparator.numberLessEquals:
          case UserComparator.numberGreater:
          case UserComparator.numberGreaterEquals:
            try {
              final uvDouble = double.parse(userValue.replaceAll(',', '.'));
              final cvDouble =
                  double.parse(comparisonValue.replaceAll(',', '.'));
              if ((comparator == UserComparator.numberEquals && uvDouble == cvDouble) ||
                  (comparator == UserComparator.numberNotEquals && uvDouble != cvDouble) ||
                  (comparator == UserComparator.numberLess && uvDouble < cvDouble) ||
                  (comparator == UserComparator.numberLessEquals && uvDouble <= cvDouble) ||
                  (comparator == UserComparator.numberGreater && uvDouble > cvDouble) ||
                  (comparator == UserComparator.numberGreaterEquals && uvDouble >= cvDouble)) {
                return produceResult(rolloutRule: rule);
              }
            } catch (e) {
              //TODO fix message
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
          case UserComparator.isOneOf:
          case UserComparator.isNotOneOf:
          case UserComparator.sensitiveIsOneOf:
          case UserComparator.sensitiveIsNotOneOf:
            //TODO refactor - sensitive is not one of as well
            final split = comparisonValue
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty);
            final userValueHash =
                sha1.convert(utf8.encode(userValue)).toString();
            if (split.contains(userValueHash)) {
              return produceResult(rolloutRule: rule);
            }
            break;
          case UserComparator.dateBefore:
          case UserComparator.dateAfter:
            //TODO implement
            break;
          case UserComparator.textEquals:
          case UserComparator.textNotEquals:
          case UserComparator.hashedEquals:
          case UserComparator.hashedNotEquals:
            //TODO implement
            break;
          case UserComparator.hashedStartsWith:
          case UserComparator.hashedNotStartsWith:
          case UserComparator.hashedEndsWith:
          case UserComparator.hashedNotEndsWith:
            //TODO implement
            break;
          case UserComparator.textStartsWith:
          case UserComparator.textNotStartsWith:
            //TODO implement
            break;
          case UserComparator.textEndsWith:
          case UserComparator.textNotEndsWith:
            //TODO implement
            break;
          case UserComparator.textArrayContains:
          case UserComparator.textArrayNotContains:
          case UserComparator.hashedArrayContains:
          case UserComparator.hashedArrayNotContains:
            //TODO implement
            break;
          default:
            //TODO fix messages
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
      required UserComparator comparator,
      required String comparisonValue,
      required Value? value}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${comparator.name}] [$comparisonValue] => match, returning: $value';
  }

  String _formatNoMatchRule(
      {required String comparisonAttribute,
      required String userValue,
      required UserComparator comparator,
      required String comparisonValue}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${comparator.name}] [$comparisonValue] => no match';
  }

  String _formatValidationErrorRule(
      {required String comparisonAttribute,
      required String userValue,
      required UserComparator comparator,
      required String comparisonValue,
      required dynamic error}) {
    return 'Evaluating rule: [$comparisonAttribute:$userValue] [${comparator.name}] [$comparisonValue] => Skip rule. Validation error: $error';
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
