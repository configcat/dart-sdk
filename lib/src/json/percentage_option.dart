import 'package:json_annotation/json_annotation.dart';

import 'setting_value.dart';

part 'percentage_option.g.dart';

/// Represents a percentage option.
@JsonSerializable()
class PercentageOption {
  /// The value associated with the percentage option.
  /// Can be a value of the following types: {@link Boolean}, {@link String}, {@link Integer} or {@link Double}.
  @JsonKey(name: 'v')
  final SettingValue settingValue;

  /// A number between 0 and 100 that represents a randomly allocated fraction of the users.
  @JsonKey(name: 'p', defaultValue: 0)
  final double percentage;

  /// Variation ID.
  @JsonKey(name: 'i')
  final String? variationId;

  PercentageOption(this.settingValue, this.percentage, this.variationId);

  factory PercentageOption.fromJson(Map<String, dynamic> json) =>
      _$PercentageOptionFromJson(json);
  Map<String, dynamic> toJson() => _$PercentageOptionToJson(this);
}
