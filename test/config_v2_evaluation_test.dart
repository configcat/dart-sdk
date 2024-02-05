import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';
import 'package:test/test.dart';

import 'evaluation/evaluation_test_logger.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  final matchedEvaluationRuleAndPercentageOptionTestData = {
    [null, null, null, "Cat", false, false],
    ["12345", null, null, "Cat", false, false],
    ["12345", "a@example.com", null, "Dog", true, false],
    ["12345", "a@configcat.com", null, "Cat", false, false],
    ["12345", "a@configcat.com", "", "Frog", true, true],
    ["12345", "a@configcat.com", "US", "Fish", true, true],
    ["12345", "b@configcat.com", null, "Cat", false, false],
    ["12345", "b@configcat.com", "", "Falcon", false, true],
    ["12345", "b@configcat.com", "US", "Spider", false, true]
  };

  final prerequisiteFlagCircularDependencyTestData = {
    ["key1", "'key1' -> 'key1'"],
    ["key2", "'key2' -> 'key3' -> 'key2'"],
    ["key4", "'key4' -> 'key3' -> 'key2' -> 'key3'"]
  };

  final prerequisiteFlagTypeMismatchTestData = {
    ["stringDependsOnBool", "mainBoolFlag", true, "Dog"],
    ["stringDependsOnBool", "mainBoolFlag", false, "Cat"],
    ["stringDependsOnBool", "mainBoolFlag", "1", null],
    ["stringDependsOnBool", "mainBoolFlag", 1, null],
    ["stringDependsOnBool", "mainBoolFlag", 1.0, null],
    ["stringDependsOnString", "mainStringFlag", "private", "Dog"],
    ["stringDependsOnString", "mainStringFlag", "Private", "Cat"],
    ["stringDependsOnString", "mainStringFlag", true, null],
    ["stringDependsOnString", "mainStringFlag", 1, null],
    ["stringDependsOnString", "mainStringFlag", 1.0, null],
    ["stringDependsOnInt", "mainIntFlag", 2, "Dog"],
    ["stringDependsOnInt", "mainIntFlag", 1, "Cat"],
    ["stringDependsOnInt", "mainIntFlag", "2", null],
    ["stringDependsOnInt", "mainIntFlag", true, null],
    ["stringDependsOnInt", "mainIntFlag", 2.0, null],
    ["stringDependsOnDouble", "mainDoubleFlag", 0.1, "Dog"],
    ["stringDependsOnDouble", "mainDoubleFlag", 0.11, "Cat"],
    ["stringDependsOnDouble", "mainDoubleFlag", "0.1", null],
    ["stringDependsOnDouble", "mainDoubleFlag", true, null],
    ["stringDependsOnDouble", "mainDoubleFlag", 1, null]
  };

  final prerequisiteFlagOverrideTestData = {
    ["stringDependsOnString", "1", "john@sensitivecompany.com", null, "Dog"],
    [
      "stringDependsOnString",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.remoteOverLocal,
      "Dog"
    ],
    [
      "stringDependsOnString",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.localOverRemote,
      "Dog"
    ],
    [
      "stringDependsOnString",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.localOnly,
      ""
    ],
    ["stringDependsOnString", "2", "john@notsensitivecompany.com", null, "Cat"],
    [
      "stringDependsOnString",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.remoteOverLocal,
      "Cat"
    ],
    [
      "stringDependsOnString",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.localOverRemote,
      "Dog"
    ],
    [
      "stringDependsOnString",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.localOnly,
      ""
    ],
    [
      "stringDependsOnInt",
      "1",
      "john@sensitivecompany.com",
      null,
      "Dog"
    ],
    [
      "stringDependsOnInt",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.remoteOverLocal,
      "Dog"
    ],
    [
      "stringDependsOnInt",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.localOverRemote,
      "Falcon"
    ],
    [
      "stringDependsOnInt",
      "1",
      "john@sensitivecompany.com",
      OverrideBehaviour.localOnly,
      "Falcon"
    ],
    [
      "stringDependsOnInt",
      "2",
      "john@notsensitivecompany.com",
      null,
      "Cat"
    ],
    [
      "stringDependsOnInt",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.remoteOverLocal,
      "Cat"
    ],
    [
      "stringDependsOnInt",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.localOverRemote,
      "Falcon"
    ],
    [
      "stringDependsOnInt",
      "2",
      "john@notsensitivecompany.com",
      OverrideBehaviour.localOnly,
      "Falcon"
    ],

  };

  final comparisonAttributeConversionToCanonicalStringRepresentationTestData = {
    ["numberToStringConversion", .12345, "1"],
    ["numberToStringConversion", "0.12345", "1"],
    ["numberToStringConversionInt", 125, "4"],
    ["numberToStringConversionPositiveExp", -1.23456789e96, "2"],
    ["numberToStringConversionNegativeExp", -12345.6789E-100, "4"],
    ["numberToStringConversionNaN", double.nan, "3"],
    ["numberToStringConversionPositiveInf", double.infinity, "4"],
    ["numberToStringConversionNegativeInf", double.negativeInfinity, "3"],
    [
      "dateToStringConversion",
      DateTime.parse("2023-03-31T23:59:59.9990000Z").toUtc(),
      "3"
    ],
    [
      "dateToStringConversion",
      DateTime.parse("2023-03-31T23:59:59.9990000Z").toLocal(),
      "3"
    ],
    ["dateToStringConversion", 1680307199.999, "3"],
    ["dateToStringConversionNaN", double.nan, "3"],
    ["dateToStringConversionPositiveInf", double.infinity, "1"],
    ["dateToStringConversionNegativeInf", double.negativeInfinity, "5"],
    [
      "stringArrayToStringConversion",
      ["read", "Write", " eXecute "],
      "4"
    ],
    ["stringArrayToStringConversionEmpty", [], "5"],
    [
      "stringArrayToStringConversionSpecialChars",
      ["+<>%\"'\\/\t\r\n"],
      "3"
    ],
    [
      "stringArrayToStringConversionUnicode",
      ["äöüÄÖÜçéèñışğâ¢™✓😀"],
      "2"
    ]
  };

  tearDown(() {
    ConfigCatClient.closeAll();
  });

  for (List<dynamic> element
      in matchedEvaluationRuleAndPercentageOptionTestData) {
    test("MatchedEvaluationRuleAndPercentageOptionTest", () async {
      await _runMatchedEvaluationRuleAndPercentageOptionTest(element[0],
          element[1], element[2], element[3], element[4], element[5]);
    });
  }

  for (List<dynamic> element in prerequisiteFlagCircularDependencyTestData) {
    test("PrerequisiteFlagCircularDependencyTest", () async {
      await _prerequisiteFlagCircularDependencyTest(element[0], element[1]);
    });
  }

  for (List<dynamic> element in prerequisiteFlagTypeMismatchTestData) {
    test("PrerequisiteFlagTypeMismatchTest", () async {
      await _prerequisiteFlagTypeMismatchTest(
          element[0], element[1], element[2], element[3]);
    });
  }

  for (List<dynamic> element in prerequisiteFlagOverrideTestData) {
    test("PrerequisiteFlagOverrideTest", () async {
      await _prerequisiteFlagOverrideTest(
          element[0], element[1], element[2], element[3], element[4]);
    });
  }

  for (List<dynamic> element
      in comparisonAttributeConversionToCanonicalStringRepresentationTestData) {
    test("ComparisonAttributeConversionToCanonicalStringRepresentationTest",
        () async {
      await _comparisonAttributeConversionToCanonicalStringRepresentationTest(
          element[0], element[1], element[2]);
    });
  }
}

