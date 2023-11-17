import 'package:configcat_client/src/json/condition_accessor.dart';
import 'package:configcat_client/src/json/prerequisite_flag_condition.dart';
import 'package:configcat_client/src/json/segment_condition.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_condition.g.dart';

@JsonSerializable()
class UserCondition implements ConditionAccessor {
  @JsonKey(name: 'a')
  final String comparisonAttribute;

  @JsonKey(name: 'c')
  final int comparator;

  @JsonKey(name: 's')
  final String? stringValue;

  @JsonKey(name: 'd')
  final double? doubleValue;

  @JsonKey(name: 'l')
  final List<String>? stringArrayValue;

  UserCondition(this.comparisonAttribute, this.comparator, this.stringValue,
      this.doubleValue, this.stringArrayValue);

  factory UserCondition.fromJson(Map<String, dynamic> json) =>
      _$UserConditionFromJson(json);

  Map<String, dynamic> toJson() => _$UserConditionToJson(this);

  @override
  PrerequisiteFlagCondition? get prerequisiteFlagCondition {
    return null;
  }

  @override
  SegmentCondition? get segmentCondition {
    return null;
  }

  @override
  UserCondition? get userCondition {
    return this;
  }
}
