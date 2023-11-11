import 'package:json_annotation/json_annotation.dart';

part 'user_condition.g.dart';

@JsonSerializable()
class UserCondition {

  @JsonKey(name: 'a')
  final String comparisonAttribute;

  @JsonKey(name: 'c')
  final int comparator;

  @JsonKey(name: 's')
  final String? stringValue;

  @JsonKey(name: 'd')
  final double? doubleValue;

  @JsonKey(name: 'l')
  final List<String>? stringArrayValue;

  UserCondition(this.comparisonAttribute, this.comparator, this.stringValue,
      this.doubleValue, this.stringArrayValue);

  factory UserCondition.fromJson(Map<String, dynamic> json) => _$UserConditionFromJson(json);

  Map<String, dynamic> toJson() => _$UserConditionToJson(this);
}