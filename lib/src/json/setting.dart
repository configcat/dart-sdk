import 'package:json_annotation/json_annotation.dart';

import 'percentage_rule.dart';
import 'rollout_rule.dart';

part 'setting.g.dart';

extension SettingConvert on Object {
  /// Creates a basic [Setting] instance from an [Object].
  Setting toSetting() {
    return Setting(this, 0, [], [], '');
  }
}

/// Describes a ConfigCat Feature Flag / Setting
@JsonSerializable()
class Setting {
  /// Value of the feature flag / setting.
  @JsonKey(name: 'v')
  final dynamic value;

  /// Type of the feature flag / setting.
  ///
  /// 0 -> [bool],
  /// 1 -> [String],
  /// 2 -> [int],
  /// 3 -> [double],
  @JsonKey(name: 't', defaultValue: 0)
  final int type;

  /// Collection of percentage rules that belongs to the feature flag / setting.
  @JsonKey(name: 'p', defaultValue: [])
  final List<PercentageRule> percentageItems;

  /// Collection of targeting rules that belongs to the feature flag / setting.
  @JsonKey(name: 'r', defaultValue: [])
  final List<RolloutRule> rolloutRules;

  /// Variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  Setting(this.value, this.type, this.percentageItems, this.rolloutRules,
      this.variationId);

  factory Setting.fromJson(Map<String, dynamic> json) =>
      _$SettingFromJson(json);

  Map<String, dynamic> toJson() => _$SettingToJson(this);
}
