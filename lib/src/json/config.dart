import 'package:json_annotation/json_annotation.dart';

import 'preferences.dart';
import 'setting.dart';

part 'config.g.dart';

@JsonSerializable()
class Config {
  @JsonKey(ignore: true)
  String jsonString = '';

  @JsonKey(name: 'p')
  final Preferences? preferences;

  @JsonKey(name: 'f')
  final Map<String, Setting> entries;

  Config(this.preferences, this.entries);

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigToJson(this);
}
