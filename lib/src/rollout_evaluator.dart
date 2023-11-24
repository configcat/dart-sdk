import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pub_semver/pub_semver.dart';

import 'configcat_user.dart';
import 'json/condition_accessor.dart';
import 'json/percentage_option.dart';
import 'json/segment.dart';
import 'json/targeting_rule.dart';
import 'json/setting.dart';
import 'json/prerequisite_flag_condition.dart';
import 'json/segment_condition.dart';
import 'json/settings_value.dart';
import 'json/user_condition.dart';
import 'log/configcat_logger.dart';

class EvaluationResult {
  final String variationId;
  final SettingsValue value;
  final TargetingRule? matchedTargetingRule;
  final PercentageOption? matchedPercentageOption;

  EvaluationResult(
      {required this.variationId,
      required this.value,
      required this.matchedTargetingRule,
      required this.matchedPercentageOption});
}

class EvaluationContext {
  String key;
  ConfigCatUser? user;
  List<String>? visitedKeys;
  Map<String, Setting> settings;
  bool isUserMissing = false;
  bool isUserAttributeMissing = false;

  EvaluationContext(this.key, this.user, this.visitedKeys, this.settings);
}

class RolloutEvaluatorException implements Exception {
  String message;

  RolloutEvaluatorException(this.message);
}

enum SegmentComparator {
  isInSegment(id: 0, name: "IS IN SEGMENT"),
  isNotInSegment(id: 1, name: "IS NOT IN SEGMENT");

  final int id;
  final String name;

  const SegmentComparator({required this.id, required this.name});
}

enum PrerequisiteComparator {
  equals(id: 0, name: "EQUALS"),
  notEquals(id: 1, name: "NOT EQUALS");

  final int id;
  final String name;

  const PrerequisiteComparator({required this.id, required this.name});
}

enum UserComparator {
  isOneOf(id: 0, name: "IS ONE OF"),
  isNotOneOf(id: 1, name: "IS NOT ONE OF"),
  containsAnyOf(id: 2, name: "CONTAINS ANY OF"),
  notContainsAnyOf(id: 3, name: "NOT CONTAINS ANY OF"),
  semverIsOneOf(id: 4, name: "IS ONE OF"),
  semverIsNotOneOf(id: 5, name: "IS NOT ONE OF"),
  semverLess(id: 6, name: "<"),
  semverLessEquals(id: 7, name: "<="),
  semverGreater(id: 8, name: ">"),
  semverGreaterEquals(id: 9, name: ">="),
  numberEquals(id: 10, name: "="),
  numberNotEquals(id: 11, name: "!="),
  numberLess(id: 12, name: "<"),
  numberLessEquals(id: 13, name: "<="),
  numberGreater(id: 14, name: ">"),
  numberGreaterEquals(id: 15, name: ">="),
  sensitiveIsOneOf(id: 16, name: "IS ONE OF"),
  sensitiveIsNotOneOf(id: 17, name: "IS NOT ONE OF"),
  dateBefore(id: 18, name: "BEFORE"),
  dateAfter(id: 19, name: "AFTER"),
  hashedEquals(id: 20, name: "EQUALS"),
  hashedNotEquals(id: 21, name: "NOT EQUALS"),
  hashedStartsWith(id: 22, name: "STARTS WITH ANY OF"),
  hashedNotStartsWith(id: 23, name: "NOT STARTS WITH ANY OF"),
  hashedEndsWith(id: 24, name: "ENDS WITH ANY OF"),
  hashedNotEndsWith(id: 25, name: "NOT ENDS WITH ANY OF"),
  hashedArrayContains(id: 26, name: "ARRAY CONTAINS ANY OF"),
  hashedArrayNotContains(id: 27, name: "ARRAY NOT CONTAINS ANY OF"),
  textEquals(id: 28, name: "EQUALS"),
  textNotEquals(id: 29, name: "NOT EQUALS"),
  textStartsWith(id: 30, name: "STARTS WITH ANY OF"),
  textNotStartsWith(id: 31, name: "NOT STARTS WITH ANY OF"),
  textEndsWith(id: 32, name: "ENDS WITH ANY OF"),
  textNotEndsWith(id: 33, name: "NOT ENDS WITH ANY OF"),
  textArrayContains(id: 34, name: "ARRAY CONTAINS ANY OF"),
  textArrayNotContains(id: 35, name: "ARRAY NOT CONTAINS ANY OF");