Future<void> _runMatchedEvaluationRuleAndPercentageOptionTest(
    String? userId,
    String? email,
    String? percentageBaseCustom,
    String expectedValue,
    bool expectedTargetingRule,
    bool expectedPercentageOption) async {
  final client = ConfigCatClient.get(
      sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw");

  ConfigCatUser? user;
  if (userId != null) {
    Map<String, Object> customAttributes = <String, Object>{};
    if (percentageBaseCustom != null) {
      customAttributes["PercentageBase"] = percentageBaseCustom;
    }

    user = ConfigCatUser(
        identifier: userId, email: email, custom: customAttributes);
  }

  final result = await client.getValueDetails(
      key: "stringMatchedTargetingRuleAndOrPercentageOption",
      defaultValue: "",
      user: user);

  expect(result.value, expectedValue);
  expect(result.matchedTargetingRule != null, expectedTargetingRule);
  expect(result.matchedPercentageOption != null, expectedPercentageOption);
}

Future<void> _prerequisiteFlagCircularDependencyTest(
    String key, String dependencyCycle) async {
  final client = ConfigCatClient.get(
      sdkKey: testSdkKey,
      options: ConfigCatOptions(
        pollingMode: PollingMode.manualPoll(),
      ));

  var jsonOverrideFile =
      await File("test/fixtures/test_circulardependency.json").readAsString();
  final decoded = jsonDecode(jsonOverrideFile);
  Config config = Config.fromJson(decoded);
  final testAdapter = HttpTestAdapter(client.httpClient);
  testAdapter.enqueueResponse(getPath(sdkKey: testSdkKey), 200, config);

  await client.forceRefresh();

  final result = await client.getValueDetails(key: key, defaultValue: "");

  expect(result.error,
      "Invalid argument(s): Circular dependency detected between the following depending flags: $dependencyCycle.");

  testAdapter.close();
}

Future<void> _prerequisiteFlagTypeMismatchTest(
    String key,
    String prerequisiteFlagKey,
    Object prerequisiteFlagValue,
    String? expectedValue) async {
  final testLogger = EvaluationTestLogger();

  Map<String, Object> map = <String, Object>{
    prerequisiteFlagKey: prerequisiteFlagValue
  };

  final client = ConfigCatClient.get(
      sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg",
      options: ConfigCatOptions(
          pollingMode: PollingMode.manualPoll(),
          logger:
              ConfigCatLogger(internalLogger: testLogger, level: LogLevel.info),
          override: FlagOverrides(
              dataSource: OverrideDataSource.map(map),
              behaviour: OverrideBehaviour.localOverRemote)));

  await client.forceRefresh();

  final result = await client.getValue<dynamic>(key: key, defaultValue: null);

  expect(result, expectedValue);

  if (expectedValue == null) {
    var logList = testLogger
        .getLogList()
        .where((element) => element.logLevel == LogLevel.error)
        .toList();
    expect(logList.length, 1);
    var message = logList[0].message;
    expect(message, startsWith("ERROR [1002]"));

    expect(message,
        matches(RegExp("^.*Type mismatch between comparison value.*")));
  }
}

Future<void> _prerequisiteFlagOverrideTest(
    String key,
    String userId,
    String email,
    OverrideBehaviour? overrideBehaviour,
    Object expectedValue) async {
  FlagOverrides? flagOverrides;
  if (overrideBehaviour != null) {
    Map<String, Object> map = <String, Object>{
      "mainStringFlag": "private",
      "stringDependsOnInt": "Falcon"
    };

    flagOverrides = FlagOverrides(
        dataSource: OverrideDataSource.map(map), behaviour: overrideBehaviour);
  }

  ConfigCatUser user = ConfigCatUser(identifier: userId, email: email);

  final client = ConfigCatClient.get(
      sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg",
      options: ConfigCatOptions(
          pollingMode: PollingMode.manualPoll(), override: flagOverrides));

  await client.forceRefresh();

  final result = await client.getValue(key: key, defaultValue: "", user: user);

  expect(result, expectedValue);
}

Future<void> _comparisonAttributeConversionToCanonicalStringRepresentationTest(
    String key, Object customAttributeValue, String expectedValue) async {
  final client = ConfigCatClient.get(
      sdkKey: testSdkKey,
      options: ConfigCatOptions(
        pollingMode: PollingMode.manualPoll(),
      ));
  var jsonOverrideFile =
      await File("test/fixtures/comparison_attribute_conversion.json")
          .readAsString();
  final decoded = jsonDecode(jsonOverrideFile);
  Config config = Config.fromJson(decoded);
  final testAdapter = HttpTestAdapter(client.httpClient);
  testAdapter.enqueueResponse(getPath(sdkKey: testSdkKey), 200, config);

  ConfigCatUser user = ConfigCatUser(
      identifier: "12345", custom: {"Custom1": customAttributeValue});

  await client.forceRefresh();

  final result =
      await client.getValue(key: key, defaultValue: "default", user: user);

  expect(result, equals(expectedValue));

  testAdapter.close();
}
