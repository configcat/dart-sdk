import 'package:json_annotation/json_annotation.dart';

import 'condition.dart';
import 'percentage_option.dart';
import 'served_value.dart';

part 'targeting_rule.g.dart';

/// Describes a targeting rule.
@JsonSerializable()
class TargetingRule {
  /// The list of conditions that are combined with the AND logical operator.
  /// Items can be one of the following types: {@link UserCondition}, {@link SegmentCondition} or {@link PrerequisiteFlagCondition}.
  @JsonKey(name: 'c')
  final List<Condition> conditions;

  /// The list of percentage options associated with the targeting rule or {@code null} if the targeting rule has a simple value THEN part.
  @JsonKey(name: 'p')
  final List<PercentageOption>? percentageOptions;

  /// The simple value associated with the targeting rule or {@code null} if the targeting rule has percentage options THEN part.
  @JsonKey(name: 's')
  final ServedValue? servedValue;

  TargetingRule(this.conditions, this.percentageOptions, this.servedValue);

  factory TargetingRule.fromJson(Map<String, dynamic> json) =>
      _$TargetingRuleFromJson(json);
  Map<String, dynamic> toJson() => _$TargetingRuleToJson(this);
}
