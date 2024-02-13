import 'package:json_annotation/json_annotation.dart';

import 'user_condition.dart';

part 'segment.g.dart';

/// ConfigCat segment.
@JsonSerializable()
class Segment {
  /// The name of the segment.
  @JsonKey(name: 'n')
  final String? name;

  /// The list of segment rule conditions (where there is a logical AND relation between the items).
  @JsonKey(name: 'r')
  final List<UserCondition> segmentRules;

  Segment(this.name, this.segmentRules);

  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);
  Map<String, dynamic> toJson() => _$SegmentToJson(this);
}
