import 'package:json_annotation/json_annotation.dart';

import 'percentage_option.dart';
import 'segment.dart';
import 'targeting_rule.dart';
import 'setting_value.dart';

part 'setting.g.dart';

extension SettingConvert on Object {
  /// Creates a basic [Setting] instance from an [Object].
  Setting toSetting() {
    SettingValue settingValue;
    int settingType;
    if (this is bool) {
      settingValue = SettingValue(this as bool?, null, null, null);
      settingType = 0;
    } else if (this is String) {
      settingValue = SettingValue(null, this as String?, null, null);
      settingType = 1;
    } else if (this is int) {
      settingValue = SettingValue(null, null, this as int?, null);
      settingType = 2;
    } else if (this is double) {
      settingValue = SettingValue(null, null, null, this as double?);
      settingType = 3;
    } else {
      throw ArgumentError(
          "Only String, Integer, Double or Boolean types are supported.");
    }
    return Setting(
        settingValue, settingType, List.empty(), List.empty(), "", "");
  }
}

/// Feature flag or setting.
@JsonSerializable()
class Setting {
  /// Setting value.
  /// Can be a value of the following types: {@link Boolean}, {@link String}, {@link Integer} or {@link Double}.
  @JsonKey(name: 'v')
  final SettingValue settingValue;

  /// Setting type.
  @JsonKey(name: 't')
  final int type;

  /// The list of percentage options.
  @JsonKey(name: 'p', defaultValue: [])
  final List<PercentageOption> percentageOptions;

  /// The list of targeting rules (where there is a logical OR relation between the items).
  @JsonKey(name: 'r', defaultValue: [])
  final List<TargetingRule> targetingRules;

  /// Variation ID.
  @JsonKey(name: 'i')
  final String? variationId;

  /// The User Object attribute which serves as the basis of percentage options evaluation.
  @JsonKey(name: 'a')
  final String? percentageAttribute;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? salt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  List<Segment> segments = List.empty();

  Setting(this.settingValue, this.type, this.percentageOptions,
      this.targetingRules, this.variationId, this.percentageAttribute);

  factory Setting.fromJson(Map<String, dynamic> json) =>
      _$SettingFromJson(json);
  Map<String, dynamic> toJson() => _$SettingToJson(this);
}
