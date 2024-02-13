import 'prerequisite_flag_condition.dart';
import 'segment_condition.dart';
import 'user_condition.dart';

abstract class ConditionAccessor {
  UserCondition? get userCondition;

  SegmentCondition? get segmentCondition;

  PrerequisiteFlagCondition? get prerequisiteFlagCondition;
}
