import 'package:json_annotation/json_annotation.dart';

part 'percentage_rule.g.dart';

@JsonSerializable()
class RolloutPercentageItem {
  @JsonKey(name: 'v')
  final dynamic value;

  @JsonKey(name: 'p')
  final double percentage;

  @JsonKey(name: 'i', defaultValue: '')
  final String variationId;

  RolloutPercentageItem(this.value, this.percentage, this.variationId);

  factory RolloutPercentageItem.fromJson(Map<String, dynamic> json) =>
      _$RolloutPercentageItemFromJson(json);

  Map<String, dynamic> toJson() => _$RolloutPercentageItemToJson(this);
}
