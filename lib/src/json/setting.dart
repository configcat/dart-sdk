import 'package:json_annotation/json_annotation.dart';

import 'percentage_rule.dart';
import 'rollout_rule.dart';

part 'setting.g.dart';

@JsonSerializable()
class Setting {
  @JsonKey(name: 'v')
  final dynamic value;

  @JsonKey(name: 't', defaultValue: 0)
  final int type;

  @JsonKey(name: 'p', defaultValue: [])
  final List<RolloutPercentageItem> percentageItems;

  @JsonKey(name: 'r', defaultValue: [])
  final List<RolloutRule> rolloutRules;

  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  Setting(this.value, this.type, this.percentageItems, this.rolloutRules,
      this.variationId);

  factory Setting.fromJson(Map<String, dynamic> json) =>
      _$SettingFromJson(json);

  Map<String, dynamic> toJson() => _$SettingToJson(this);
}
