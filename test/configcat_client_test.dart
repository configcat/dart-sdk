import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ConfigCatClient client;
  late DioAdapter dioAdapter;
  setUp(() {
    client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(mode: PollingMode.manualPoll()));
    dioAdapter = DioAdapter(dio: client.httpClient);
  });
  tearDown(() {
    ConfigCatClient.close();
    dioAdapter.close();
  });

  test('get string', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'stringValue', defaultValue: '');

    // Assert
    expect(value, equals('testValue'));
  });

  test('get int', () async {
    // Arrange
    final body = createTestConfig({'intValue': 42}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'intValue', defaultValue: 0);

    // Assert
    expect(value, equals(42));
  });

  test('get double', () async {
    // Arrange
    final body = createTestConfig({'doubleValue': 3.14}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'doubleValue', defaultValue: 0.0);

    // Assert
    expect(value, equals(3.14));
  });

  test('get bool', () async {
    // Arrange
    final body = createTestConfig({'boolValue': true}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'boolValue', defaultValue: false);

    // Assert
    expect(value, isTrue);
  });

  test('get default on failure', () async {
    // Arrange
    dioAdapter.onGet(getPath(), (server) {
      server.reply(500, null);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'boolValue', defaultValue: false);

    // Assert
    expect(value, isFalse);
  });

  test('get default on bad response', () async {
    // Arrange
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, null);
    });

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'boolValue', defaultValue: false);

    // Assert
    expect(value, isFalse);
  });

  test('cache refreshes on new config json', () async {
    // Arrange
    final body1 = createTestConfig({'value': 42}).toJson();
    final body2 = createTestConfig({'value': 69}).toJson();
    dioAdapter
      ..onGet(getPath(), (server) {
        server.reply(200, body1, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Etag': [etag]
        });
      })
      ..onGet(getPath(), (server) {
        server.reply(200, body2);
      }, headers: {'If-None-Match': etag});

    // Act
    await client.forceRefresh();
    final value1 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value1, equals(42));

    // Act
    await client.forceRefresh();
    final value2 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value2, equals(69));
  });

  test('returns cached value on failed latest fetch', () async {
    // Arrange
    final body1 = createTestConfig({'value': 42}).toJson();
    dioAdapter
      ..onGet(getPath(), (server) {
        server.reply(200, body1, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Etag': [etag]
        });
      })
      ..onGet(getPath(), (server) {
        server.reply(500, null);
      }, headers: {'If-None-Match': etag});

    // Act
    await client.forceRefresh();
    final value1 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value1, equals(42));

    // Act
    await client.forceRefresh();
    final value2 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value2, equals(42));
  });

  test('returns cached value on failed latest fetch', () async {
    // Arrange
    final body1 = createTestConfig({'value': 42}).toJson();
    dioAdapter
      ..onGet(getPath(), (server) {
        server.reply(200, body1, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Etag': [etag]
        });
      })
      ..onGet(getPath(), (server) {
        server.reply(500, null);
      }, headers: {'If-None-Match': etag});

    // Act
    await client.forceRefresh();
    final value1 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value1, equals(42));

    // Act
    await client.forceRefresh();
    final value2 = await client.getValue(key: 'value', defaultValue: 0);

    // Assert
    expect(value2, equals(42));
  });

  test('get all keys', () async {
    // Arrange
    final body = createTestConfig({'value1': true, 'value2': false}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final keys = await client.getAllKeys();

    // Assert
    expect(keys, equals(['value1', 'value2']));
  });

  test('get all values', () async {
    // Arrange
    final body = createTestConfig({'value1': true, 'value2': false}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final values = await client.getAllValues();

    // Assert
    expect(values, equals({'value1': true, 'value2': false}));
  });

  test('get key and value', () async {
    // Arrange
    final body = createTestConfigWithVariationId({
      'value': [42, 'test']
    }).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final keyValue = await client.getKeyAndValue(variationId: 'test');

    // Assert
    expect(keyValue!.key, equals('value'));
    expect(keyValue.value, equals(42));
  });

  test('variation id test', () async {
    // Arrange
    final body = createTestConfigWithVariationId({
      'value': [42, 'test']
    }).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final variationId =
        await client.getVariationId(key: 'value', defaultVariationId: '');

    // Assert
    expect(variationId, equals('test'));
  });

  test('variation id test default', () async {
    // Arrange
    dioAdapter.onGet(getPath(), (server) {
      server.reply(500, null);
    });

    // Act
    await client.forceRefresh();
    final variationId =
        await client.getVariationId(key: 'value', defaultVariationId: '');

    // Assert
    expect(variationId, equals(''));
  });

  test('get all variation ids', () async {
    // Arrange
    final body = createTestConfigWithVariationId({
      'value1': [42, 'testId1'],
      'value2': [69, 'testId2']
    }).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();
    final variationIds = await client.getAllVariationIds();

    // Assert
    expect(variationIds, equals(['testId1', 'testId2']));
  });

  test('ensure singleton per sdk key', () async {
    // Act
    final client2 = ConfigCatClient.get(sdkKey: testSdkKey);

    // Assert
    expect(client2, same(client));
  });

  test('ensure close works', () async {
    // Act
    final client = ConfigCatClient.get(sdkKey: "another");
    final client2 = ConfigCatClient.get(sdkKey: "another");

    // Assert
    expect(client2, same(client));

    // Act
    ConfigCatClient.close(client: client2);
    final client3 = ConfigCatClient.get(sdkKey: "another");

    // Assert
    expect(client3, isNot(same(client2)));

    // Act
    ConfigCatClient.close();
    final client4 = ConfigCatClient.get(sdkKey: "another");

    // Assert
    expect(client4, isNot(same(client3)));
  });
}

Config createTestConfigWithVariationId(Map<String, List<Object>> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) =>
          MapEntry(key, Setting(value[0], 0, [], [], value[1].toString()))),
      "",
      0);
}
