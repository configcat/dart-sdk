import 'package:json_annotation/json_annotation.dart';

import 'settings_value.dart';

part 'percentage_option.g.dart';

@JsonSerializable()
class PercentageOption {

  /// Value served when the rule is selected during evaluation.
  @JsonKey(name: 'v')
  final SettingsValue settingsValue;

  /// The rule's percentage value.
  @JsonKey(name: 'p', defaultValue: 0)
  final double percentage;

  /// The rule's variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  PercentageOption(this.settingsValue, this.percentage, this.variationId);

  factory PercentageOption.fromJson(Map<String, dynamic> json) => _$PercentageOptionFromJson(json);
  Map<String, dynamic> toJson() => _$PercentageOptionToJson(this);

}
