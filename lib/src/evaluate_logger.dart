import 'dart:math';

import 'package:configcat_client/src/utils.dart';

import '../configcat_client.dart';
import 'json/prerequisite_comparator.dart';
import 'json/segment_comparator.dart';
import 'json/user_comparator.dart';

class EvaluateLogger {
  static final String _hashedValue = "<hashed value>";
  static final String _invalidValue = "<invalid value>";
  static final String _invalidName = "<invalid name>";
  static final String _invalidOperator = "<invalid operator>";
  static final String _invalidReference = "<invalid reference>";

  static final int _maxListElement = 10;

  final StringBuffer _stringBuffer = StringBuffer();

  int _indentLevel = 0;

  increaseIndentLevel() {
    _indentLevel++;
  }

  decreaseIndentLevel() {
    if (_indentLevel > 0) {
      _indentLevel--;
    }
  }

  newLine() {
    _stringBuffer.write(Utils.lineTerminator);
    for (int i = 0; i < _indentLevel; i++) {
      _stringBuffer.write("  ");
    }
  }

  append(final String line) {
    _stringBuffer.write(line);
  }

  String toPrint() {
    return _stringBuffer.toString();
  }

  logUserObject(final ConfigCatUser user) {
    append(" for User '$user'");
  }

  logEvaluation(String key) {
    append("Evaluating '$key'");
  }

  logPercentageOptionUserMissing() {
    newLine();
    append("Skipping % options because the User Object is missing.");
  }

  logPercentageOptionUserAttributeMissing(
      String percentageOptionsAttributeName) {
    newLine();
    append(
        "Skipping % options because the User.$percentageOptionsAttributeName attribute is missing.");
  }

  logPercentageOptionEvaluation(String percentageOptionsAttributeName) {
    newLine();
    append(
        "Evaluating % options based on the User.$percentageOptionsAttributeName attribute:");
  }

  logPercentageOptionEvaluationHash(
      String percentageOptionsAttributeName, int hashValue) {
    newLine();
    append(
        "- Computing hash in the [0..99] range from User.$percentageOptionsAttributeName => $hashValue (this value is sticky and consistent across all SDKs)");
  }

  logReturnValue(String returnValue) {
    newLine();
    append("Returning '$returnValue'.");
  }

  logTargetingRules() {
    newLine();
    append("Evaluating targeting rules and applying the first match if any:");
  }

  logConditionConsequence(bool result) {
    append(" => $result");
    if (!result) {
      append(", skipping the remaining AND conditions");
    }
  }

  logTargetingRuleIgnored() {
    increaseIndentLevel();
    newLine();
    append(
        "The current targeting rule is ignored and the evaluation continues with the next rule.");
    decreaseIndentLevel();
  }

  logTargetingRuleConsequence(TargetingRule targetingRule, String? error,
      bool isMatch, bool isNewLine) {
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
    String percentageOptionValue = settingsValue.toString();
    newLine();
    append(
        "- Hash value $hashValue selects % option ${i + 1} ($percentage%), '$percentageOptionValue'.");
  }

  logSegmentEvaluationStart(String segmentName) {
    newLine();
    append("(");
    increaseIndentLevel();
    newLine();
    append("Evaluating segment '$segmentName':");
  }

  logSegmentEvaluationResult(SegmentCondition segmentCondition, Segment segment,
      bool result, bool segmentResult) {
    newLine();
    String segmentResultComparator = segmentResult
        ? SegmentComparator.isInSegment.name
        : SegmentComparator.isNotInSegment.name;
    append("Segment evaluation result: User $segmentResultComparator.");
    newLine();
    append(
        "Condition (${formatSegmentFlagCondition(segmentCondition, segment)}) evaluates to $result.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }

  logSegmentEvaluationError(
      SegmentCondition segmentCondition, Segment segment, String error) {
    newLine();

    append("Segment evaluation result: $error.");
    newLine();
    append(
        "Condition (${formatSegmentFlagCondition(segmentCondition, segment)}) failed to evaluate.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }

  logPrerequisiteFlagEvaluationStart(String prerequisiteFlagKey) {
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
    newLine();
    String prerequisiteFlagValueFormat = prerequisiteFlagValue.toString();
    append(
        "Prerequisite flag evaluation result: '$prerequisiteFlagValueFormat'.");
    newLine();
    append(
        "Condition (${formatPrerequisiteFlagCondition(prerequisiteFlagCondition)}) evaluates to $result.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }

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
    UserComparator? userComparator =
        UserComparator.tryFrom(userCondition.comparator);

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
        comparisonValue = _invalidValue;
    }

    return "User.${userCondition.comparisonAttribute} ${userComparator?.name ?? _invalidOperator} $comparisonValue";
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
    SegmentComparator? segmentComparator =
        SegmentComparator.tryFrom(segmentCondition.segmentComparator);
    return "User ${segmentComparator?.name ?? _invalidOperator} '$segmentName'";
  }

  static String formatPrerequisiteFlagCondition(
      PrerequisiteFlagCondition prerequisiteFlagCondition) {
    String prerequisiteFlagKey = prerequisiteFlagCondition.prerequisiteFlagKey;
    PrerequisiteComparator? prerequisiteComparator =
        PrerequisiteComparator.tryFrom(
            prerequisiteFlagCondition.prerequisiteComparator);

    SettingsValue? prerequisiteValue = prerequisiteFlagCondition.value;
    String comparisonValue = prerequisiteValue == null
        ? _invalidValue
        : prerequisiteValue.toString();
    return "Flag '$prerequisiteFlagKey' ${prerequisiteComparator?.name ?? _invalidOperator} '$comparisonValue'";
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
    var comparisonValueFormatted = comparisonValue
        .toString()
        .replaceAllMapped(RegExp(r'\.0+(e|$)'), (m) => m[1]!);
    if (isDate) {
      var dateTimeInMilliseconds = comparisonValue * 1000;
      var dateTime = DateTime.fromMillisecondsSinceEpoch(
          isUtc: true, dateTimeInMilliseconds.toInt());

      return "'$comparisonValueFormatted' (${dateTime.toIso8601String()} UTC)";
    }
    return "'$comparisonValueFormatted'";
  }
}
