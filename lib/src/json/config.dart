import 'package:json_annotation/json_annotation.dart';

import 'preferences.dart';
import 'setting.dart';

part 'config.g.dart';

@JsonSerializable()
class Config {
  @JsonKey(name: 'p')
  final Preferences? preferences;

  @JsonKey(name: 'f')
  final Map<String, Setting> entries;

  @JsonKey(name: 'e', defaultValue: '')
  String eTag;

  @JsonKey(name: 't', defaultValue: -1)
  int timeStamp;

  Config(this.preferences, this.entries, this.eTag, this.timeStamp);

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigToJson(this);

  static Config empty = Config(null, {}, '', -1);
}
