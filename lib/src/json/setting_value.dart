import 'package:configcat_client/src/json/setting_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'setting_value.g.dart';

/// Describes the setting type-specific value of a setting or feature flag.
@JsonSerializable()
class SettingValue {
  @JsonKey(name: 'b')
  final bool? booleanValue;

  @JsonKey(name: 's')
  final String? stringValue;

  @JsonKey(name: 'i')
  final int? intValue;

  @JsonKey(name: 'd')
  final double? doubleValue;

  SettingValue(
      this.booleanValue, this.stringValue, this.intValue, this.doubleValue);

  factory SettingValue.fromJson(Map<String, dynamic> json) =>
      _$SettingValueFromJson(json);

  Map<String, dynamic> toJson() => _$SettingValueToJson(this);

  bool equalsBasedOnSettingType(Object? other, SettingType settingType) {
    if( identical(this, other) ) {
      return true;
    }
    if(other is SettingValue &&
        runtimeType == other.runtimeType) {
        if (settingType == SettingType.boolean) {
          return booleanValue == other.booleanValue;
        }
        if (settingType == SettingType.string) {
          return stringValue == other.stringValue;
        }
        if (settingType == SettingType.int) {
          return intValue == other.intValue;
        }
        if (settingType == SettingType.double) {
          return doubleValue == other.doubleValue;
        }
        throw ArgumentError("Setting is of an unsupported type (${settingType.name}).");
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingValue &&
          runtimeType == other.runtimeType &&
          booleanValue == other.booleanValue &&
          stringValue == other.stringValue &&
          intValue == other.intValue &&
          doubleValue == other.doubleValue;

  @override
  int get hashCode =>
      booleanValue.hashCode ^
      stringValue.hashCode ^
      intValue.hashCode ^
      doubleValue.hashCode;

  @override
  String toString() {
    if (booleanValue != null) {
      return booleanValue.toString();
    } else if (intValue != null) {
      return intValue.toString();
    } else if (doubleValue != null) {
      return doubleValue.toString();
    } else {
      return stringValue ?? '';
    }
  }
}
