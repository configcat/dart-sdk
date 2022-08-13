import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  tearDown(() {
    ConfigCatClient.close();
  });

  test('local only', () async {
    // Arrange
    final client = ConfigCatClient.get(
        sdkKey: 'localhost',
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.localOnly)));
    final dioAdapter = DioAdapter(dio: client.httpClient);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, 'localhost']);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final found = await client.getValue(key: 'enabled', defaultValue: false);
    final localOnly =
        await client.getValue(key: 'local-only', defaultValue: false);
    final notFound = await client.getValue(key: 'remote', defaultValue: null);

    // Assert
    expect(found, isTrue);
    expect(localOnly, isTrue);
    expect(notFound, isNull);
  });

  test('local over remote', () async {
    // Arrange
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.localOverRemote)));
    final dioAdapter = DioAdapter(dio: client.httpClient);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final enabled = await client.getValue(key: 'enabled', defaultValue: false);
    final localOnly =
        await client.getValue(key: 'local-only', defaultValue: false);
    final remote = await client.getValue(key: 'remote', defaultValue: '');

    // Assert
    expect(enabled, isTrue);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));
  });

  test('remote over local', () async {
    // Arrange
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.remoteOverLocal)));
    final dioAdapter = DioAdapter(dio: client.httpClient);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final enabled = await client.getValue(key: 'enabled', defaultValue: true);
    final localOnly =
        await client.getValue(key: 'local-only', defaultValue: false);
    final remote = await client.getValue(key: 'remote', defaultValue: '');

    // Assert
    expect(enabled, isFalse);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));
  });
}

Config _createTestConfig(Map<String, Object> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
}
