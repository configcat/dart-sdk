import 'package:json_annotation/json_annotation.dart';

import 'settings_value.dart';

part 'prerequisite_flag_condition.g.dart';

/// Describes a condition that is based on a prerequisite flag.
@JsonSerializable()
class PrerequisiteFlagCondition {
  /// The key of the prerequisite flag that the condition is based on.
  @JsonKey(name: 'f')
  final String prerequisiteFlagKey;

  /// The operator which defines the relation between the evaluated value of the prerequisite flag and the comparison value.
  @JsonKey(name: 'c')
  final int prerequisiteComparator;

  /// The value that the evaluated value of the prerequisite flag is compared to.
  /// Can be a value of the following types: {@link Boolean}, {@link String}, {@link Integer} or {@link Double}.
  @JsonKey(name: 'v')
  final SettingsValue? value;

  PrerequisiteFlagCondition(
      this.prerequisiteFlagKey, this.prerequisiteComparator, this.value);

  factory PrerequisiteFlagCondition.fromJson(Map<String, dynamic> json) =>
      _$PrerequisiteFlagConditionFromJson(json);
  Map<String, dynamic> toJson() => _$PrerequisiteFlagConditionToJson(this);
}
