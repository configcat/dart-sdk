import 'package:json_annotation/json_annotation.dart';

import 'condition_accessor.dart';
import 'user_condition.dart';
import 'segment_condition.dart';
import 'prerequisite_flag_condition.dart';

part 'condition.g.dart';

/// Represents a condition.
@JsonSerializable()
class Condition implements ConditionAccessor {
  @override
  @JsonKey(name: 'u')
  final UserCondition? userCondition;

  @override
  @JsonKey(name: 's')
  final SegmentCondition? segmentCondition;

  @override
  @JsonKey(name: 'p')
  final PrerequisiteFlagCondition? prerequisiteFlagCondition;

  Condition(this.userCondition, this.segmentCondition,
      this.prerequisiteFlagCondition);

  factory Condition.fromJson(Map<String, dynamic> json) =>
      _$ConditionFromJson(json);
  Map<String, dynamic> toJson() => _$ConditionToJson(this);
}
