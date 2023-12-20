import 'dart:convert';
import 'dart:math';

import 'package:configcat_client/src/log/logger.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
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
      Map<String, Setting> settings, EvaluateLogger evaluateLogger) {
    try {
      evaluateLogger.logEvaluation(key);

      if (user != null) {
        evaluateLogger.logUserObject(user);
      }
      evaluateLogger.increaseIndentLevel();

      EvaluationContext evaluationContext =
          EvaluationContext(key, user, null, settings);
      EvaluationResult evaluationResult =
          _evaluateSetting(setting, evaluationContext, evaluateLogger);

      evaluateLogger.logReturnValue(evaluationResult.value.toString());
      evaluateLogger.decreaseIndentLevel();
      return evaluationResult;
    } finally {
      _logger.info(5000, evaluateLogger.toPrint());
    }
  }

  EvaluationResult _evaluateSetting(Setting setting,
      EvaluationContext evaluationContext, EvaluateLogger evaluateLogger) {
    EvaluationResult? evaluationResult;
    if (setting.targetingRules.isNotEmpty) {
      evaluationResult =
          _evaluateTargetingRules(setting, evaluationContext, evaluateLogger);
    }
    if (evaluationResult == null && setting.percentageOptions.isNotEmpty) {
      evaluationResult = _evaluatePercentageOptions(setting.percentageOptions,
          setting.percentageAttribute, evaluationContext, null, evaluateLogger);
    }
    evaluationResult ??= EvaluationResult(
        variationId: setting.variationId,
        value: setting.settingsValue,
        matchedTargetingRule: null,
        matchedPercentageOption: null);

    return evaluationResult;
  }

  EvaluationResult? _evaluateTargetingRules(Setting setting,
      EvaluationContext evaluationContext, EvaluateLogger evaluateLogger) {
    evaluateLogger.logTargetingRules();
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
            setting.segments,
            evaluateLogger);
      } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
        error = rolloutEvaluatorException.message;
        evaluateConditionsResult = false;
      }

      if (!evaluateConditionsResult) {
        if (error != null) {
          evaluateLogger.logTargetingRuleIgnored();
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

      evaluateLogger.increaseIndentLevel();
      EvaluationResult? evaluatePercentageOptionsResult =
          _evaluatePercentageOptions(
              rule.percentageOptions!,
              setting.percentageAttribute,
              evaluationContext,
              rule,
              evaluateLogger);
      evaluateLogger.decreaseIndentLevel();

      if (evaluatePercentageOptionsResult == null) {
        evaluateLogger.logTargetingRuleIgnored();
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
      List<Segment> segments,
      EvaluateLogger evaluateLogger) {
    bool firstConditionFlag = true;
    bool conditionsEvaluationResult = false;
    String? error;
    bool newLine = false;
    for (ConditionAccessor condition in conditions) {
      if (firstConditionFlag) {
        firstConditionFlag = false;
        evaluateLogger.newLine();
        evaluateLogger.append("- IF ");
        evaluateLogger.increaseIndentLevel();
      } else {
        evaluateLogger.increaseIndentLevel();
        evaluateLogger.newLine();
        evaluateLogger.append("AND ");
      }

      final userCondition = condition.userCondition;
      final segmentCondition = condition.segmentCondition;
      final prerequisiteFlagCondition = condition.prerequisiteFlagCondition;
      if (userCondition != null) {
        try {
          conditionsEvaluationResult = _evaluateUserCondition(userCondition,
              evaluationContext, configSalt, contextSalt, evaluateLogger);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = conditions.length > 1;
      } else if (segmentCondition != null) {
        try {
          conditionsEvaluationResult = _evaluateSegmentCondition(
              segmentCondition,
              evaluationContext,
              configSalt,
              segments,
              evaluateLogger);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = userObjectIsMissing != error || conditions.length > 1;
      } else if (prerequisiteFlagCondition != null) {
        try {
          conditionsEvaluationResult = _evaluatePrerequisiteFlagCondition(
              prerequisiteFlagCondition, evaluationContext, evaluateLogger);
        } on RolloutEvaluatorException catch (rolloutEvaluatorException) {
          error = rolloutEvaluatorException.message;
          conditionsEvaluationResult = false;
        }
        newLine = error == null || conditions.length > 1;
      }

      if (targetingRule == null || conditions.length > 1) {
        evaluateLogger.logConditionConsequence(conditionsEvaluationResult);
      }
      evaluateLogger.decreaseIndentLevel();
      if (!conditionsEvaluationResult) {
        break;
      }
    }
    if (targetingRule != null) {
      evaluateLogger.logTargetingRuleConsequence(
          targetingRule, error, conditionsEvaluationResult, newLine);
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
      String contextSalt,
      EvaluateLogger evaluateLogger) {
    evaluateLogger.append(_LogHelper.formatUserCondition(userCondition));

    var configCatUser = evaluationContext.user;
    if (configCatUser == null) {
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
    Object? userAttributeValue =
        configCatUser.getAttribute(comparisonAttribute);

    if (userAttributeValue == null ||
        (userAttributeValue is String && userAttributeValue.isEmpty)) {
      _logger.warning(3003,
          "Cannot evaluate condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '${evaluationContext.key}' (the User.$comparisonAttribute attribute is missing). You should set the User.$comparisonAttribute attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      throw RolloutEvaluatorException(cannotEvaluateTheUserPrefix +
          comparisonAttribute +
          cannotEvaluateTheUserAttributeMissing);
    }

    switch (comparator) {
      case UserComparator.containsAnyOf:
      case UserComparator.notContainsAnyOf:
        bool negateContainsAnyOf =
            UserComparator.notContainsAnyOf == comparator;
        String userAttributeForContains = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateContainsAnyOf(
            negateContainsAnyOf, userCondition, userAttributeForContains);
      case UserComparator.semverIsOneOf:
      case UserComparator.semverIsNotOneOf:
        bool negateSemverIsOneOf =
            UserComparator.semverIsNotOneOf == comparator;
        Version userAttributeValueForSemverIsOneOf = _getUserAttributeAsVersion(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateSemverIsOneOf(
            userCondition,
            userAttributeValueForSemverIsOneOf,
            negateSemverIsOneOf,
            comparisonAttribute);
      case UserComparator.semverLess:
      case UserComparator.semverLessEquals:
      case UserComparator.semverGreater:
      case UserComparator.semverGreaterEquals:
        Version userAttributeValueForSemverOperators =
            _getUserAttributeAsVersion(evaluationContext.key, userCondition,
                comparisonAttribute, userAttributeValue);
        return _evaluateSemver(userAttributeValueForSemverOperators,
            userCondition, comparator, comparisonAttribute);
      case UserComparator.numberEquals:
      case UserComparator.numberNotEquals:
      case UserComparator.numberLess:
      case UserComparator.numberLessEquals:
      case UserComparator.numberGreater:
      case UserComparator.numberGreaterEquals:
        double userAttributeAsDouble = _getUserAttributeAsDouble(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateNumbers(userAttributeAsDouble, userCondition,
            comparator, comparisonAttribute);
      case UserComparator.isOneOf:
      case UserComparator.isNotOneOf:
      case UserComparator.sensitiveIsOneOf:
      case UserComparator.sensitiveIsNotOneOf:
        bool negateIsOneOf = UserComparator.sensitiveIsNotOneOf == comparator ||
            UserComparator.isNotOneOf == comparator;
        bool sensitiveIsOneOf = UserComparator.sensitiveIsOneOf == comparator ||
            UserComparator.sensitiveIsNotOneOf == comparator;
        String userAttributeForIsOneOf = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateIsOneOf(userCondition, sensitiveIsOneOf,
            userAttributeForIsOneOf, configSalt, contextSalt, negateIsOneOf);
      case UserComparator.dateBefore:
      case UserComparator.dateAfter:
        double userAttributeForDate = _getUserAttributeForDate(userCondition,
            evaluationContext, comparisonAttribute, userAttributeValue);
        return _evaluateDate(userAttributeForDate, userCondition, comparator,
            comparisonAttribute);
      case UserComparator.textEquals:
      case UserComparator.textNotEquals:
      case UserComparator.hashedEquals:
      case UserComparator.hashedNotEquals:
        bool negateEquals = UserComparator.hashedNotEquals == comparator ||
            UserComparator.textNotEquals == comparator;
        bool hashedEquals = UserComparator.hashedEquals == comparator ||
            UserComparator.hashedNotEquals == comparator;
        String userAttributeForEqual = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateEquals(hashedEquals, userAttributeForEqual, configSalt,
            contextSalt, userCondition, negateEquals);
      case UserComparator.hashedStartsWith:
      case UserComparator.hashedNotStartsWith:
      case UserComparator.hashedEndsWith:
      case UserComparator.hashedNotEndsWith:
        String userAttributeForHashedStartEndsWith = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateHashedStartOrEndWith(
            userAttributeForHashedStartEndsWith,
            userCondition,
            comparator,
            configSalt,
            contextSalt);
      case UserComparator.textStartsWith:
      case UserComparator.textNotStartsWith:
        bool negateTextStartWith =
            UserComparator.textNotStartsWith == comparator;
        String userAttributeFoTextStartWith = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateTextStartWith(
            userCondition, userAttributeFoTextStartWith, negateTextStartWith);
      case UserComparator.textEndsWith:
      case UserComparator.textNotEndsWith:
        bool negateTextEndsWith = UserComparator.textNotEndsWith == comparator;
        String userAttributeForTextEndsWith = _getUserAttributeAsString(
            evaluationContext.key,
            userCondition,
            comparisonAttribute,
            userAttributeValue);
        return _evaluateTextEndsWith(
            userCondition, userAttributeForTextEndsWith, negateTextEndsWith);
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
        List<String> userAttributeForArrayContains =
            _getUserAttributeAsStringList(userCondition, evaluationContext,
                comparisonAttribute, userAttributeValue);
        return _evaluateArrayContains(
            userCondition,
            userAttributeForArrayContains,
            comparisonAttribute,
            hashedArrayContains,
            configSalt,
            contextSalt,
            negateArrayContains);
      default:
        throw ArgumentError(comparisonOperatorIsInvalid);
    }
  }

  String _getUserAttributeAsString(String key, UserCondition userCondition,
      String userAttributeName, Object userAttributeValue) {
    if (userAttributeValue is String) {
      return userAttributeValue;
    }
    String? convertedUserAttribute = _userAttributeToString(userAttributeValue);
    _logger.warning(3005,
        "Evaluation of condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '$key' may not produce the expected result (the User.$userAttributeName attribute is not a string value, thus it was automatically converted to the string value '$convertedUserAttribute'). Please make sure that using a non-string value was intended.");
    return convertedUserAttribute;
  }

  Version _getUserAttributeAsVersion(String key, UserCondition userCondition,
      String comparisonAttribute, Object userValue) {
    if (userValue is String) {
      try {
        return _parseVersion(userValue.trim());
      } catch (e) {
        // Version parse failed continue with the RolloutEvaluatorException
      }
    }
    String reason = "'$userValue' is not a valid semantic version";
    _logger.warning(3004,
        "Cannot evaluate condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '$key' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
    throw RolloutEvaluatorException(
        "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
  }

  double _getUserAttributeAsDouble(String key, UserCondition userCondition,
      String comparisonAttribute, Object userAttributeValue) {
    double converted;
    try {
      if (userAttributeValue is double) {
        converted = userAttributeValue;
      } else {
        converted = _userAttributeToDouble(userAttributeValue);
      }
      if (converted.isNaN) {
        throw FormatException();
      }
      return converted;
    } catch (e) {
      //If cannot convert to double, continue with the error
      String reason = "'$userAttributeValue' is not a valid decimal number";
      _logger.warning(3004,
          "Cannot evaluate condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '$key' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  double _getUserAttributeForDate(
      UserCondition userCondition,
      EvaluationContext context,
      String comparisonAttribute,
      Object userAttributeValue) {
    try {
      if (userAttributeValue is DateTime) {
        return userAttributeValue.millisecondsSinceEpoch / 1000;
      }

      double attributeToDouble = _userAttributeToDouble(userAttributeValue);
      if (attributeToDouble.isNaN) {
        throw FormatException();
      }
      return attributeToDouble;
    } catch (e) {
      String reason =
          "'$userAttributeValue' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)";
      _logger.warning(3004,
          "Cannot evaluate condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '${context.key}' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
      throw RolloutEvaluatorException(
          "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
    }
  }

  List<String> _getUserAttributeAsStringList(
      UserCondition userCondition,
      EvaluationContext context,
      String comparisonAttribute,
      Object userAttributeValue) {
    try {
      if (userAttributeValue is List<String>) {
        return userAttributeValue;
      }
      if (userAttributeValue is Set<dynamic>) {
        return userAttributeValue.map((e) => e as String).toList();
      }
      if (userAttributeValue is String) {
        var decoded = jsonDecode(userAttributeValue);
        return List<String>.from(decoded);
      }
    } catch (e) {
      // String array parse failed continue with the RolloutEvaluatorException
    }
    String reason = "'$userAttributeValue' is not a valid JSON string array";
    _logger.warning(3004,
        "Cannot evaluate condition (${_LogHelper.formatUserCondition(userCondition)}) for setting '${context.key}' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
    throw RolloutEvaluatorException(
        "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
  }

  String _userAttributeToString(Object userAttribute) {
    if (userAttribute is String) {
      return userAttribute;
    }
    if (userAttribute is DateTime) {
      return (userAttribute.millisecondsSinceEpoch / 1000).toString();
    }
    return userAttribute.toString();
  }

  double _userAttributeToDouble(Object userAttribute) {
    if (userAttribute is double) {
      return userAttribute;
    }
    if (userAttribute is String) {
      return double.parse(userAttribute.trim().replaceAll(",", "."));
    }
    if (userAttribute is int) {
      return userAttribute.toDouble();
    }
    throw FormatException();
  }

  bool _evaluateArrayContains(
      UserCondition userCondition,
      List<String> userContainsValues,
      String comparisonAttribute,
      bool hashedArrayContains,
      String configSalt,
      String contextSalt,
      bool negateArrayContains) {
    List<String>? conditionContainsValues = userCondition.stringArrayValue;
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
          userValueSubString = utf8.decode(
              userAttributeValueUTF8.sublist(0, comparedTextLengthInt),
              allowMalformed: true);
        } else {
          //HASHED_ENDS_WITH & HASHED_NOT_ENDS_WITH
          userValueSubString = utf8.decode(
              userAttributeValueUTF8.sublist(
                  userAttributeValueUTF8.length - comparedTextLengthInt,
                  userAttributeValueUTF8.length),
              allowMalformed: true);
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

  bool _evaluateDate(double userDoubleValue, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    double? comparisonDoubleValue = userCondition.doubleValue;
    if (comparisonDoubleValue == null) {
      return false;
    }
    return (UserComparator.dateBefore == comparator &&
            userDoubleValue < comparisonDoubleValue) ||
        UserComparator.dateAfter == comparator &&
            userDoubleValue > comparisonDoubleValue;
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

  bool _evaluateNumbers(double uvDouble, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    final cvDouble = userCondition.doubleValue;
    if (cvDouble == null) {
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
  }

  bool _evaluateSemver(Version userValueVersion, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    try {
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
      return false;
    }
  }

  bool _evaluateSemverIsOneOf(UserCondition userCondition, Version userVersion,
      bool negateSemverIsOneOf, String comparisonAttribute) {
    List<String> containsValues =
        userCondition.stringArrayValue ?? List.empty();
    final filteredContainsValues = containsValues
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    try {
      var matched = false;
      for (final value in filteredContainsValues) {
        matched = _parseVersion(value) == userVersion || matched;
      }

      if (negateSemverIsOneOf) {
        matched = !matched;
      }
      return matched;
    } catch (e) {
      return false;
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
      List<Segment> segments,
      EvaluateLogger evaluateLogger) {
    int segmentIndex = segmentCondition.segmentIndex;
    Segment? segment;
    if (segmentIndex < segments.length) {
      segment = segments[segmentIndex];
    }
    evaluateLogger.append(
        _LogHelper.formatSegmentFlagCondition(segmentCondition, segment));

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
    evaluateLogger.logSegmentEvaluationStart(segmentName);

    bool result;
    try {
      bool segmentRulesResult = _evaluateConditions(segment.segmentRules, null,
          evaluationContext, configSalt, segmentName, segments, evaluateLogger);

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
      evaluateLogger.logSegmentEvaluationResult(
          segmentCondition, segment, result, segmentRulesResult);
    } on RolloutEvaluatorException catch (evaluatorException) {
      evaluateLogger.logSegmentEvaluationError(
          segmentCondition, segment, evaluatorException.message);
      rethrow;
    }

    return result;
  }

  bool _evaluatePrerequisiteFlagCondition(
      PrerequisiteFlagCondition prerequisiteFlagCondition,
      EvaluationContext evaluationContext,
      EvaluateLogger evaluateLogger) {
    evaluateLogger.append(
        _LogHelper.formatPrerequisiteFlagCondition(prerequisiteFlagCondition));

    String prerequisiteFlagKey = prerequisiteFlagCondition.prerequisiteFlagKey;
    Setting? prerequisiteFlagSetting =
        evaluationContext.settings[prerequisiteFlagKey];
    if (prerequisiteFlagKey.isEmpty || prerequisiteFlagSetting == null) {
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

    evaluateLogger.logPrerequisiteFlagEvaluationStart(prerequisiteFlagKey);

    EvaluationContext prerequisiteFlagContext = EvaluationContext(
        prerequisiteFlagKey,
        evaluationContext.user,
        visitedKeys,
        evaluationContext.settings);

    EvaluationResult evaluateResult = _evaluateSetting(
        prerequisiteFlagSetting, prerequisiteFlagContext, evaluateLogger);

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

    evaluateLogger.logPrerequisiteFlagEvaluationResult(
        prerequisiteFlagCondition, evaluateResult.value, result);

    return result;
  }

  EvaluationResult? _evaluatePercentageOptions(
      List<PercentageOption> percentageOptions,
      String? percentageOptionAttribute,
      EvaluationContext evaluationContext,
      TargetingRule? parentTargetingRule,
      EvaluateLogger evaluateLogger) {
    ConfigCatUser? contextUser = evaluationContext.user;
    if (contextUser == null) {
      evaluateLogger.logPercentageOptionUserMissing();
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()`/`getValueAsync()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      }
      return null;
    }
    String percentageOptionAttributeValue;
    String? percentageOptionAttributeName = percentageOptionAttribute;
    if (percentageOptionAttributeName == null ||
        percentageOptionAttributeName.isEmpty) {
      percentageOptionAttributeName = "Identifier";
      percentageOptionAttributeValue = evaluationContext.user!.identifier;
    } else {
      Object? userAttribute =
          contextUser.getAttribute(percentageOptionAttributeName);
      if (userAttribute == null) {
        evaluateLogger.logPercentageOptionUserAttributeMissing(
            percentageOptionAttributeName);
        if (!evaluationContext.isUserAttributeMissing) {
          evaluationContext.isUserAttributeMissing = true;
          _logger.warning(3003,
              "Cannot evaluate % options for setting '${evaluationContext.key}' (the User.$percentageOptionAttributeName attribute is missing). You should set the User.$percentageOptionAttributeName attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
        }
        return null;
      }
      percentageOptionAttributeValue = _userAttributeToString(userAttribute);
    }
    evaluateLogger.logPercentageOptionEvaluation(percentageOptionAttributeName);

    final hashCandidate =
        evaluationContext.key + percentageOptionAttributeValue;
    final userValueHash = sha1.convert(utf8.encode(hashCandidate));
    final hash = userValueHash.toString().substring(0, 7);
    final num = int.parse(hash, radix: 16);
    final scaled = num % 100;
    evaluateLogger.logPercentageOptionEvaluationHash(
        percentageOptionAttributeName, scaled);

    double bucket = 0;

    if (percentageOptions.isNotEmpty) {
      for (int i = 0; i < percentageOptions.length; i++) {
        var percentageOption = percentageOptions[i];
        bucket += percentageOption.percentage;
        if (scaled < bucket) {
          evaluateLogger.logPercentageEvaluationReturnValue(
              scaled,
              i,
              percentageOption.percentage.toInt(),
              percentageOption.settingsValue);
          return EvaluationResult(
              variationId: percentageOption.variationId,
              value: percentageOption.settingsValue,
              matchedTargetingRule: parentTargetingRule,
              matchedPercentageOption: percentageOption);
        }
      }
    }
    return null;
  }

  Version _parseVersion(String text) {
    // remove build parts, we don't want to compare by them.
    final buildCharPos = text.indexOf('+');
    return Version.parse(
        buildCharPos != -1 ? text.substring(0, buildCharPos) : text);
  }
}

class EvaluateLogger {
  int _indentLevel = 0;
  late bool _isLoggable;

  EvaluateLogger(LogLevel logLeve) {
    _isLoggable = logLeve.index <= LogLevel.info.index;
  }

  final StringBuffer _stringBuffer = StringBuffer();

  increaseIndentLevel() {
    if (!_isLoggable) {
      return;
    }
    _indentLevel++;
  }

  decreaseIndentLevel() {
    if (!_isLoggable) {
      return;
    }
    if (_indentLevel > 0) {
      _indentLevel--;
    }
  }

  newLine() {
    if (!_isLoggable) {
      return;
    }
    _stringBuffer.write("\n");
    for (int i = 0; i < _indentLevel; i++) {
      _stringBuffer.write("  ");
    }
  }

  append(final String line) {
    if (!_isLoggable) {
      return;
    }
    _stringBuffer.write(line);
  }

  String toPrint() {
    if (!_isLoggable) {
      return "";
    }
    return _stringBuffer.toString();
  }

  logUserObject(final ConfigCatUser user) {
    if (!_isLoggable) {
      return;
    }
    append(" for User '$user'");
  }

  logEvaluation(String key) {
    if (!_isLoggable) {
      return;
    }
    append("Evaluating '$key'");
  }

  logPercentageOptionUserMissing() {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append("Skipping % options because the User Object is missing.");
  }

  logPercentageOptionUserAttributeMissing(
      String percentageOptionsAttributeName) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append(
        "Skipping % options because the User.$percentageOptionsAttributeName attribute is missing.");
  }

  logPercentageOptionEvaluation(String percentageOptionsAttributeName) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append(
        "Evaluating % options based on the User.$percentageOptionsAttributeName attribute:");
  }

  logPercentageOptionEvaluationHash(
      String percentageOptionsAttributeName, int hashValue) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append(
        "- Computing hash in the [0..99] range from User.$percentageOptionsAttributeName => $hashValue (this value is sticky and consistent across all SDKs)");
  }

  logReturnValue(String returnValue) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append("Returning '$returnValue'.");
  }

  logTargetingRules() {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append("Evaluating targeting rules and applying the first match if any:");
  }

  logConditionConsequence(bool result) {
    if (!_isLoggable) {
      return;
    }
    append(" => $result");
    if (!result) {
      append(", skipping the remaining AND conditions");
    }
  }

  logTargetingRuleIgnored() {
    if (!_isLoggable) {
      return;
    }
    increaseIndentLevel();
    newLine();
    append(
        "The current targeting rule is ignored and the evaluation continues with the next rule.");
    decreaseIndentLevel();
  }

  logTargetingRuleConsequence(TargetingRule targetingRule, String? error,
      bool isMatch, bool isNewLine) {
    if (!_isLoggable) {
      return;
    }
    increaseIndentLevel();
    String valueFormat = "% options";
    if (targetingRule.servedValue != null) {
      valueFormat = "'${targetingRule.servedValue?.settingsValue}'";
    }
    if (isNewLine) {
      newLine();
    } else {
      append(" ");
    }
    append("THEN $valueFormat => ");
    if (error != null && error.isNotEmpty) {
      append(error);
    } else {
      if (isMatch) {
        append("MATCH, applying rule");
      } else {
        append("no match");
      }
    }
    decreaseIndentLevel();
  }

  logPercentageEvaluationReturnValue(
      int hashValue, int i, int percentage, SettingsValue settingsValue) {
    if (!_isLoggable) {
      return;
    }
    String percentageOptionValue = settingsValue.toString();
    newLine();
    append(
        "- Hash value $hashValue selects % option ${i + 1} ($percentage%), '$percentageOptionValue'.");
  }

  logSegmentEvaluationStart(String segmentName) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append("(");
    increaseIndentLevel();
    newLine();
    append("Evaluating segment '$segmentName':");
  }

  logSegmentEvaluationResult(SegmentCondition segmentCondition, Segment segment,
      bool result, bool segmentResult) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    String segmentResultComparator = segmentResult
        ? SegmentComparator.isInSegment.name
        : SegmentComparator.isNotInSegment.name;
    append("Segment evaluation result: User $segmentResultComparator.");
    newLine();
    append(
        "Condition (${_LogHelper.formatSegmentFlagCondition(segmentCondition, segment)}) evaluates to $result.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }

  logSegmentEvaluationError(
      SegmentCondition segmentCondition, Segment segment, String error) {
    if (!_isLoggable) {
      return;
    }
    newLine();

    append("Segment evaluation result: $error.");
    newLine();
    append(
        "Condition (${_LogHelper.formatSegmentFlagCondition(segmentCondition, segment)}) failed to evaluate.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }

  logPrerequisiteFlagEvaluationStart(String prerequisiteFlagKey) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    append("(");
    increaseIndentLevel();
    newLine();
    append("Evaluating prerequisite flag '$prerequisiteFlagKey':");
  }

  logPrerequisiteFlagEvaluationResult(
      PrerequisiteFlagCondition prerequisiteFlagCondition,
      SettingsValue prerequisiteFlagValue,
      bool result) {
    if (!_isLoggable) {
      return;
    }
    newLine();
    String prerequisiteFlagValueFormat = prerequisiteFlagValue.toString();
    append(
        "Prerequisite flag evaluation result: '$prerequisiteFlagValueFormat'.");
    newLine();
    append(
        "Condition (${_LogHelper.formatPrerequisiteFlagCondition(prerequisiteFlagCondition)}) evaluates to $result.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }
}

class _LogHelper {
  static final String _hashedValue = "<hashed value>";
  static final String _invalidValue = "<invalid value>";
  static final String _invalidName = "<invalid name>";
  static final String _invalidReference = "<invalid reference>";

  static final int _maxListElement = 10;

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

  static String formatUserCondition(UserCondition userCondition) {
    UserComparator userComparator = UserComparator.values.firstWhere(
        (element) => element.id == userCondition.comparator,
        orElse: () => throw ArgumentError(comparisonOperatorIsInvalid));
    String comparisonValue;
    switch (userComparator) {
      case UserComparator.isOneOf:
      case UserComparator.isNotOneOf:
      case UserComparator.containsAnyOf:
      case UserComparator.notContainsAnyOf:
      case UserComparator.semverIsOneOf:
      case UserComparator.semverIsNotOneOf:
      case UserComparator.textStartsWith:
      case UserComparator.textNotStartsWith:
      case UserComparator.textEndsWith:
      case UserComparator.textNotEndsWith:
      case UserComparator.textArrayContains:
      case UserComparator.textArrayNotContains:
        comparisonValue = _formatStringListComparisonValue(
            userCondition.stringArrayValue, false);
        break;
      case UserComparator.semverLess:
      case UserComparator.semverLessEquals:
      case UserComparator.semverGreater:
      case UserComparator.semverGreaterEquals:
      case UserComparator.textEquals:
      case UserComparator.textNotEquals:
        comparisonValue =
            _formatStringComparisonValue(userCondition.stringValue, false);
        break;
      case UserComparator.numberEquals:
      case UserComparator.numberNotEquals:
      case UserComparator.numberLess:
      case UserComparator.numberLessEquals:
      case UserComparator.numberGreater:
      case UserComparator.numberGreaterEquals:
        comparisonValue =
            _formatDoubleComparisonValue(userCondition.doubleValue, false);
        break;
      case UserComparator.sensitiveIsOneOf:
      case UserComparator.sensitiveIsNotOneOf:
      case UserComparator.hashedStartsWith:
      case UserComparator.hashedNotStartsWith:
      case UserComparator.hashedEndsWith:
      case UserComparator.hashedNotEndsWith:
      case UserComparator.hashedArrayContains:
      case UserComparator.hashedArrayNotContains:
        comparisonValue = _formatStringListComparisonValue(
            userCondition.stringArrayValue, true);
        break;
      case UserComparator.dateBefore:
      case UserComparator.dateAfter:
        comparisonValue =
            _formatDoubleComparisonValue(userCondition.doubleValue, true);
        break;
      case UserComparator.hashedEquals:
      case UserComparator.hashedNotEquals:
        comparisonValue =
            _formatStringComparisonValue(userCondition.stringValue, true);
        break;
      default:
        comparisonValue = _invalidName;
    }

    return "User.${userCondition.comparisonAttribute} ${userComparator.name} $comparisonValue";
  }

  static String formatSegmentFlagCondition(
      SegmentCondition segmentCondition, Segment? segment) {
    String? segmentName;
    if (segment != null) {
      segmentName = segment.name;
      if (segmentName == null || segmentName.isEmpty) {
        segmentName = _invalidName;
      }
    } else {
      segmentName = _invalidReference;
    }
    SegmentComparator segmentComparator = SegmentComparator.values.firstWhere(
        (element) => element.id == segmentCondition.segmentComparator,
        orElse: () =>
            throw ArgumentError("Segment comparison operator is invalid."));
    return "User ${segmentComparator.name} '$segmentName'";
  }

  static String formatPrerequisiteFlagCondition(
      PrerequisiteFlagCondition prerequisiteFlagCondition) {
    String prerequisiteFlagKey = prerequisiteFlagCondition.prerequisiteFlagKey;
    PrerequisiteComparator prerequisiteComparator =
        PrerequisiteComparator.values.firstWhere(
            (element) =>
                element.id == prerequisiteFlagCondition.prerequisiteComparator,
            orElse: () => throw ArgumentError(
                "Prerequisite Flag comparison operator is invalid."));
    SettingsValue? prerequisiteValue = prerequisiteFlagCondition.value;
    String comparisonValue = prerequisiteValue == null
        ? _invalidValue
        : prerequisiteValue.toString();
    return "Flag '$prerequisiteFlagKey' ${prerequisiteComparator.name} '$comparisonValue'";
  }

  static String _formatStringListComparisonValue(
      List<String>? comparisonValue, bool isSensitive) {
    if (comparisonValue == null || comparisonValue.isEmpty) {
      return _invalidValue;
    }

    String formattedList;
    if (isSensitive) {
      String sensitivePostFix =
          comparisonValue.length == 1 ? "value" : "values";
      formattedList = "<${comparisonValue.length} hashed $sensitivePostFix>";
    } else {
      String listPostFix = "";
      if (comparisonValue.length > _maxListElement) {
        int count = comparisonValue.length - _maxListElement;
        String countPostFix = count == 1 ? "value" : "values";
        listPostFix = ", ... <$count more $countPostFix>";
      }
      List<String> subList = comparisonValue.sublist(
          0, min(_maxListElement, comparisonValue.length));
      StringBuffer formatListBuilder = StringBuffer();
      int subListSize = subList.length;
      for (int i = 0; i < subListSize; i++) {
        formatListBuilder.write("'");
        formatListBuilder.write(subList[i]);
        formatListBuilder.write("'");
        if (i != subListSize - 1) {
          formatListBuilder.write(", ");
        }
      }
      formatListBuilder.write(listPostFix);
      formattedList = formatListBuilder.toString();
    }

    return "[$formattedList]";
  }

  static String _formatStringComparisonValue(
      String? comparisonValue, bool isSensitive) {
    return "'${isSensitive ? _hashedValue : comparisonValue}'";
  }

  static String _formatDoubleComparisonValue(
      double? comparisonValue, bool isDate) {
    if (comparisonValue == null) {
      return _invalidValue;
    }
    var decimalFormat = NumberFormat("0.######", "en");
    if (isDate) {
      var dateTimeInMilliseconds = comparisonValue * 1000;
      var dateTime = DateTime.fromMillisecondsSinceEpoch(
          isUtc: true, dateTimeInMilliseconds.toInt());

      return "'${decimalFormat.format(comparisonValue)}' (${dateTime.toIso8601String()} UTC)";
    }
    return "'${decimalFormat.format(comparisonValue)}'";
  }
}
