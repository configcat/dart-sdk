import 'package:json_annotation/json_annotation.dart';

part 'rollout_rule.g.dart';

@JsonSerializable()
class RolloutRule {
  /// Value served when the rule is selected during evaluation.
  @JsonKey(name: 'v')
  final dynamic value;

  /// The user attribute used in the comparison during evaluation.
  @JsonKey(name: 'a')
  final String comparisonAttribute;

  /// The operator used in the comparison.
  ///
  /// 0  -> 'IS ONE OF',
  /// 1  -> 'IS NOT ONE OF',
  /// 2  -> 'CONTAINS',
  /// 3  -> 'DOES NOT CONTAIN',
  /// 4  -> 'IS ONE OF (SemVer)',
  /// 5  -> 'IS NOT ONE OF (SemVer)',
  /// 6  -> '< (SemVer)',
  /// 7  -> '<= (SemVer)',
  /// 8  -> '> (SemVer)',
  /// 9  -> '>= (SemVer)',
  /// 10 -> '= (Number)',
  /// 11 -> '<> (Number)',
  /// 12 -> '< (Number)',
  /// 13 -> '<= (Number)',
  /// 14 -> '> (Number)',
  /// 15 -> '>= (Number)',
  /// 16 -> 'IS ONE OF (Sensitive)',
  /// 17 -> 'IS NOT ONE OF (Sensitive)'
  @JsonKey(name: 't')
  final int comparator;

  /// The comparison value compared to the given user attribute.
  @JsonKey(name: 'c')
  final String comparisonValue;

  /// The rule's variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  RolloutRule(this.value, this.comparisonAttribute, this.comparator,
      this.comparisonValue, this.variationId);

  factory RolloutRule.fromJson(Map<String, dynamic> json) =>
      _$RolloutRuleFromJson(json);

  Map<String, dynamic> toJson() => _$RolloutRuleToJson(this);
}
