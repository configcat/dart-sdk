import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/entry.dart';
import 'package:dio/dio.dart';
import 'package:sprintf/sprintf.dart';

const urlTemplate = '%s/configuration-files/%s/$configJsonName';
const testSdkKey =
    'configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012';
const etag = 'test-etag';

Config createTestConfig(Map<String, Object> map) {
  return Config(Preferences(ConfigFetcher.globalBaseUrl, 0, "test-salt"),
      map.map((key, value) => MapEntry(key, value.toSetting())), List.empty());
}

Config createTestConfigWithRules() {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0, "test-salt"),
      {
        'key1': Setting(
            SettingsValue(null, "def", null, null), //default flag value
            1,
            [],
            [
              TargetingRule(
                  [
                    Condition(
                        UserCondition(
                            "Identifier", 2, null, null, ["@test1.com"]),
                        null,
                        null)
                  ],
                  [],
                  ServedValue(SettingsValue(null, "fake1", null, null),
                      "variationId1")),
              TargetingRule(
                  [
                    Condition(
                        UserCondition(
                            "Identifier", 2, null, null, ["@test2.com"]),
                        null,
                        null)
                  ],
                  [],
                  ServedValue(SettingsValue(null, "fake2", null, null),
                      "variationId2")),
            ],
            'defaultId', // flag def variationID
            "") //percentage attribute
      },
      List.empty());
}

Entry createTestEntry(Map<String, Object> map) {
  Config config = createTestConfig(map);
  return Entry(jsonEncode(config.toJson()), config, map[0].toString(),
      DateTime.now().toUtc());
}

Entry createTestEntryWithTime(Map<String, Object> map, DateTime time) {
  Config config = createTestConfig(map);
  return Entry(jsonEncode(config.toJson()), config, map[0].toString(), time);
}

Entry createTestEntryWithETag(Map<String, Object> map, String etag) {
  Config config = createTestConfig(map);
  return Entry(
      jsonEncode(config.toJson()), config, etag, DateTime.now().toUtc());
}

String getPath({String sdkKey = testSdkKey}) {
  return sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, sdkKey]);
}

Future<Duration> until(
    Future<bool> Function() predicate, Duration timeout) async {
  final start = DateTime.now().toUtc();
  while (!await predicate()) {
    await Future.delayed(const Duration(milliseconds: 100));
    if (DateTime.now().toUtc().isAfter(start.add(timeout))) {
      throw Exception("Test await timed out.");
    }
  }
  return DateTime.now().toUtc().difference(start);
}

class CustomCache implements ConfigCatCache {
  late String _value;

  CustomCache(String initial) {
    _value = initial;
  }

  @override
  Future<String> read(String key) {
    return Future.value(_value);
  }

  @override
  Future<void> write(String key, String value) {
    _value = value;
    return Future.value();
  }
}
