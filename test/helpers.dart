import 'dart:convert';

import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:configcat_client/src/json/setting.dart';
import 'package:sprintf/sprintf.dart';

const urlTemplate = '%s/configuration-files/%s/$configJsonName.json';
const testSdkKey = 'test';
const etag = 'test-etag';

Config createTestConfig(Map<String, Object> map) {
  final config = Config(Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
  config.jsonString = jsonEncode(config);
  return config;
}

String getPath() {
  return sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
}
