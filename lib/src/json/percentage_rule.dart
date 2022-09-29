import 'package:json_annotation/json_annotation.dart';

part 'percentage_rule.g.dart';

@JsonSerializable()
class PercentageRule {
  /// Value served when the rule is selected during evaluation.
  @JsonKey(name: 'v')
  final dynamic value;

  /// The rule's percentage value.
  @JsonKey(name: 'p')
  final double percentage;

  /// The rule's variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  PercentageRule(this.value, this.percentage, this.variationId);

  factory PercentageRule.fromJson(Map<String, dynamic> json) =>
      _$PercentageRuleFromJson(json);

  Map<String, dynamic> toJson() => _$PercentageRuleToJson(this);
}
