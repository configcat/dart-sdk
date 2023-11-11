import 'package:json_annotation/json_annotation.dart';

import 'percentage_option.dart';
import 'targeting_rule.dart';
import 'settings_value.dart';

part 'setting.g.dart';

// TODO do we need this?
// extension SettingConvert on Object {
//   /// Creates a basic [Setting] instance from an [Object].
//   Setting toSetting() {
//     return Setting(this, 0, [], [], '');
//   }
// }

//TODO add segments and salt as non seriazible variable
/// Describes a ConfigCat Feature Flag / Setting
@JsonSerializable()
class Setting {

  /// Value of the feature flag / setting.
  @JsonKey(name: 'v')
  final SettingsValue settingsValue;

  /// Type of the feature flag / setting.
  ///
  /// 0 -> [bool],
  /// 1 -> [String],
  /// 2 -> [int],
  /// 3 -> [double],
  @JsonKey(name: 't', defaultValue: 0)
  final int type;

  /// Collection of percentage options that belongs to the feature flag / setting.
  @JsonKey(name: 'p', defaultValue: [])
  final List<PercentageOption>? percentageOptions;

  /// Collection of targeting rules that belongs to the feature flag / setting.
  @JsonKey(name: 'r', defaultValue: [])
  final List<TargetingRule>? targetingRules;

  /// Variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  Setting(this.settingsValue, this.type, this.percentageOptions,
      this.targetingRules, this.variationId);

  factory Setting.fromJson(Map<String, dynamic> json) => _$SettingFromJson(json);
  Map<String, dynamic> toJson() => _$SettingToJson(this);
}
