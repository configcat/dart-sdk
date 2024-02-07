import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pub_semver/pub_semver.dart';

import 'configcat_user.dart';
import 'evaluate_logger.dart';
import 'json/condition_accessor.dart';
import 'json/percentage_option.dart';
import 'json/segment.dart';
import 'json/targeting_rule.dart';
import 'json/setting.dart';
import 'json/prerequisite_flag_condition.dart';
import 'json/segment_condition.dart';
import 'json/settings_value.dart';
import 'json/user_comparator.dart';
import 'json/user_condition.dart';
import 'log/configcat_logger.dart';
import 'log_helper.dart';

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
      Map<String, Setting> settings, EvaluateLogger? evaluateLogger) {
    try {
      evaluateLogger?.logEvaluation(key);

      if (user != null) {
        evaluateLogger?.logUserObject(user);
      }
      evaluateLogger?.increaseIndentLevel();

      EvaluationContext evaluationContext =
          EvaluationContext(key, user, null, settings);
      EvaluationResult evaluationResult =
          _evaluateSetting(setting, evaluationContext, evaluateLogger);

      evaluateLogger?.logReturnValue(evaluationResult.value.toString());
      evaluateLogger?.decreaseIndentLevel();
      return evaluationResult;
    } finally {
      if (evaluateLogger != null) {
        _logger.info(5000, evaluateLogger.toPrint());
      }
    }
  }

  EvaluationResult _evaluateSetting(Setting setting,
      EvaluationContext evaluationContext, EvaluateLogger? evaluateLogger) {
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
      EvaluationContext evaluationContext, EvaluateLogger? evaluateLogger) {
    evaluateLogger?.logTargetingRules();
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
          evaluateLogger?.logTargetingRuleIgnored();
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

      evaluateLogger?.increaseIndentLevel();
      EvaluationResult? evaluatePercentageOptionsResult =
          _evaluatePercentageOptions(
              rule.percentageOptions!,
              setting.percentageAttribute,
              evaluationContext,
              rule,
              evaluateLogger);
      evaluateLogger?.decreaseIndentLevel();

      if (evaluatePercentageOptionsResult == null) {
        evaluateLogger?.logTargetingRuleIgnored();
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
      EvaluateLogger? evaluateLogger) {
    bool firstConditionFlag = true;
    bool conditionsEvaluationResult = true;
    String? error;
    bool newLine = false;
    for (ConditionAccessor condition in conditions) {
      if (firstConditionFlag) {
        firstConditionFlag = false;
        evaluateLogger?.newLine();
        evaluateLogger?.append("- IF ");
        evaluateLogger?.increaseIndentLevel();
      } else {
        evaluateLogger?.increaseIndentLevel();
        evaluateLogger?.newLine();
        evaluateLogger?.append("AND ");
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
        evaluateLogger?.logConditionConsequence(conditionsEvaluationResult);
      }
      evaluateLogger?.decreaseIndentLevel();
      if (!conditionsEvaluationResult) {
        break;
      }
    }
    if (targetingRule != null) {
      evaluateLogger?.logTargetingRuleConsequence(
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
      EvaluateLogger? evaluateLogger) {
    evaluateLogger?.append(LogHelper.formatUserCondition(userCondition));

    var configCatUser = evaluationContext.user;
    if (configCatUser == null) {
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      }
      throw RolloutEvaluatorException(userObjectIsMissing);
    }

    String comparisonAttribute = userCondition.comparisonAttribute;
    UserComparator comparator = UserComparator.tryFrom(userCondition.comparator)
      ?? (() => throw ArgumentError(comparisonOperatorIsInvalid))();

    Object? userAttributeValue =
        configCatUser.getAttribute(comparisonAttribute);

    if (userAttributeValue == null ||
        (userAttributeValue is String && userAttributeValue.isEmpty)) {
      _logger.warning(3003,
          "Cannot evaluate condition (${LogHelper.formatUserCondition(userCondition)}) for setting '${evaluationContext.key}' (the User.$comparisonAttribute attribute is missing). You should set the User.$comparisonAttribute attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
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
    }
  }

  String _getUserAttributeAsString(String key, UserCondition userCondition,
      String userAttributeName, Object userAttributeValue) {
    if (userAttributeValue is String) {
      return userAttributeValue;
    }
    String? convertedUserAttribute = _userAttributeToString(userAttributeValue);
    _logger.warning(3005,
        "Evaluation of condition (${LogHelper.formatUserCondition(userCondition)}) for setting '$key' may not produce the expected result (the User.$userAttributeName attribute is not a string value, thus it was automatically converted to the string value '$convertedUserAttribute'). Please make sure that using a non-string value was intended.");
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
        "Cannot evaluate condition (${LogHelper.formatUserCondition(userCondition)}) for setting '$key' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
    throw RolloutEvaluatorException(
        "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
  }

  double _getUserAttributeAsDouble(String key, UserCondition userCondition,
      String comparisonAttribute, Object userAttributeValue) {
    try {
      if (userAttributeValue is double) {
        return userAttributeValue;
      } else {
        return _userAttributeToDouble(userAttributeValue);
      }
    } catch (e) {
      //If cannot convert to double, continue with the error
      String reason = "'$userAttributeValue' is not a valid decimal number";
      _logger.warning(3004,
          "Cannot evaluate condition (${LogHelper.formatUserCondition(userCondition)}) for setting '$key' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
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
      return _userAttributeToDouble(userAttributeValue);
    } catch (e) {
      String reason =
          "'$userAttributeValue' is not a valid Unix timestamp (number of seconds elapsed since Unix epoch)";
      _logger.warning(3004,
          "Cannot evaluate condition (${LogHelper.formatUserCondition(userCondition)}) for setting '${context.key}' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
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
      List<String>? result;
      if (userAttributeValue is List<String>) {
        result = userAttributeValue;
      }
      if (userAttributeValue is Set<String>) {
        result = userAttributeValue.toList();
      }
      if (userAttributeValue is String) {
        var decoded = jsonDecode(userAttributeValue);
        result = List<String>.from(decoded);
      }
      if (result != null && !result.contains(null)) {
        return result;
      }
    } catch (e) {
      // String array parse failed continue with the RolloutEvaluatorException
    }
    String reason = "'$userAttributeValue' is not a valid JSON string array";
    _logger.warning(3004,
        "Cannot evaluate condition (${LogHelper.formatUserCondition(userCondition)}) for setting '${context.key}' ($reason). Please check the User.$comparisonAttribute attribute and make sure that its value corresponds to the comparison operator.");
    throw RolloutEvaluatorException(
        "$cannotEvaluateTheUserPrefix$comparisonAttribute$cannotEvaluateTheUserAttributeInvalid$reason)");
  }

  String _userAttributeToString(Object userAttribute) {
    if (userAttribute is String) {
      return userAttribute;
    }
    if (userAttribute is List) {
      return jsonEncode(userAttribute);
    }
    if (userAttribute is DateTime) {
      return (userAttribute.millisecondsSinceEpoch / 1000).toString();
    }
    // TODO add doouble parse?
    return userAttribute.toString();
  }

  double _userAttributeToDouble(Object userAttribute) {
    if (userAttribute is double) {
      return userAttribute;
    }
    if (userAttribute is String) {
      return double.parse(userAttribute.trim().replaceAll(",", "."));
    }
    if (userAttribute is num) {
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
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);
    if (userContainsValues.isEmpty) {
      return false;
    }

    for (String userContainsValue in userContainsValues) {
      String userContainsValueConverted = hashedArrayContains
          ? _getSaltedUserValue(userContainsValue, configSalt, contextSalt)
          : userContainsValue;

      for (String inValuesElement in comparisonValues) {
        if (_ensureComparisonValue(inValuesElement) ==
            userContainsValueConverted) {
          return !negateArrayContains;
        }
      }
    }
    return negateArrayContains;
  }

  bool _evaluateTextEndsWith(UserCondition userCondition,
      String userAttributeValue, bool negateTextEndsWith) {
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);

    for (String textValue in comparisonValues) {
      if (userAttributeValue.endsWith(_ensureComparisonValue(textValue))) {
        return !negateTextEndsWith;
      }
    }
    return negateTextEndsWith;
  }

  bool _evaluateTextStartWith(UserCondition userCondition,
      String userAttributeValue, bool negateTextStartWith) {
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);

    for (String textValue in comparisonValues) {
      if (userAttributeValue.startsWith(_ensureComparisonValue(textValue))) {
        return !negateTextStartWith;
      }
    }
    return negateTextStartWith;
  }

  bool _evaluateHashedStartOrEndWith(
      String userAttributeValue,
      UserCondition userCondition,
      UserComparator comparator,
      String configSalt,
      String contextSalt) {
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);
    List<int> userAttributeValueUTF8 = utf8.encode(userAttributeValue);

    bool foundEqual = false;
    for (String comparisonValueHashedStartsEnds in comparisonValues) {
      int indexOf =
          _ensureComparisonValue(comparisonValueHashedStartsEnds).indexOf("_");
      if (indexOf <= 0) {
        throw ArgumentError(comparisonValueIsMissingOrInvalid);
      }
      String comparedTextLength =
          comparisonValueHashedStartsEnds.substring(0, indexOf);
      int comparedTextLengthInt;
      try {
        comparedTextLengthInt = int.parse(comparedTextLength);
      } catch (e) {
        throw ArgumentError(comparisonValueIsMissingOrInvalid);
      }
      if (userAttributeValueUTF8.length < comparedTextLengthInt) {
        continue;
      }
      String comparisonHashValue =
          comparisonValueHashedStartsEnds.substring(indexOf + 1);
      if (comparisonHashValue.isEmpty) {
        throw ArgumentError(comparisonValueIsMissingOrInvalid);
      }
      List<int> userValueSubStringByteArray;
      if (UserComparator.hashedStartsWith == comparator ||
          UserComparator.hashedNotStartsWith == comparator) {
        userValueSubStringByteArray =
            userAttributeValueUTF8.sublist(0, comparedTextLengthInt);
      } else {
        //HASHED_ENDS_WITH & HASHED_NOT_ENDS_WITH
        userValueSubStringByteArray = userAttributeValueUTF8.sublist(
            userAttributeValueUTF8.length - comparedTextLengthInt,
            userAttributeValueUTF8.length);
      }
      String hashUserValueSub = _getSaltedUserValueSlice(
          userValueSubStringByteArray, configSalt, contextSalt);
      if (hashUserValueSub == comparisonHashValue) {
        foundEqual = true;
        break;
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
    String comparisonValue = _ensureComparisonValue(userCondition.stringValue);

    String valueEquals = hashedEquals
        ? _getSaltedUserValue(userAttributeValue, configSalt, contextSalt)
        : userAttributeValue;
    return negateEquals != (valueEquals == comparisonValue);
  }

  bool _evaluateDate(double userDoubleValue, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    double comparisonDoubleValue =
        _ensureComparisonValue(userCondition.doubleValue);
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
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);

    String userIsOneOfValue = sensitiveIsOneOf
        ? _getSaltedUserValue(userAttributeValue, configSalt, contextSalt)
        : userAttributeValue;

    for (String inValuesElement in comparisonValues) {
      if (_ensureComparisonValue(inValuesElement) == userIsOneOfValue) {
        return !negateIsOneOf;
      }
    }
    return negateIsOneOf;
  }

  String _getSaltedUserValue(
      String userValue, String configSalt, String contextSalt) {
    return sha256
        .convert(utf8.encode(userValue + configSalt + contextSalt))
        .toString();
  }

  String _getSaltedUserValueSlice(
      List<int> userValueSliceUTF8, String configSalt, String contextSalt) {
    List<int> configSaltByteArray = utf8.encode(configSalt);
    List<int> contextSaltByteArray = utf8.encode(contextSalt);

    List<int> concatByteArrays =
        userValueSliceUTF8 + configSaltByteArray + contextSaltByteArray;

    return sha256.convert(concatByteArrays).toString();
  }

  bool _evaluateNumbers(double uvDouble, UserCondition userCondition,
      UserComparator comparator, String comparisonAttribute) {
    final cvDouble = _ensureComparisonValue(userCondition.doubleValue);
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
    final comparisonValue = _ensureComparisonValue(userCondition.stringValue);
    try {
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
    List<String> comparisonValues =
        _ensureComparisonValue(userCondition.stringArrayValue);

    var matched = false;
    for (final value in comparisonValues) {
      if (_ensureComparisonValue(value).isEmpty) {
        continue;
      }
      try {
        matched = _parseVersion(value.trim()) == userVersion || matched;
      } catch (e) {
        return false;
      }
    }
    return negateSemverIsOneOf != matched;
  }

  bool _evaluateContainsAnyOf(bool negateContainsAnyOf,
      UserCondition userCondition, String userAttributeValue) {
    List<String> comparisonValues =
        _ensureComparisonValue<List<String>>(userCondition.stringArrayValue);

    for (String containsValue in comparisonValues) {
      if (userAttributeValue.contains(_ensureComparisonValue(containsValue))) {
        return !negateContainsAnyOf;
      }
    }
    return negateContainsAnyOf;
  }

  bool _evaluateSegmentCondition(
      SegmentCondition segmentCondition,
      EvaluationContext evaluationContext,
      String configSalt,
      List<Segment> segments,
      EvaluateLogger? evaluateLogger) {
    int segmentIndex = segmentCondition.segmentIndex;
    Segment? segment;
    if (segmentIndex < segments.length) {
      segment = segments[segmentIndex];
    }
    evaluateLogger?.append(
        LogHelper.formatSegmentFlagCondition(segmentCondition, segment));

    if (evaluationContext.user == null) {
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
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
    evaluateLogger?.logSegmentEvaluationStart(segmentName);

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
      evaluateLogger?.logSegmentEvaluationResult(
          segmentCondition, segment, result, segmentRulesResult);
    } on RolloutEvaluatorException catch (evaluatorException) {
      evaluateLogger?.logSegmentEvaluationError(
          segmentCondition, segment, evaluatorException.message);
      rethrow;
    }

    return result;
  }

  bool _evaluatePrerequisiteFlagCondition(
      PrerequisiteFlagCondition prerequisiteFlagCondition,
      EvaluationContext evaluationContext,
      EvaluateLogger? evaluateLogger) {
    evaluateLogger?.append(
        LogHelper.formatPrerequisiteFlagCondition(prerequisiteFlagCondition));

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
      String dependencyCycle = LogHelper.formatCircularDependencyList(
          visitedKeys, prerequisiteFlagKey);
      throw ArgumentError(
          "Circular dependency detected between the following depending flags: $dependencyCycle.");
    }

    evaluateLogger?.logPrerequisiteFlagEvaluationStart(prerequisiteFlagKey);

    EvaluationContext prerequisiteFlagContext = EvaluationContext(
        prerequisiteFlagKey,
        evaluationContext.user,
        visitedKeys,
        evaluationContext.settings);

    EvaluationResult evaluateResult = _evaluateSetting(
        prerequisiteFlagSetting, prerequisiteFlagContext, evaluateLogger);

    visitedKeys.remove(evaluationContext.key);

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

    evaluateLogger?.logPrerequisiteFlagEvaluationResult(
        prerequisiteFlagCondition, evaluateResult.value, result);

    return result;
  }

  EvaluationResult? _evaluatePercentageOptions(
      List<PercentageOption> percentageOptions,
      String? percentageOptionAttribute,
      EvaluationContext evaluationContext,
      TargetingRule? parentTargetingRule,
      EvaluateLogger? evaluateLogger) {
    ConfigCatUser? contextUser = evaluationContext.user;
    if (contextUser == null) {
      evaluateLogger?.logPercentageOptionUserMissing();
      if (!evaluationContext.isUserMissing) {
        evaluationContext.isUserMissing = true;
        _logger.warning(3001,
            "Cannot evaluate targeting rules and % options for setting '${evaluationContext.key}' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/");
      }
      return null;
    }
    String percentageOptionAttributeValue;
    String? percentageOptionAttributeName = percentageOptionAttribute;
    if (percentageOptionAttributeName == null) {
      percentageOptionAttributeName = "Identifier";
      percentageOptionAttributeValue = evaluationContext.user!.identifier;
    } else {
      Object? userAttribute =
          contextUser.getAttribute(percentageOptionAttributeName);
      if (userAttribute == null) {
        evaluateLogger?.logPercentageOptionUserAttributeMissing(
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
    evaluateLogger
        ?.logPercentageOptionEvaluation(percentageOptionAttributeName);

    final hashCandidate =
        evaluationContext.key + percentageOptionAttributeValue;
    final userValueHash = sha1.convert(utf8.encode(hashCandidate));
    final hash = userValueHash.toString().substring(0, 7);
    final num = int.parse(hash, radix: 16);
    final scaled = num % 100;
    evaluateLogger?.logPercentageOptionEvaluationHash(
        percentageOptionAttributeName, scaled);

    double bucket = 0;

    if (percentageOptions.isNotEmpty) {
      for (int i = 0; i < percentageOptions.length; i++) {
        var percentageOption = percentageOptions[i];
        bucket += percentageOption.percentage;
        if (scaled < bucket) {
          evaluateLogger?.logPercentageEvaluationReturnValue(
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
    throw ArgumentError(
        "Sum of percentage option percentages are less than 100.");
  }

  Version _parseVersion(String text) {
    // remove build parts, we don't want to compare by them.
    final buildCharPos = text.indexOf('+');
    return Version.parse(
        buildCharPos != -1 ? text.substring(0, buildCharPos) : text);
  }

  T _ensureComparisonValue<T>(T? value) {
    if (value == null) {
      throw ArgumentError("Comparison value is missing or invalid.");
    }
    return value;
  }
}
