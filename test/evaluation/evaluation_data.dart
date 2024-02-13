import 'package:configcat_client/src/configcat_user.dart';

class EvaluationData {
  final String key;

  final dynamic defaultValue;

  final dynamic returnValue;

  final String expectedLog;

  final ConfigCatUser? user;

  EvaluationData(this.key, this.defaultValue, this.returnValue,
      this.expectedLog, this.user);

  static EvaluationData fromJson(Map<String, dynamic> json) => EvaluationData(
      json['key'] as String,
      json['defaultValue'] as dynamic,
      json['returnValue'] as dynamic,
      json['expectedLog'] as String,
      json['user'] == null
          ? null
          : userFromJson(json['user'] as Map<String, dynamic>));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'defaultValue': defaultValue,
        'returnValue': returnValue,
        'expectedLog': expectedLog,
        'user': user
      };

  static ConfigCatUser userFromJson(Map<String, dynamic> json) => ConfigCatUser(
      identifier: json['Identifier'] as String,
      email: json['Email'] as String?,
      country: json['Country'] as String?,
      custom: customsFromJson(json));

  static Map<String, Object>? customsFromJson(Map<String, dynamic> json) {
    Map<String, Object>? customs = <String, Object>{};
    json.forEach((key, value) {
      if (key != 'Identifier' || key != 'Email' || key != 'Country') {
        customs[key] = value;
      }
    });
    return customs;
  }
}