  final int id;
  final String name;

  const UserComparator({required this.id, required this.name});
}

const String userObjectIsMissing = "cannot evaluate, User Object is missing";
const String cannotEvaluateTheUserPrefix = "cannot evaluate, the User.";
const String comparisonOperatorIsInvalid = "Comparison operator is invalid.";
const String comparisonValueIsMissingOrInvalid =
    "Comparison value is missing or invalid.";
const String cannotEvaluateTheUserAttributeInvalid = " attribute is invalid (";
const String cannotEvaluateTheUserAttributeMissing = " attribute is missing";

class RolloutEvaluator {
  final ConfigCatLogger _logger;

  RolloutEvaluator(this._logger);

  EvaluationResult evaluate(Setting setting, String key, ConfigCatUser? user,
      Map<String, Setting> settings) {
    final logEntries = _LogEntries();
    logEntries.add('Evaluating getValue($key)');

    try {
      //TODO add eval log start

      if (user != null) {
        //TODO user eval log
        logEntries.add('User object: $user');
      }
      //TODO eval incs

      EvaluationContext evaluationContext =
          EvaluationContext(key, user, null, settings);
      EvaluationResult evaluationResult =
          _evaluateSetting(setting, evaluationContext);

      // TODO fix log
      logEntries.add('Returning ${evaluationResult}');
      //TODO eval dec
      return evaluationResult;
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

  EvaluationResult _evaluateSetting(
      Setting setting, EvaluationContext evaluationContext) {
    EvaluationResult? evaluationResult;
    if (setting.targetingRules.isNotEmpty) {
      evaluationResult = _evaluateTargetingRules(setting, evaluationContext);
    }
    if (evaluationResult == null && setting.percentageOptions.isNotEmpty) {
      evaluationResult = _evaluatePercentageOptions(setting.percentageOptions,
          setting.percentageAttribute, evaluationContext, null);
    }
    evaluationResult ??= EvaluationResult(
        variationId: setting.variationId,
        value: setting.settingsValue,
        matchedTargetingRule: null,
        matchedPercentageOption: null);

    return evaluationResult;
  }

  EvaluationResult? _evaluateTargetingRules(
      Setting setting, EvaluationContext evaluationContext) {
    //TODO         evaluateLogger.logTargetingRules();
    for (TargetingRule rule in setting.targetingRules) {
      bool evaluateConditionsResult;
      String? error;
      try {
        evaluateConditionsResult = _evaluateConditions(
            rule.conditions,
            rule,
            evaluationContext,
            setting.salt,
            evaluationContext.key,
            setting.segments);
      } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
        error = rolloutEvaluatorException.message;
        evaluateConditionsResult = false;
      }

      if (!evaluateConditionsResult) {
        if (error != null) {
          // TODO FIXME evaluateLogger.logTargetingRuleIgnored();
        }
        continue;
      }
      if (rule.servedValue != null) {
        return EvaluationResult(
            variationId: rule.servedValue!.variationId,
            value: rule.servedValue!.settingsValue,
            matchedTargetingRule: rule,
            matchedPercentageOption: null);
      }

      if (rule.percentageOptions?.isEmpty ?? true) {
        throw ArgumentError("Targeting rule THEN part is missing or invalid.");
      }

      // TODO evaluateLogger.increaseIndentLevel();
      EvaluationResult? evaluatePercentageOptionsResult =
          _evaluatePercentageOptions(rule.percentageOptions!,
              setting.percentageAttribute, evaluationContext, rule);
      // TODO EVAL evaluateLogger.decreaseIndentLevel();

      if (evaluatePercentageOptionsResult == null) {
        // TODO evaluateLogger.logTargetingRuleIgnored();
        continue;
      }

      return evaluatePercentageOptionsResult;
    }

    return null;
  }

  bool _evaluateConditions(
      List<ConditionAccessor> conditions,
      TargetingRule? targetingRule,
      EvaluationContext evaluationContext,
      String configSalt,
      String contextSalt,
      List<Segment> segments) {
    bool firstConditionFlag = true;
    bool conditionsEvaluationResult = false;
    String? error;
    bool newLine = false;
    for (ConditionAccessor condition in conditions) {
      if (firstConditionFlag) {
        firstConditionFlag = false;
        // TODO evaluateLogger.newLine();
        // evaluateLogger.append("- IF ");
        // evaluateLogger.increaseIndentLevel();
      } else {
        // TODO evaluateLogger.increaseIndentLevel();
        // evaluateLogger.newLine();
        // evaluateLogger.append("AND ");
      }

      //TODO solve conditions ?
      final userCondition = condition.userCondition;
      final segmentCondition = condition.segmentCondition;
      final prerequisiteFlagCondition = condition.prerequisiteFlagCondition;
      if (userCondition != null) {
        try {
          conditionsEvaluationResult = _evaluateUserCondition(
              userCondition, evaluationContext, configSalt, contextSalt);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = conditions.length > 1;
      } else if (segmentCondition != null) {
        try {
          conditionsEvaluationResult = _evaluateSegmentCondition(
              segmentCondition, evaluationContext, configSalt, segments);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = userObjectIsMissing != error || conditions.length > 1;
      } else if (prerequisiteFlagCondition != null) {
        try {
          conditionsEvaluationResult = _evaluatePrerequisiteFlagCondition(
              prerequisiteFlagCondition, evaluationContext);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = error == null || conditions.length > 1;
      }

      if (targetingRule == null || conditions.length > 1) {
        //TODO evaluateLogger.logConditionConsequence(conditionsEvaluationResult);
      }
      //TODO evaluateLogger.decreaseIndentLevel();
      if (!conditionsEvaluationResult) {
        break;
      }
    }
    if (targetingRule != null) {
      // TODO logger evaluateLogger.logTargetingRuleConsequence(targetingRule, error, conditionsEvaluationResult, newLine);
    }
    if (error != null) {
      throw RolloutEvaluatorException(error);
    }
    return conditionsEvaluationResult;
  }

  bool _evaluateUserCondition(
      UserCondition userCondition,
      EvaluationContext evaluationContext,
      String configSalt,
      String contextSalt) {
    //TODO evaluateLogger.append(LogHelper.formatUserCondition(userCondition));

    if (evaluationContext.user == null) {
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()`/`getValueAsync()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      }
      throw RolloutEvaluatorException(userObjectIsMissing);
    }

    String comparisonAttribute = userCondition.comparisonAttribute;
    UserComparator comparator = UserComparator.values.firstWhere(
        (element) => element.id == userCondition.comparator,
        orElse: () => throw ArgumentError(comparisonOperatorIsInvalid));
    String? userAttributeValue =
        evaluationContext.user!.getAttribute(comparisonAttribute);

    if (userAttributeValue == null || userAttributeValue.isEmpty) {
      //TODO  logger.warn(3003, ConfigCatLogMessages.getUserAttributeMissing(context.getKey(), userCondition, comparisonAttribute));
      throw RolloutEvaluatorException(cannotEvaluateTheUserPrefix +
          comparisonAttribute +
          cannotEvaluateTheUserAttributeMissing);
    }

    switch (comparator) {
      case UserComparator.containsAnyOf:
      case UserComparator.notContainsAnyOf:
        bool negateContainsAnyOf =
            UserComparator.notContainsAnyOf == comparator;
        return _evaluateContainsAnyOf(
            negateContainsAnyOf, userCondition, userAttributeValue);
      case UserComparator.semverIsOneOf:
      case UserComparator.semverIsNotOneOf:
        bool negateSemverIsOneOf =
            UserComparator.semverIsNotOneOf == comparator;
        return _evaluateSemverIsOneOf(userCondition, userAttributeValue,
            negateSemverIsOneOf, comparisonAttribute);
      case UserComparator.semverLess:
      case UserComparator.semverLessEquals:
      case UserComparator.semverGreater:
      case UserComparator.semverGreaterEquals:
        return _evaluateSemver(
            userAttributeValue, userCondition, comparator, comparisonAttribute);
      case UserComparator.numberEquals:
      case UserComparator.numberNotEquals:
      case UserComparator.numberLess:
      case UserComparator.numberLessEquals:
      case UserComparator.numberGreater:
      case UserComparator.numberGreaterEquals:
        return _evaluateNumbers(
            userAttributeValue, userCondition, comparator, comparisonAttribute);
      case UserComparator.isOneOf:
      case UserComparator.isNotOneOf:
      case UserComparator.sensitiveIsOneOf:
      case UserComparator.sensitiveIsNotOneOf:
        bool negateIsOneOf = UserComparator.sensitiveIsNotOneOf == comparator ||
            UserComparator.isNotOneOf == comparator;
        bool sensitiveIsOneOf = UserComparator.sensitiveIsOneOf == comparator ||
            UserComparator.sensitiveIsNotOneOf == comparator;
        return _evaluateIsOneOf(userCondition, sensitiveIsOneOf,
            userAttributeValue, configSalt, contextSalt, negateIsOneOf);
      case UserComparator.dateBefore:
      case UserComparator.dateAfter:
        return _evaluateDate(
            userAttributeValue, userCondition, comparator, comparisonAttribute);
      case UserComparator.textEquals:
      case UserComparator.textNotEquals:
      case UserComparator.hashedEquals:
      case UserComparator.hashedNotEquals:
        bool negateEquals = UserComparator.hashedNotEquals == comparator ||
            UserComparator.textNotEquals == comparator;
        bool hashedEquals = UserComparator.hashedEquals == comparator ||
            UserComparator.hashedNotEquals == comparator;
        return _evaluateEquals(hashedEquals, userAttributeValue, configSalt,
            contextSalt, userCondition, negateEquals);
      case UserComparator.hashedStartsWith:
      case UserComparator.hashedNotStartsWith:
      case UserComparator.hashedEndsWith:
      case UserComparator.hashedNotEndsWith:
        return _evaluateHashedStartOrEndWith(userAttributeValue, userCondition,
            comparator, configSalt, contextSalt);
      case UserComparator.textStartsWith:
      case UserComparator.textNotStartsWith:
        bool negateTextStartWith =
            UserComparator.textNotStartsWith == comparator;
        return _evaluateTextStartWith(
            userCondition, userAttributeValue, negateTextStartWith);
      case UserComparator.textEndsWith:
      case UserComparator.textNotEndsWith:
        bool negateTextEndsWith = UserComparator.textNotEndsWith == comparator;
        return _evaluateTextEndsWith(
            userCondition, userAttributeValue, negateTextEndsWith);
      case UserComparator.textArrayContains:
      case UserComparator.textArrayNotContains:
      case UserComparator.hashedArrayContains:
      case UserComparator.hashedArrayNotContains:
        bool negateArrayContains =
            UserComparator.hashedArrayNotContains == comparator ||
                UserComparator.textArrayNotContains == comparator;
        bool hashedArrayContains =
            UserComparator.hashedArrayContains == comparator ||
                UserComparator.hashedArrayNotContains == comparator;
        return _evaluateArrayContains(
            userCondition,
            userAttributeValue,
            comparisonAttribute,
            hashedArrayContains,
            configSalt,
            contextSalt,
            negateArrayContains);
      default:
        throw ArgumentError(comparisonOperatorIsInvalid);
    }
  }

  bool _evaluateArrayContains(
      UserCondition userCondition,
      String userAttributeValue,
      String comparisonAttribute,
      bool hashedArrayContains,
      String configSalt,
      String contextSalt,
      bool negateArrayContains) {
    List<String>? conditionContainsValues = userCondition.stringArrayValue;
    List<String> userContainsValues;
    try {
      userContainsValues = jsonDecode(userAttributeValue);
    } catch (e) {
      String reason = "'$userAttributeValue' is not a valid JSON string array";
      //TODO _logger.warn(3004, ConfigCatLogMessages.getUserAttributeInvalid(context.getKey(), userCondition, reason, comparisonAttribute));
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
    if (userContainsValues.isEmpty) {
      return false;
    }
    bool containsFlag = false;
    for (String userContainsValue in userContainsValues) {
      String userContainsValueConverted;
      if (hashedArrayContains) {
        userContainsValueConverted = _getSaltedUserValue(
            userContainsValue.trim(), configSalt, contextSalt);
      } else {
        userContainsValueConverted = userContainsValue;
      }
      //TODO ! fix
      if (conditionContainsValues!.contains(userContainsValueConverted)) {
        containsFlag = true;
        break;
      }
    }
    if (negateArrayContains) {
      containsFlag = !containsFlag;
    }
    return containsFlag;
  }

  bool _evaluateTextEndsWith(UserCondition userCondition,
      String userAttributeValue, bool negateTextEndsWith) {
    List<String> withTextValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = withTextValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    bool textEndsWith = false;
    for (String textValue in filteredContainsValues) {
      if (userAttributeValue.endsWith(textValue)) {
        textEndsWith = true;
        break;
      }
    }
    if (negateTextEndsWith) {
      return !textEndsWith;
    }
    return textEndsWith;
  }

  bool _evaluateTextStartWith(UserCondition userCondition,
      String userAttributeValue, bool negateTextStartWith) {
    List<String> withTextValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = withTextValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    bool textStartWith = false;
    for (String textValue in filteredContainsValues) {
      if (userAttributeValue.startsWith(textValue)) {
        textStartWith = true;
        break;
      }
    }
    if (negateTextStartWith) {
      return !textStartWith;
    }
    return textStartWith;
  }

  bool _evaluateHashedStartOrEndWith(
      String userAttributeValue,
      UserCondition userCondition,
      UserComparator comparator,
      String configSalt,
      String contextSalt) {
    List<int> userAttributeValueUTF8 = utf8.encode(userAttributeValue);
    List<String> withValues = userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = withValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);

    bool foundEqual = false;
    for (String comparisonValueHashedStartsEnds in filteredContainsValues) {
      int indexOf = comparisonValueHashedStartsEnds.indexOf("_");
      if (indexOf <= 0) {
        throw ArgumentError(comparisonValueIsMissingOrInvalid);
      }
      String comparedTextLength =
          comparisonValueHashedStartsEnds.substring(0, indexOf);
      try {
        int comparedTextLengthInt = int.parse(comparedTextLength);
        if (userAttributeValueUTF8.length < comparedTextLengthInt) {
          continue;
        }
        String comparisonHashValue =
            comparisonValueHashedStartsEnds.substring(indexOf + 1);
        if (comparisonHashValue.isEmpty) {
          throw ArgumentError(comparisonValueIsMissingOrInvalid);
        }
        String userValueSubString;
        if (UserComparator.hashedStartsWith == comparator ||
            UserComparator.hashedNotStartsWith == comparator) {
          userValueSubString = utf8
              .decode(userAttributeValueUTF8.sublist(0, comparedTextLengthInt));
        } else {
          //HASHED_ENDS_WITH & HASHED_NOT_ENDS_WITH
          userValueSubString = utf8.decode(userAttributeValueUTF8.sublist(
              userAttributeValueUTF8.length - comparedTextLengthInt,
              userAttributeValueUTF8.length));
        }
        String hashUserValueSub =
            _getSaltedUserValue(userValueSubString, configSalt, contextSalt);
        if (hashUserValueSub == comparisonHashValue) {
          foundEqual = true;
          break;
        }
      } catch (e) {
        throw ArgumentError(comparisonValueIsMissingOrInvalid);
      }
    }
    if (UserComparator.hashedNotStartsWith == comparator ||
        UserComparator.hashedNotEndsWith == comparator) {
      return !foundEqual;
    }
    return foundEqual;
  }

  bool _evaluateEquals(
      bool hashedEquals,
      String userAttributeValue,
      String configSalt,
      String contextSalt,
      UserCondition userCondition,
      bool negateEquals) {
    String valueEquals;
    if (hashedEquals) {
      valueEquals =
          _getSaltedUserValue(userAttributeValue, configSalt, contextSalt);
    } else {
      valueEquals = userAttributeValue;
    }
    bool equalsResult = valueEquals == userCondition.stringValue;
    if (negateEquals) {
      equalsResult = !equalsResult;
    }
    return equalsResult;
  }

  bool _evaluateDate(String userAttributeValue, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    try {
      double userDoubleValue =
          double.parse(userAttributeValue.replaceAll(',', '.'));
      double? comparisonDoubleValue = userCondition.doubleValue;
      if (comparisonDoubleValue == null) {
        //TODO is this check ok?
        return false;
      }
      return (UserComparator.dateBefore == comparator &&
              userDoubleValue < comparisonDoubleValue) ||
          UserComparator.dateAfter == comparator &&
              userDoubleValue > comparisonDoubleValue;
    } catch (e) {
      String reason =
          "'$userAttributeValue' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)";
      //TODO fix Logger this.logger.warn(3004, ConfigCatLogMessages.getUserAttributeInvalid(context.getKey(), userCondition, reason, comparisonAttribute));
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  bool _evaluateIsOneOf(
      UserCondition userCondition,
      bool sensitiveIsOneOf,
      String userAttributeValue,
      String configSalt,
      String contextSalt,
      bool negateIsOneOf) {
    List<String> containsValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = containsValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    String userIsOneOfValue;
    if (sensitiveIsOneOf) {
      userIsOneOfValue =
          _getSaltedUserValue(userAttributeValue, configSalt, contextSalt);
    } else {
      userIsOneOfValue = userAttributeValue;
    }
    bool isOneOf = filteredContainsValues.contains(userIsOneOfValue);
    if (negateIsOneOf) {
      isOneOf = !isOneOf;
    }
    return isOneOf;
  }

  String _getSaltedUserValue(
      String userValue, String configSalt, String contextSalt) {
    return sha256
        .convert(utf8.encode(userValue + configSalt + contextSalt))
        .toString();
  }

  bool _evaluateNumbers(String userAttributeValue, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    try {
      final uvDouble = double.parse(userAttributeValue.replaceAll(',', '.'));
      final cvDouble = userCondition.doubleValue;
      if (cvDouble == null) {
        //TODO this  should not happen. throw error? just return false? same is valid for emptyList etc.
        return false;
      }
      return ((comparator == UserComparator.numberEquals &&
              uvDouble == cvDouble) ||
          (comparator == UserComparator.numberNotEquals &&
              uvDouble != cvDouble) ||
          (comparator == UserComparator.numberLess && uvDouble < cvDouble) ||
          (comparator == UserComparator.numberLessEquals &&
              uvDouble <= cvDouble) ||
          (comparator == UserComparator.numberGreater && uvDouble > cvDouble) ||
          (comparator == UserComparator.numberGreaterEquals &&
              uvDouble >= cvDouble));
    } catch (e) {
      //TODO fix message
      String reason = "'$userAttributeValue' is not a valid decimal number";
      // this.logger.warn(3004, ConfigCatLogMessages.getUserAttributeInvalid(context.getKey(), userCondition, reason, comparisonAttribute));
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  bool _evaluateSemver(String userAttributeValue, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    try {
      final userValueVersion = _parseVersion(userAttributeValue);
      final comparisonValue = userCondition.stringValue ?? "";
      final comparisonVersion = _parseVersion(comparisonValue.trim());

      return ((comparator == UserComparator.semverLess &&
              userValueVersion < comparisonVersion) ||
          (comparator == UserComparator.semverLessEquals &&
              userValueVersion <= comparisonVersion) ||
          (comparator == UserComparator.semverGreater &&
              userValueVersion > comparisonVersion) ||
          (comparator == UserComparator.semverGreaterEquals &&
              userValueVersion >= comparisonVersion));
    } catch (e) {
      //TODO fix logger
      String reason = "'$userAttributeValue' is not a valid semantic version";
      //this.logger.warn(3004, ConfigCatLogMessages.getUserAttributeInvalid(context.getKey(), userCondition, reason, comparisonAttribute));
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  bool _evaluateSemverIsOneOf(
      UserCondition userCondition,
      String userAttributeValue,
      bool negateSemverIsOneOf,
      String comparisonAttribute) {
    List<String> containsValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = containsValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    try {
      final userVersion = _parseVersion(userAttributeValue);
      var matched = false;
      for (final value in filteredContainsValues) {
        matched = _parseVersion(value) == userVersion || matched;
      }

      if (negateSemverIsOneOf) {
        matched = !matched;
      }
      return matched;
    } catch (e) {
      //TODO fix logger
      String reason = "'$userAttributeValue' is not a valid semantic version";
      // this.logger.warn(3004, ConfigCatLogMessages.getUserAttributeInvalid(context.getKey(), userCondition, reason, comparisonAttribute));
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  bool _evaluateContainsAnyOf(bool negateContainsAnyOf,
      UserCondition userCondition, String userAttributeValue) {
    bool containsResult = !negateContainsAnyOf;
    List<String> containsValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = containsValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (String containsValue in filteredContainsValues) {
      if (userAttributeValue.contains(containsValue)) {
        return containsResult;
      }
    }
    return !containsResult;
  }

  bool _evaluateSegmentCondition(
      SegmentCondition segmentCondition,
      EvaluationContext evaluationContext,
      String configSalt,
      List<Segment> segments) {
    int segmentIndex = segmentCondition.segmentIndex;
    Segment? segment;
    if (segmentIndex < segments.length) {
      segment = segments[segmentIndex];
    }
    // TODO fix logger evaluateLogger.append(LogHelper.formatSegmentFlagCondition(segmentCondition, segment));

    if (evaluationContext.user == null) {
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()`/`getValueAsync()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      }
      throw RolloutEvaluatorException(userObjectIsMissing);
    }

    if (segment == null) {
      throw ArgumentError("Segment reference is invalid.");
    }
    String? segmentName = segment.name;
    if (segmentName == null || segmentName.isEmpty) {
      throw ArgumentError("Segment name is missing.");
    }
    //TODO fix logger evaluateLogger.logSegmentEvaluationStart(segmentName);

    bool result;
    try {
      bool segmentRulesResult = _evaluateConditions(segment.segmentRules, null,
          evaluationContext, configSalt, segmentName, segments);

      SegmentComparator segmentComparator = SegmentComparator.values.firstWhere(
          (element) => element.id == segmentCondition.segmentComparator,
          orElse: () =>
              throw ArgumentError("Segment comparison operator is invalid."));

      switch (segmentComparator) {
        case SegmentComparator.isInSegment:
          result = segmentRulesResult;
          break;
        case SegmentComparator.isNotInSegment:
          result = !segmentRulesResult;
          break;
        default:
          throw ArgumentError("Segment comparison operator is invalid.");
      }
      //TODO fix logger evaluateLogger.logSegmentEvaluationResult(segmentCondition, segment, result, segmentRulesResult);
    } on RolloutEvaluatorException catch (evaluatorException) {
      //TODO add logger evaluateLogger.logSegmentEvaluationError(segmentCondition, segment, evaluatorException.getMessage());
      rethrow;
    }

    return result;
  }

  bool _evaluatePrerequisiteFlagCondition(
      PrerequisiteFlagCondition prerequisiteFlagCondition,
      EvaluationContext evaluationContext) {
    //TODO evaluateLogger.append(LogHelper.formatPrerequisiteFlagCondition(prerequisiteFlagCondition));

    String prerequisiteFlagKey = prerequisiteFlagCondition.prerequisiteFlagKey;
    Setting? prerequisiteFlagSetting =
        evaluationContext.settings[prerequisiteFlagKey];
    if (prerequisiteFlagKey.isEmpty ||
        prerequisiteFlagSetting == null) {
      throw ArgumentError("Prerequisite flag key is missing or invalid.");
    }

    int settingType = prerequisiteFlagSetting.type;
    if ((settingType == 0 &&
            prerequisiteFlagCondition.value?.booleanValue == null) ||
        (settingType == 1 &&
            prerequisiteFlagCondition.value?.stringValue == null) ||
        (settingType == 2 &&
            prerequisiteFlagCondition.value?.intValue == null) ||
        (settingType == 3 &&
            prerequisiteFlagCondition.value?.doubleValue == null)) {
      throw ArgumentError(
          "Type mismatch between comparison value '${prerequisiteFlagCondition.value}' and prerequisite flag '$prerequisiteFlagKey'.");
    }

    List<String>? visitedKeys = evaluationContext.visitedKeys;
    visitedKeys ??= [];
    visitedKeys.add(evaluationContext.key);
    if (visitedKeys.contains(prerequisiteFlagKey)) {
      String dependencyCycle = _LogHelper.formatCircularDependencyList(
          visitedKeys, prerequisiteFlagKey);
      throw ArgumentError(
          "Circular dependency detected between the following depending flags: $dependencyCycle.");
    }

    //TODO fix me evaluateLogger.logPrerequisiteFlagEvaluationStart(prerequisiteFlagKey);

    EvaluationContext prerequisiteFlagContext = EvaluationContext(
        prerequisiteFlagKey,
        evaluationContext.user,
        visitedKeys,
        evaluationContext.settings);

    EvaluationResult evaluateResult =
        _evaluateSetting(prerequisiteFlagSetting, prerequisiteFlagContext);

    PrerequisiteComparator prerequisiteComparator =
        PrerequisiteComparator.values.firstWhere(
            (element) =>
                element.id == prerequisiteFlagCondition.prerequisiteComparator,
            orElse: () => throw ArgumentError(
                "Prerequisite Flag comparison operator is invalid."));
    SettingsValue? conditionValue = prerequisiteFlagCondition.value;
    bool result;

    switch (prerequisiteComparator) {
      case PrerequisiteComparator.equals:
        result = conditionValue == evaluateResult.value;
        break;
      case PrerequisiteComparator.notEquals:
        result = conditionValue != evaluateResult.value;
        break;
      default:
        throw ArgumentError(
            "Prerequisite Flag comparison operator is invalid.");
    }

    //TODO fix Logger evaluateLogger.logPrerequisiteFlagEvaluationResult(prerequisiteFlagCondition, evaluateResult.value, result);

    return result;
  }

  EvaluationResult? _evaluatePercentageOptions(
      List<PercentageOption> percentageOptions,
      String percentageOptionAttribute,
      EvaluationContext evaluationContext,
      TargetingRule? parentTargetingRule) {
    if (evaluationContext.user == null) {
      //TODO eval log user missings
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        //TODO logger.warn 3001
      }
      return null;
    }
    String? percentageOptionAttributeValue;
    String percentageOptionAttributeName = percentageOptionAttribute;
    if (percentageOptionAttributeName.isEmpty) {
      percentageOptionAttributeName = "Identifier";
      percentageOptionAttributeValue = evaluationContext.user!.identifier;
    } else {
      percentageOptionAttributeValue =
          evaluationContext.user!.getAttribute(percentageOptionAttributeName);
      if (percentageOptionAttributeValue == null) {
        //TODO eval log
        //evaluateLogger.logPercentageOptionUserAttributeMissing(percentageOptionAttributeName);
        if (!evaluationContext.isUserAttributeMissing) {
          evaluationContext.isUserAttributeMissing = true;
          // TODO fix logger
          //this.logger.warn(3003, ConfigCatLogMessages.getUserAttributeMissing(context.getKey(), percentageOptionAttributeName));
        }
        return null;
      }
    }
    //TODO evaluateLogger.logPercentageOptionEvaluation(percentageOptionAttributeName);

    final hashCandidate =
        evaluationContext.key + percentageOptionAttributeValue;
    final userValueHash = sha1.convert(utf8.encode(hashCandidate));
    final hash = userValueHash.toString().substring(0, 7);
    final num = int.parse(hash, radix: 16);
    final scaled = num % 100;
    double bucket = 0;

    if (percentageOptions.isNotEmpty) {
      for (final rule in percentageOptions) {
        bucket += rule.percentage;
        if (scaled < bucket) {
          //TODO fix log
          // logEntries.add('Evaluating %% options. Returning ${rule.value}');
          return EvaluationResult(
              variationId: rule.variationId,
              value: rule.settingsValue,
              matchedTargetingRule: parentTargetingRule,
              matchedPercentageOption: rule);
        }
      }
    }
    return null;
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

class _LogHelper {
  static String formatCircularDependencyList(
      List<String> visitedKeys, String key) {
    StringBuffer builder = StringBuffer();
    for (String visitedKey in visitedKeys) {
      builder.write("'");
      builder.write(visitedKey);
      builder.write("' -> ");
    }
    builder.write("'");
    builder.write(key);
    builder.write("'");
    return builder.toString();
  }
}
