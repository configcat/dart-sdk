import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:parameterized_test/parameterized_test.dart';
import 'package:test/test.dart';

import 'evaluation/evaluation_test_logger.dart';
import 'helpers.dart';

void main() {
  DioAdapter? dioAdapter;

  tearDown(() {
    ConfigCatClient.closeAll();
    if (dioAdapter != null) {
      dioAdapter?.close();
    }
  });

  parameterizedTest('Matched Evaluation Rule And PercentageOption Test', [
    [null, null, null, "Cat", false, false],
    ["12345", null, null, "Cat", false, false],
    ["12345", "a@example.com", null, "Dog", true, false],
    ["12345", "a@configcat.com", null, "Cat", false, false],
    ["12345", "a@configcat.com", "", "Frog", true, true],
    ["12345", "a@configcat.com", "US", "Fish", true, true],
    ["12345", "b@configcat.com", null, "Cat", false, false],
    ["12345", "b@configcat.com", "", "Falcon", false, true],
    ["12345", "b@configcat.com", "US", "Spider", false, true],
  ], p6((String? userId,
      String? email,
      String? percentageBaseCustom,
      String expectedValue,
      bool expectedTargetingRule,
      bool expectedPercentageOption) async {
    final client = ConfigCatClient.get(
        sdkKey:
            "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/P4e3fAz_1ky2-Zg2e4cbkw");

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
  }));

  parameterizedTest('Prerequisite Flag Circular Dependency Test', [
    ["key1", "'key1' -> 'key1'"],
    ["key2", "'key2' -> 'key3' -> 'key2'"],
    ["key4", "'key4' -> 'key3' -> 'key2' -> 'key3'"]
  ], p2((String key, String dependencyCycle) async {
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
          pollingMode: PollingMode.manualPoll(),
        ));

    var jsonOverrideFile =
        await File("test/fixtures/test_circulardependency.json").readAsString();
    final decoded = jsonDecode(jsonOverrideFile);
    Config config = Config.fromJson(decoded);
    var interceptor = RequestCounterInterceptor();
    client.httpClient.interceptors.add(interceptor);
    dioAdapter = DioAdapter(dio: client.httpClient);
    dioAdapter?.onGet(getPath(sdkKey: testSdkKey), (server) {
      server.reply(200, config);
    });

    await client.forceRefresh();

    final result = await client.getValueDetails(key: key, defaultValue: "");

    expect(result.error,
        "Invalid argument(s): Circular dependency detected between the following depending flags: $dependencyCycle.");
  }));

  parameterizedTest('Prerequisite Flag Type Mismatch Test', [
    ["stringDependsOnBool", "mainBoolFlag", true, "Dog"],
    ["stringDependsOnBool", "mainBoolFlag", false, "Cat"],
    ["stringDependsOnBool", "mainBoolFlag", "1", ""],
    ["stringDependsOnBool", "mainBoolFlag", 1, ""],
    ["stringDependsOnBool", "mainBoolFlag", 1.0, ""],
    ["stringDependsOnString", "mainStringFlag", "private", "Dog"],
    ["stringDependsOnString", "mainStringFlag", "Private", "Cat"],
    ["stringDependsOnString", "mainStringFlag", true, ""],
    ["stringDependsOnString", "mainStringFlag", 1, ""],
    ["stringDependsOnString", "mainStringFlag", 1.0, ""],
    ["stringDependsOnInt", "mainIntFlag", 2, "Dog"],
    ["stringDependsOnInt", "mainIntFlag", 1, "Cat"],
    ["stringDependsOnInt", "mainIntFlag", "2", ""],
    ["stringDependsOnInt", "mainIntFlag", true, ""],
    ["stringDependsOnInt", "mainIntFlag", 2.0, ""],
    ["stringDependsOnDouble", "mainDoubleFlag", 0.1, "Dog"],
    ["stringDependsOnDouble", "mainDoubleFlag", 0.11, "Cat"],
    ["stringDependsOnDouble", "mainDoubleFlag", "0.1", ""],
    ["stringDependsOnDouble", "mainDoubleFlag", true, ""],
    ["stringDependsOnDouble", "mainDoubleFlag", 1, ""],
  ], p4((String key, String prerequisiteFlagKey, Object prerequisiteFlagValue,
      String expectedValue) async {
    final testLogger = EvaluationTestLogger();

    Map<String, Object> map = <String, Object>{
      prerequisiteFlagKey: prerequisiteFlagValue
    };

    final client = ConfigCatClient.get(
        sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg",
        options: ConfigCatOptions(
            pollingMode: PollingMode.manualPoll(),
            logger: ConfigCatLogger(
                internalLogger: testLogger, level: LogLevel.info),
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(map),
                behaviour: OverrideBehaviour.localOverRemote)));

    await client.forceRefresh();

    final result = await client.getValue(key: key, defaultValue: "");

    expect(result, expectedValue);

    if (expectedValue.isEmpty) {
      var logList = testLogger
          .getLogList()
          .where((element) => element.logLevel == LogLevel.error)
          .toList();
      expect(logList.length, 1);
      var message = logList[0].message;
      expect(message, startsWith("ERROR [1002]"));

      if (prerequisiteFlagValue == null) {
        expect(message, matches(RegExp("^.*Setting value is null.*")));
      } else {
        expect(message,
            matches(RegExp("^.*Type mismatch between comparison value.*")));
      }
    }
  }));

  parameterizedTest('Prerequisite Flag Override Test', [
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
    ]
  ], p5((String key, String userId, String email,
      OverrideBehaviour? overrideBehaviour, Object expectedValue) async {
    FlagOverrides? flagOverrides;
    if (overrideBehaviour != null) {
      Map<String, Object> map = <String, Object>{"mainStringFlag": "private"};

      flagOverrides = FlagOverrides(
          dataSource: OverrideDataSource.map(map),
          behaviour: overrideBehaviour);
    }

    ConfigCatUser user = ConfigCatUser(identifier: userId, email: email);

    final client = ConfigCatClient.get(
        sdkKey: "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/JoGwdqJZQ0K2xDy7LnbyOg",
        options: ConfigCatOptions(
            pollingMode: PollingMode.manualPoll(), override: flagOverrides));

    await client.forceRefresh();

    final result =
        await client.getValue(key: key, defaultValue: "", user: user);

    expect(result, expectedValue);
  }));
}
