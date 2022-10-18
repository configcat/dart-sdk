import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';

void main() {
  late ConfigCatClient client;
  late DioAdapter dioAdapter;
  late MockConfigCatCache cache;
  late RequestCounterInterceptor interceptor;
  setUp(() {
    cache = MockConfigCatCache();
    interceptor = RequestCounterInterceptor();
    when(cache.read(any)).thenAnswer((_) => Future.value(''));
    client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options:
            ConfigCatOptions(pollingMode: PollingMode.manualPoll(), cache: cache));
    client.httpClient.interceptors.add(interceptor);
    dioAdapter = DioAdapter(dio: client.httpClient);
  });
  tearDown(() {
    ConfigCatClient.closeAll();
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

  test('returns cached value on failure', () async {
    // Arrange
    final body = jsonEncode(createTestEntry({'value': 42}));
    when(cache.read(any)).thenAnswer((_) => Future.value(body));
    dioAdapter.onGet(getPath(), (server) {
      server.reply(500, null);
    });

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
    client2.close();
    final client3 = ConfigCatClient.get(sdkKey: "another");

    // Assert
    expect(client3, isNot(same(client2)));

    // Act
    ConfigCatClient.closeAll();
    final client4 = ConfigCatClient.get(sdkKey: "another");

    // Assert
    expect(client4, isNot(same(client3)));
  });

  test('online/offline', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await client.forceRefresh();

    // Assert
    expect(interceptor.allRequestCount(), equals(1));

    // Act
    client.setOffline();
    await client.forceRefresh();

    // Assert
    expect(interceptor.allRequestCount(), equals(1));
    expect(client.isOffline(), isTrue);

    // Act
    client.setOnline();
    await client.forceRefresh();

    // Assert
    expect(interceptor.allRequestCount(), equals(2));
  });

  test('init offline', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();

    final localClient = ConfigCatClient.get(
        sdkKey: "init local",
        options: ConfigCatOptions(
            pollingMode: PollingMode.manualPoll(), cache: cache, offline: true));
    localClient.httpClient.interceptors.add(interceptor);
    final localDioAdapter = DioAdapter(dio: client.httpClient);

    localDioAdapter.onGet(getPath(), (server) {
      server.reply(200, body);
    });

    // Act
    await localClient.forceRefresh();

    // Assert
    expect(interceptor.allRequestCount(), equals(0));
    expect(localClient.isOffline(), isTrue);

    // Act
    localClient.setOnline();
    await localClient.forceRefresh();

    // Assert
    expect(interceptor.allRequestCount(), equals(1));
    expect(localClient.isOffline(), isFalse);
  });

  test('eval details', () async {
    // Arrange
    dioAdapter.onGet(getPath(), (server) {
      server.reply(200, createTestConfigWithRules());
    });

    // Act
    await client.forceRefresh();
    final details = await client.getValueDetails(
        key: 'key1',
        defaultValue: '',
        user: ConfigCatUser(identifier: 'test@test2.com'));

    // Assert
    expect(details.value, equals('fake2'));
    expect(details.key, equals('key1'));
    expect(details.variationId, equals('variationId2'));
    expect(details.isDefaultValue, isFalse);
    expect(details.error, isNull);
    expect(details.matchedEvaluationPercentageRule, isNull);
    expect(details.matchedEvaluationRule?.value, equals('fake2'));
    expect(details.matchedEvaluationRule?.comparator, equals(2));
    expect(details.matchedEvaluationRule?.comparisonAttribute,
        equals('Identifier'));
    expect(
        details.matchedEvaluationRule?.comparisonValue, equals('@test2.com'));
    expect(
        details.fetchTime.isAfter(
            DateTime.now().toUtc().subtract(const Duration(seconds: 1))),
        isTrue);
  });
}

Config createTestConfigWithVariationId(Map<String, List<Object>> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) =>
          MapEntry(key, Setting(value[0], 0, [], [], value[1].toString()))));
}
