import 'package:json_annotation/json_annotation.dart';

import 'percentage_option.dart';
import 'segment.dart';
import 'targeting_rule.dart';
import 'settings_value.dart';

part 'setting.g.dart';

extension SettingConvert on Object {
  /// Creates a basic [Setting] instance from an [Object].
  Setting toSetting() {
    SettingsValue settingsValue;
    int settingType;
    if (this is bool) {
      settingsValue = SettingsValue(this as bool?, null, null, null);
      settingType = 0;
    } else if (this is String) {
      settingsValue = SettingsValue(null, this as String?, null, null);
      settingType = 1;
    } else if (this is int) {
      settingsValue = SettingsValue(null, null, this as int?, null);
      settingType = 2;
    } else if (this is double) {
      settingsValue = SettingsValue(null, null, null, this as double?);
      settingType = 3;
    } else {
      throw ArgumentError(
          "Only String, Integer, Double or Boolean types are supported.");
    }
    return Setting(
        settingsValue, settingType, List.empty(), List.empty(), "", "", "", List.empty());
  }
}

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
  final List<PercentageOption> percentageOptions;

  /// Collection of targeting rules that belongs to the feature flag / setting.
  @JsonKey(name: 'r', defaultValue: [])
  final List<TargetingRule> targetingRules;

  /// Variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  /// The User Object attribute which serves as the basis of percentage options evaluation.
  @JsonKey(name: 'a')
  final String percentageAttribute;

  String salt = "";
  List<Segment> segments = List.empty();

  Setting(
      this.settingsValue,
      this.type,
      this.percentageOptions,
      this.targetingRules,
      this.variationId,
      this.percentageAttribute,
      this.salt,
      this.segments);

  factory Setting.fromJson(Map<String, dynamic> json) =>
      _$SettingFromJson(json);
  Map<String, dynamic> toJson() => _$SettingToJson(this);
}
