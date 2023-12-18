import '../evaluation/evaluation_data.dart';

class EvaluationDataSet {
  final String sdkKey;
  final String? jsonOverride;
  final List<EvaluationData> tests;

  EvaluationDataSet(this.sdkKey, this.jsonOverride, this.tests);

  static EvaluationDataSet fromJson(
          Map<String, dynamic> json) =>
      EvaluationDataSet(
          json['sdkKey'] as String,
          json['jsonOverride'] as String?,
          (json['tests'] as List<dynamic>)
              .map((e) => EvaluationData.fromJson(e as Map<String, dynamic>))
              .toList());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sdkKey': sdkKey,
        'jsonOverride': jsonOverride,
        'tests': tests
      };
}
