import 'package:json_annotation/json_annotation.dart';

part 'percentage_rule.g.dart';

@JsonSerializable()
class RolloutPercentageItem {
  /// Value served when the rule is selected during evaluation.
  @JsonKey(name: 'v')
  final dynamic value;

  /// The rule's percentage value.
  @JsonKey(name: 'p')
  final double percentage;

  /// The rule's variation ID (for analytical purposes).
  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  RolloutPercentageItem(this.value, this.percentage, this.variationId);

  factory RolloutPercentageItem.fromJson(Map<String, dynamic> json) =>
      _$RolloutPercentageItemFromJson(json);

  Map<String, dynamic> toJson() => _$RolloutPercentageItemToJson(this);
}
