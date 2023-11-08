import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/entry.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';

@GenerateMocks([ConfigCatCache])
void main() {
  tearDown(() {
    ConfigCatClient.closeAll();
  });

  test('failing cache, returns memory-cached value', () async {
    // Arrange
    final cache = MockConfigCatCache();

    when(cache.write(any, any)).thenThrow(Exception());
    when(cache.read(any)).thenThrow(Exception());

    final client = ConfigCatClient.get(
        sdkKey: testSdkKey, options: ConfigCatOptions(cache: cache));
    final dioAdapter = DioAdapter(dio: client.httpClient);
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, createTestConfig({'value': 'test'}).toJson());
    });

    // Act
    final value = await client.getValue(key: 'value', defaultValue: '');

    // Assert
    expect(value, equals('test'));
  });

  test('failing fetch, returns cached value', () async {
    // Arrange
    final cache = MockConfigCatCache();
    when(cache.read(any)).thenAnswer(
        (_) => Future.value(createTestEntry({'value': 'test'}).serialize()));

    final client = ConfigCatClient.get(
        sdkKey: testSdkKey, options: ConfigCatOptions(cache: cache));
    final dioAdapter = DioAdapter(dio: client.httpClient);
    dioAdapter.onGet(getPath(), (server) {
      server.reply(500, null);
    });

    // Act
    final value = await client.getValue(key: 'value', defaultValue: '');

    // Assert
    expect(value, equals('test'));
  });

  group('cache key generation', () {
    final inputs = {
      'configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012':
          'dbd2c54f946f95ed3d76e788950f8a3a6c01e0a6',
      'configcat-sdk-1/TEST_KEY2-123456789012/1234567890123456789012':
          '71a778682cbfa4bb87862ab4733c37de35ebcbee',
    };

    inputs.forEach((sdkKey, cacheKey) {
      test('$sdkKey -> $cacheKey', () async {
        // Arrange
        final cache = MockConfigCatCache();
        when(cache.read(any)).thenAnswer((_) => Future.value(''));
        when(cache.write(any, any)).thenAnswer((_) => Future.value());

        final client = ConfigCatClient.get(
            sdkKey: sdkKey, options: ConfigCatOptions(cache: cache));
        final dioAdapter = DioAdapter(dio: client.httpClient);
        dioAdapter.onGet(getPath(sdkKey: sdkKey), (server) {
          server.reply(200, createTestConfig({'value': 'test2'}).toJson());
        });

        // Act
        await client.getValue(key: 'value', defaultValue: '');

        // Assert
        verify(cache.read(captureThat(equals(cacheKey))));
        verify(cache.write(captureThat(equals(cacheKey)), any));
      });
    });
  });

  test('cache serialization', () async {
    // Arrange
    final testJson =
        "{\"p\":{\"u\":\"https://cdn-global.configcat.com\",\"r\":0},\"f\":{\"testKey\":{\"v\":\"testValue\",\"t\":1,\"p\":[],\"r\":[]}}}";

    final time = DateTime.parse('2023-06-14T15:27:15.8440000Z');
    final eTag = 'test-etag';

    final expectedPayload = '1686756435844\ntest-etag\n$testJson';

    final entry = Entry.fromConfigJson(testJson, eTag, time);

    // Act
    final cached = entry.serialize();

    // Assert
    expect(cached, equals(expectedPayload));

    // Act
    final fromCache = Entry.fromCached(expectedPayload);

    // Assert
    expect(fromCache.configJsonString, equals(testJson));
    expect(fromCache.fetchTime, equals(time));
    expect(fromCache.eTag, equals(eTag));
  });
}
