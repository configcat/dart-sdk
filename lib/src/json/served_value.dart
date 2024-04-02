import 'package:json_annotation/json_annotation.dart';

import 'setting_value.dart';

part 'served_value.g.dart';

@JsonSerializable()
class ServedValue {
  @JsonKey(name: 'v')
  final SettingValue settingValue;

  @JsonKey(name: 'i')
  final String? variationId;

  ServedValue(this.settingValue, this.variationId);

  factory ServedValue.fromJson(Map<String, dynamic> json) =>
      _$ServedValueFromJson(json);
  Map<String, dynamic> toJson() => _$ServedValueToJson(this);
}
