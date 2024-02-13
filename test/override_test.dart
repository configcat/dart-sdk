import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  tearDown(() {
    ConfigCatClient.closeAll();
  });

  test('local only', () async {
    // Arrange
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.localOnly)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, 'localhost']);
    testAdapter.enqueueResponse(path, 200, body);

    // Act
    final found = await client.getValue(key: 'enabled', defaultValue: false);
    final localOnly =
        await client.getValue(key: 'local-only', defaultValue: false);
    final notFound =
        await client.getValue<dynamic>(key: 'remote', defaultValue: null);

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
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    testAdapter.enqueueResponse(path, 200, body);

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
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    final path =
        sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
    testAdapter.enqueueResponse(path, 200, body);

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
