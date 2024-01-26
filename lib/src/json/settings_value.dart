import 'package:json_annotation/json_annotation.dart';

part 'settings_value.g.dart';

/// Describes the setting type-specific value of a setting or feature flag.
@JsonSerializable()
class SettingsValue {
  @JsonKey(name: 'b')
  final bool? booleanValue;

  @JsonKey(name: 's')
  final String? stringValue;

  @JsonKey(name: 'i')
  final int? intValue;

  @JsonKey(name: 'd')
  final double? doubleValue;

  SettingsValue(
      this.booleanValue, this.stringValue, this.intValue, this.doubleValue);

  factory SettingsValue.fromJson(Map<String, dynamic> json) =>
      _$SettingsValueFromJson(json);

  Map<String, dynamic> toJson() => _$SettingsValueToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsValue &&
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
