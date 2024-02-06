import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/entry.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'http_adapter.dart';

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
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(
        getPath(), 200, createTestConfig({'value': 'test'}).toJson());

    // Act
    final String value = await client.getValue(key: 'value', defaultValue: '');

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
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(getPath(), 500, null);

    // Act
    final value = await client.getValue(key: 'value', defaultValue: '');

    // Assert
    expect(value, equals('test'));
  });

  group('cache key generation', () {
    final inputs = {
      'configcat-sdk-1/TEST_KEY-0123456789012/1234567890123456789012':
          'f83ba5d45bceb4bb704410f51b704fb6dfa19942',
      'configcat-sdk-1/TEST_KEY2-123456789012/1234567890123456789012':
          'da7bfd8662209c8ed3f9db96daed4f8d91ba5876',
    };

    inputs.forEach((sdkKey, cacheKey) {
      test('$sdkKey -> $cacheKey', () async {
        // Arrange
        final cache = MockConfigCatCache();
        when(cache.read(any)).thenAnswer((_) => Future.value(''));
        when(cache.write(any, any)).thenAnswer((_) => Future.value());

        final client = ConfigCatClient.get(
            sdkKey: sdkKey, options: ConfigCatOptions(cache: cache));
        final testAdapter = HttpTestAdapter(client.httpClient);
        testAdapter.enqueueResponse(getPath(sdkKey: sdkKey), 200,
            createTestConfig({'value': 'test2'}).toJson());

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
        "{\"p\":{\"u\":\"https://cdn-global.configcat.com\",\"r\":0,\"s\":\"test-slat\"},\"f\":{\"testKey\":{\"v\":{\"s\":\"testValue\"},\"t\":1,\"p\":[],\"r\":[], \"a\":\"\", \"i\":\"test-variation-id\"}}, \"s\":[] }";

    final time = DateTime.parse('2023-06-14T15:27:15.8440000Z');
    final eTag = 'test-etag';

    final decodedJson = jsonDecode(testJson);
    final config = Config.fromJson(decodedJson);

    final entry = Entry(testJson, config, eTag, time);

    // Act
    final cached = entry.serialize();

    final expectedPayload = '1686756435844\ntest-etag\n$testJson';
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
