import 'package:json_annotation/json_annotation.dart';

import 'preferences.dart';
import 'setting.dart';
import 'segment.dart';

part 'config.g.dart';

@JsonSerializable()
class Config {
  @JsonKey(name: 'p')
  final Preferences preferences;

  @JsonKey(name: 'f')
  final Map<String, Setting> entries;

  @JsonKey(name: 's', defaultValue: [])
  final List<Segment> segments;

  Config(this.preferences, this.entries, this.segments);

  bool get isEmpty => identical(this, empty);

  static Config empty = Config(Preferences.empty, {}, List.empty());

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigToJson(this);
}
