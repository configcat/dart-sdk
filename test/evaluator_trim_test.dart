import 'dart:convert';
import 'dart:io';

import 'package:configcat_client/configcat_client.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'helpers.dart';
import 'http_adapter.dart';

Future<void> main() async {
  tearDown(() {
    ConfigCatClient.closeAll();
  });

  final testComparatorValueTrimsData = {
    ["isoneof", "no trim"],
    ["isnotoneof", "no trim"],
    ["containsanyof", "no trim"],
    ["notcontainsanyof", "no trim"],
    ["isoneofhashed", "no trim"],
    ["isnotoneofhashed", "no trim"],
    ["equalshashed", "no trim"],
    ["notequalshashed", "no trim"],
    ["arraycontainsanyofhashed", "no trim"],
    ["arraynotcontainsanyofhashed", "no trim"],
    ["equals", "no trim"],
    ["notequals", "no trim"],
    ["startwithanyof", "no trim"],
    ["notstartwithanyof", "no trim"],
    ["endswithanyof", "no trim"],
    ["notendswithanyof", "no trim"],
    ["arraycontainsanyof", "no trim"],
    ["arraynotcontainsanyof", "no trim"],
    ["startwithanyofhashed", "no trim"],
    ["notstartwithanyofhashed", "no trim"],
    ["endswithanyofhashed", "no trim"],
    ["notendswithanyofhashed", "no trim"],
    //semver comparator values trimmed because of backward compatibility
    ["semverisoneof", "4 trim"],
    ["semverisnotoneof", "5 trim"],
    ["semverless", "6 trim"],
    ["semverlessequals", "7 trim"],
    ["semvergreater", "8 trim"],
    ["semvergreaterequals", "9 trim"]
  };

  final testUserValueTrimsData = {
    ["isoneof", "no trim"],
    ["isnotoneof", "no trim"],
    ["isoneofhashed", "no trim"],
    ["isnotoneofhashed", "no trim"],
    ["equalshashed", "no trim"],
    ["notequalshashed", "no trim"],
    ["arraycontainsanyofhashed", "no trim"],
    ["arraynotcontainsanyofhashed", "no trim"],
    ["equals", "no trim"],
    ["notequals", "no trim"],
    ["startwithanyof", "no trim"],
    ["notstartwithanyof", "no trim"],
    ["endswithanyof", "no trim"],
    ["notendswithanyof", "no trim"],
    ["arraycontainsanyof", "no trim"],
    ["arraynotcontainsanyof", "no trim"],
    ["startwithanyofhashed", "no trim"],
    ["notstartwithanyofhashed", "no trim"],
    ["endswithanyofhashed", "no trim"],
    ["notendswithanyofhashed", "no trim"],
    //semver comparators user values trimmed because of backward compatibility
    ["semverisoneof", "4 trim"],
    ["semverisnotoneof", "5 trim"],
    ["semverless", "6 trim"],
    ["semverlessequals", "7 trim"],
    ["semvergreater", "8 trim"],
    ["semvergreaterequals", "9 trim"],
    //number and date comparators user values trimmed because of backward compatibility
    ["numberequals", "10 trim"],
    ["numbernotequals", "11 trim"],
    ["numberless", "12 trim"],
    ["numberlessequals", "13 trim"],
    ["numbergreater", "14 trim"],
    ["numbergreaterequals", "15 trim"],
    ["datebefore", "18 trim"],
    ["dateafter", "19 trim"],
    //"contains any of" and "not contains any of" is a special case, the not trimmed user attribute checked against not trimmed comparator values.
    ["containsanyof", "no trim"],
    ["notcontainsanyof", "no trim"]
  };

  ConfigCatUser trimComparatorValueUser =
      _createTestUser("12345", "[\"USA\"]", "1.0.0", "3", "1705253400");
  Config trimComparatorValueConfig =
      await _loadConfigFromJson("trim_comparator_values.json");
  for (List<dynamic> element in testComparatorValueTrimsData) {
    test("TestComparatorValueTrims", () async {
      await _trimValueTest(element[0], element[1], trimComparatorValueUser,
          trimComparatorValueConfig);
    });
  }

  ConfigCatUser trimUserValueUser = _createTestUser(
      " 12345 ", "[\" USA \"]", " 1.0.0 ", " 3 ", " 1705253400 ");
  Config trimUserValueConfig =
      await _loadConfigFromJson("trim_user_values.json");

  for (List<dynamic> element in testUserValueTrimsData) {
    test("TestUserValueTrims", () async {
      await _trimValueTest(
          element[0], element[1], trimUserValueUser, trimUserValueConfig);
    });
  }
}

Future<Config> _loadConfigFromJson(String fileName) async {
  var jsonOverrideFile = await File("test/fixtures/$fileName").readAsString();
  final decoded = jsonDecode(jsonOverrideFile);
  return Config.fromJson(decoded);
}

ConfigCatUser _createTestUser(String identifier, String country, String version,
    String number, String date) {
  Map<String, Object> customAttributes = <String, Object>{};
  customAttributes["Version"] = version;
  customAttributes["Number"] = number;
  customAttributes["Date"] = date;
  return ConfigCatUser(
      identifier: identifier, country: country, custom: customAttributes);
}

Future<void> _trimValueTest(
    String key, String expectedValue, ConfigCatUser user, Config config) async {
  String sdkKey = "configcat-sdk-test-key/0000000000000000000000";
  final client = ConfigCatClient.get(
      sdkKey: sdkKey,
      options: ConfigCatOptions(pollingMode: PollingMode.manualPoll()));

  final testAdapter = HttpTestAdapter(client.httpClient);
  testAdapter.enqueueResponse(getPath(sdkKey: sdkKey), 200, config);

  await client.forceRefresh();

  var value =
      await client.getValue(key: key, defaultValue: "default", user: user);

  // Assert
  expect(value, equals(expectedValue));

  testAdapter.close();
}
