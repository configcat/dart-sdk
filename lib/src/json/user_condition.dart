import 'package:configcat_client/src/json/condition_accessor.dart';
import 'package:configcat_client/src/json/prerequisite_flag_condition.dart';
import 'package:configcat_client/src/json/segment_condition.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_condition.g.dart';

/// Describes a condition that is based on a User Object attribute.
@JsonSerializable()
class UserCondition implements ConditionAccessor {
  /// The User Object attribute that the condition is based on. Can be "Identifier", "Email", "Country" or any custom attribute.
  @JsonKey(name: 'a')
  final String comparisonAttribute;

  /// The operator which defines the relation between the comparison attribute and the comparison value.
  @JsonKey(name: 'c')
  final int comparator;

  /// The String value that the User Object attribute is compared or {@code null} if the comparator use a different type of value.
  @JsonKey(name: 's')
  final String? stringValue;

  /// The Double value that the User Object attribute is compared or {@code null} if the comparator use a different type of value.
  @JsonKey(name: 'd')
  final double? doubleValue;

  /// The String Array value that the User Object attribute is compared or {@code null} if the comparator use a different type of value.
  @JsonKey(name: 'l')
  final List<String>? stringArrayValue;

  UserCondition(this.comparisonAttribute, this.comparator, this.stringValue,
      this.doubleValue, this.stringArrayValue);

  factory UserCondition.fromJson(Map<String, dynamic> json) =>
      _$UserConditionFromJson(json);

  Map<String, dynamic> toJson() => _$UserConditionToJson(this);

  @override
  PrerequisiteFlagCondition? get prerequisiteFlagCondition {
    return null;
  }

  @override
  SegmentCondition? get segmentCondition {
    return null;
  }

  @override
  UserCondition? get userCondition {
    return this;
  }
}
