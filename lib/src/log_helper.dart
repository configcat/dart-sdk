import 'dart:math';

import 'package:configcat_client/src/rollout_evaluator.dart';
import 'package:intl/intl.dart';

import '../configcat_client.dart';
import 'json/user_comparator.dart';

class LogHelper {
  static final String _hashedValue = "<hashed value>";
  static final String _invalidValue = "<invalid value>";
  static final String _invalidName = "<invalid name>";
  static final String _invalidOperator = "<invalid operator>";
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
     UserComparator? userComparator = UserComparator.tryFrom(userCondition.comparator);

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

    return "User.${userCondition.comparisonAttribute} ${userComparator?.name ?? _invalidOperator } $comparisonValue";
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
