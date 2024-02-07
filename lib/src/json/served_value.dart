import 'package:json_annotation/json_annotation.dart';

import 'settings_value.dart';

part 'served_value.g.dart';

@JsonSerializable()
class ServedValue {
  @JsonKey(name: 'v')
  final SettingsValue settingsValue;

  @JsonKey(name: 'i')
  final String? variationId;

  ServedValue(this.settingsValue, this.variationId);

  factory ServedValue.fromJson(Map<String, dynamic> json) =>
      _$ServedValueFromJson(json);
  Map<String, dynamic> toJson() => _$ServedValueToJson(this);
}
