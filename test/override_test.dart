import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('local only', () async {
    // Arrange
    final client = ConfigCatClient.get('localhost',
        options: ConfigCatOptions(
            override: FlagOverrides(
                OverrideDataSource.map({'enabled': true, 'local-only': true}),
                OverrideBehaviour.localOnly)));
    final dioAdapter = DioAdapter(dio: client.client);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, 'localhost']);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final found = await client.getValue('enabled', false);
    final localOnly = await client.getValue('local-only', false);
    final notFound = await client.getValue('remote', null);

    // Assert
    expect(found, isTrue);
    expect(localOnly, isTrue);
    expect(notFound, isNull);

    // Cleanup
    ConfigCatClient.close();
  });

  test('local over remote', () async {
    // Arrange
    final client = ConfigCatClient.get(testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                OverrideDataSource.map({'enabled': true, 'local-only': true}),
                OverrideBehaviour.localOverRemote)));
    final dioAdapter = DioAdapter(dio: client.client);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final enabled = await client.getValue('enabled', false);
    final localOnly = await client.getValue('local-only', false);
    final remote = await client.getValue('remote', '');

    // Assert
    expect(enabled, isTrue);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));

    // Cleanup
    ConfigCatClient.close();
  });

  test('remote over local', () async {
    // Arrange
    final client = ConfigCatClient.get(testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                OverrideDataSource.map({'enabled': true, 'local-only': true}),
                OverrideBehaviour.remoteOverLocal)));
    final dioAdapter = DioAdapter(dio: client.client);
    final body =
        _createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    dioAdapter.onGet(path, (server) {
      server.reply(200, body);
    });

    // Act
    final enabled = await client.getValue('enabled', true);
    final localOnly = await client.getValue('local-only', false);
    final remote = await client.getValue('remote', '');

    // Assert
    expect(enabled, isFalse);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));

    // Cleanup
    ConfigCatClient.close();
  });
}

Config _createTestConfig(Map<String, Object> map) {
  return Config(Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
}
