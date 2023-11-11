import 'package:json_annotation/json_annotation.dart';

import 'condition.dart';
import 'percentage_option.dart';
import 'served_value.dart';

part 'targeting_rule.g.dart';

@JsonSerializable()
class TargetingRule {

  @JsonKey(name: 'c')
  final List<Condition>? conditions;

  @JsonKey(name: 'p')
  final List<PercentageOption>? percentageOptions;

  @JsonKey(name: 's')
  final ServedValue servedValue;

  TargetingRule(this.conditions, this.percentageOptions, this.servedValue);

  factory TargetingRule.fromJson(Map<String, dynamic> json) => _$TargetingRuleFromJson(json);
  Map<String, dynamic> toJson() => _$TargetingRuleToJson(this);
}