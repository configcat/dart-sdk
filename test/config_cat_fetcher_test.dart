import 'package:dart_sdk/src/config_cat_client.dart';
import 'package:dart_sdk/src/config_fetcher.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'fetch_configuration_test.mocks.dart';

void main() {
  test('test simple fetch', () async {
    final testBody = 'test';

    final client = MockClient();
    when(
      client.get(
        Uri.parse(
            'https://cdn-global.configcat.com/configuration-files/test/config_v5.json'),
        headers: {'X-ConfigCat-UserAgent': 'ConfigCat-Dart/m-7.2.0'},
      ),
    ).thenAnswer((_) async => http.Response(testBody, 200));

    final fetcher = ConfigFetcher(
        log: Logger('test'),
        sdkKey: 'test',
        mode: 'm',
        dataGovernance: DataGovernanceGlobal());
    final configurationJson = await fetcher.fetchConfigurationJson(client);
    expect(configurationJson.body, equals(testBody));
  });

  test('test simple fetch not modified', () async {
    final client = MockClient();
    when(
      client.get(
        Uri.parse(
            'https://cdn-global.configcat.com/configuration-files/test/config_v5.json'),
        headers: {'X-ConfigCat-UserAgent': 'ConfigCat-Dart/m-7.2.0'},
      ),
    ).thenAnswer((_) async => http.Response('', 304));

    final fetcher = ConfigFetcher(
        log: Logger('test'),
        sdkKey: 'test',
        mode: 'm',
        dataGovernance: DataGovernanceGlobal());
    final response = await fetcher.fetchConfigurationJson(client);
    expect(response.isNotModified, equals(true));
    expect(response.body.isEmpty, equals(true));
  });

  test('test simple fetch failed', () async {
    final client = MockClient();
    when(
      client.get(
        Uri.parse(
            'https://cdn-global.configcat.com/configuration-files/test/config_v5.json'),
        headers: {'X-ConfigCat-UserAgent': 'ConfigCat-Dart/m-7.2.0'},
      ),
    ).thenAnswer((_) async => http.Response('', 404));

    final fetcher = ConfigFetcher(
        log: Logger('test'),
        sdkKey: 'test',
        mode: 'm',
        dataGovernance: DataGovernanceGlobal());
    final response = await fetcher.fetchConfigurationJson(client);
    expect(response.isFailed, equals(true));
    expect(response.body.isEmpty, equals(true));
  });

  test('test fetch not modified etag', () async {
    final etag = 'test';
    final client = MockClient();

    when(
      client.get(
        Uri.parse(
            'https://cdn-global.configcat.com/configuration-files/test/config_v5.json'),
        headers: {
          'X-ConfigCat-UserAgent': 'ConfigCat-Dart/m-7.2.0',
        },
      ),
    ).thenAnswer((_) async => http.Response('', 200, headers: {'Etag': etag}));

    when(
      client.get(
        Uri.parse(
            'https://cdn-global.configcat.com/configuration-files/test/config_v5.json'),
        headers: {
          'X-ConfigCat-UserAgent': 'ConfigCat-Dart/m-7.2.0',
          'If-None-Match': etag,
        },
      ),
    ).thenAnswer((_) async => http.Response(
          '',
          304,
        ));

    final fetcher = ConfigFetcher(
        log: Logger('test'),
        sdkKey: 'test',
        mode: 'm',
        dataGovernance: DataGovernanceGlobal());
    FetchResponse response = await fetcher.fetchConfigurationJson(client);
    expect(response.isFetched, equals(true));
    response = await fetcher.fetchConfigurationJson(client);
    expect(response.isNotModified, equals(true));
    expect(fetcher.etag, etag);
  });
}
