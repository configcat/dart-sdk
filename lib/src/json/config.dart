import 'package:json_annotation/json_annotation.dart';

import 'preferences.dart';
import 'setting.dart';
import 'segment.dart';

part 'config.g.dart';

/// Details of a ConfigCat config.
@JsonSerializable()
class Config {
  /// The config preferences.
  @JsonKey(name: 'p')
  final Preferences preferences;

  /// The map of settings.
  @JsonKey(name: 'f')
  final Map<String, Setting> entries;

  /// The list of segments.
  @JsonKey(name: 's', defaultValue: [])
  final List<Segment> segments;

  Config(this.preferences, this.entries, this.segments);

  bool get isEmpty => identical(this, empty);

  static Config empty = Config(Preferences.empty, {}, List.empty());

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigToJson(this);
}
