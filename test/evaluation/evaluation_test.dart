import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/utils.dart';

import 'package:test/test.dart';

import '../http_adapter.dart';
import 'evaluation_data_set.dart';
import 'evaluation_test_logger.dart';
import '../helpers.dart';
import 'evaluation_data.dart';

void main() {
  final testData = {
    "simple_value",
    "1_targeting_rule",
    "2_targeting_rules",
    "and_rules",
    "semver_validation",
    "epoch_date_validation",
    "number_validation",
    "comparators",
    "prerequisite_flag",
    "segment",
    "options_after_targeting_rule",
    "options_based_on_user_id",
    "options_based_on_custom_attr",
    "options_within_targeting_rule",
    "list_truncation"
  };

  tearDown(() {
    ConfigCatClient.closeAll();
  });

  for (var element in testData) {
    test(element, () async {
      await _runTest(element);
    });
  }
}

Future<void> _runTest(String testCaseName) async {
  const testSetPath = "test/evaluation/data/";
  const jsonExt = ".json";

  final testSet =
      await File(testSetPath + testCaseName + jsonExt).readAsString();
  EvaluationDataSet dataSet = EvaluationDataSet.fromJson(jsonDecode(testSet));

  String sdkKey = dataSet.sdkKey;
  if (sdkKey.isEmpty) {
    sdkKey = "configcat-sdk-test-key/0000000000000000000000"; //DUMMY TEST KEY
  }
  final testLogger = EvaluationTestLogger();

  final client = ConfigCatClient.get(
      sdkKey: sdkKey,
      options: ConfigCatOptions(
        logger:
            ConfigCatLogger(internalLogger: testLogger, level: LogLevel.info),
        pollingMode: PollingMode.manualPoll(),
      ));

  var jsonOverride = dataSet.jsonOverride;

  if (jsonOverride != null && jsonOverride.isNotEmpty) {
    var jsonOverrideFile =
        await File("$testSetPath$testCaseName/$jsonOverride").readAsString();
    final decoded = jsonDecode(jsonOverrideFile);
    Config config = Config.fromJson(decoded);
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(getPath(sdkKey: sdkKey), 200, config);
  }

  await client.forceRefresh();

  List<String> errors = List<String>.empty(growable: true);

  for (EvaluationData test in dataSet.tests) {
    var configCatUser = test.user;
    var value = await client.getValue(
        key: test.key, defaultValue: test.defaultValue, user: configCatUser);

    if (test.returnValue != value) {
      errors.add(
          "Return value mismatch for test: $testCaseName Test Key: ${test.key} Expected: ${test.returnValue}, Result: $value \n");
    }

    final expectedLog =
        (await File("$testSetPath$testCaseName/${test.expectedLog}")
            .readAsString())
            .replaceAll("\r\n", "\n");

    StringBuffer logResultBuffer = StringBuffer();

    for (LogEvent log in testLogger.getLogList()) {
      logResultBuffer.write(log.message.replaceAll("\r\n", "\n"));
      logResultBuffer.write("\n");
    }

    String logResult = logResultBuffer.toString();

    if (expectedLog != logResult) {
      errors.add(
          "Log mismatch for test: $testCaseName Test Key: ${test.key} Expected:\n$expectedLog\nResult:\n$logResult\n");
    }

    testLogger.reset();
  }

  if (errors.isNotEmpty) {
    stderr.writeln("\n == ERRORS == \n");
    for (var element in errors) {
      stderr.writeln(element);
    }
    fail("Errors found: ${errors.length}");
  }
}
