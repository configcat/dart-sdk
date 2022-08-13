import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/entry.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:configcat_client/src/json/setting.dart';
import 'package:sprintf/sprintf.dart';

const urlTemplate = '%s/configuration-files/%s/$configJsonName';
const testSdkKey = 'test';
const etag = 'test-etag';

Config createTestConfig(Map<String, Object> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
}

Entry createTestEntry(Map<String, Object> map) {
  return Entry(createTestConfig(map), map[0].toString(), '', DateTime.now().toUtc());
}

String getPath() {
  return sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
}
