import 'package:json_annotation/json_annotation.dart';

part 'preferences.g.dart';

@JsonSerializable()
class Preferences {
  @JsonKey(name: 'u')
  final String baseUrl;

  @JsonKey(name: 'r')
  final int redirect;

  Preferences(this.baseUrl, this.redirect);

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}
