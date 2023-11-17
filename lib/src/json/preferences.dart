import 'package:json_annotation/json_annotation.dart';

part 'preferences.g.dart';

@JsonSerializable()
class Preferences {
  @JsonKey(name: 'u')
  final String baseUrl;

  @JsonKey(name: 'r', defaultValue: 0)
  final int redirect;

  @JsonKey(name: 's')
  final String salt;

  Preferences(this.baseUrl, this.redirect, this.salt);

  static Preferences empty = Preferences("", 0, "");

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}
