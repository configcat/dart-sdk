import 'package:configcat_client/src/utils.dart';

import '../configcat_client.dart';
import 'json/segment_comparator.dart';
import 'log_helper.dart';

class EvaluateLogger {
  int _indentLevel = 0;

  final StringBuffer _stringBuffer = StringBuffer();

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
        "Condition (${LogHelper.formatSegmentFlagCondition(segmentCondition, segment)}) evaluates to $result.");
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
        "Condition (${LogHelper.formatSegmentFlagCondition(segmentCondition, segment)}) failed to evaluate.");
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
        "Condition (${LogHelper.formatPrerequisiteFlagCondition(prerequisiteFlagCondition)}) evaluates to $result.");
    decreaseIndentLevel();
    newLine();
    append(")");
  }
}
