import 'package:json_annotation/json_annotation.dart';

import 'settings_value.dart';

part 'prerequisite_flag_condition.g.dart';

@JsonSerializable()
class PrerequisiteFlagCondition {

  @JsonKey(name: 'f')
  final String? prerequisiteFlagKey;

  /// The operator used in the comparison.
  ///
  /// 0  -> 'IS IN SEGMENT',
  /// 1  -> 'IS NOT IN SEGMENT',
  @JsonKey(name: 'c', defaultValue: 0)
  final int prerequisiteComparator;

  @JsonKey(name: 'v')
  final SettingsValue? value;

  PrerequisiteFlagCondition(
      this.prerequisiteFlagKey, this.prerequisiteComparator, this.value);

  factory PrerequisiteFlagCondition.fromJson(Map<String, dynamic> json) => _$PrerequisiteFlagConditionFromJson(json);
  Map<String, dynamic> toJson() => _$PrerequisiteFlagConditionToJson(this);
}