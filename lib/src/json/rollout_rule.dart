import 'package:json_annotation/json_annotation.dart';

part 'rollout_rule.g.dart';

@JsonSerializable()
class RolloutRule {
  @JsonKey(name: 'v')
  final dynamic value;

  @JsonKey(name: 'a')
  final String comparisonAttribute;

  @JsonKey(name: 't')
  final int comparator;

  @JsonKey(name: 'c')
  final String comparisonValue;

  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  RolloutRule(this.value, this.comparisonAttribute, this.comparator,
      this.comparisonValue, this.variationId);

  factory RolloutRule.fromJson(Map<String, dynamic> json) =>
      _$RolloutRuleFromJson(json);

  Map<String, dynamic> toJson() => _$RolloutRuleToJson(this);
}
