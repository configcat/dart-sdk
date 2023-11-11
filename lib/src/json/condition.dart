import 'package:json_annotation/json_annotation.dart';

import 'user_condition.dart';
import 'segment_condition.dart';
import 'prerequisite_flag_condition.dart';

part 'condition.g.dart';

//TODO add ConditionAccessor interface
@JsonSerializable()
class Condition {

  @JsonKey(name: 'u')
  final UserCondition? userCondition;

  @JsonKey(name: 's')
  final SegmentCondition? segmentCondition;

  @JsonKey(name: 'p')
  final PrerequisiteFlagCondition? prerequisiteFlagCondition;

  Condition(this.userCondition, this.segmentCondition,
      this.prerequisiteFlagCondition);

  factory Condition.fromJson(Map<String, dynamic> json) => _$ConditionFromJson(json);
  Map<String, dynamic> toJson() => _$ConditionToJson(this);
}