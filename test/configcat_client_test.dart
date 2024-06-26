import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/pair.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  late ConfigCatClient client;
  late HttpTestAdapter httpAdapter;
  late MockConfigCatCache cache;

  setUp(() {
    cache = MockConfigCatCache();
    when(cache.read(any)).thenAnswer((_) => Future.value(''));
    client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            pollingMode: PollingMode.manualPoll(), cache: cache));
    httpAdapter = HttpTestAdapter(client.httpClient);
  });
  tearDown(() {
    ConfigCatClient.closeAll();
    httpAdapter.close();
  });

  test('sdk key is not empty', () async {
    expect(
        () => ConfigCatClient.get(sdkKey: ""),
        throwsA(predicate((e) =>
            e is ArgumentError && e.message == 'SDK Key cannot be empty.')));
  });

  test('sdk key validation', () async {
    //TEST VALID KEYS
    client = ConfigCatClient.get(
        sdkKey: "sdk-key-90123456789012/1234567890123456789012");
    expect(client, isNotNull);
    client = ConfigCatClient.get(
        sdkKey:
            "configcat-sdk-1/sdk-key-90123456789012/1234567890123456789012");
    expect(client, isNotNull);
    client = ConfigCatClient.get(
        sdkKey: "configcat-proxy/sdk-key-90123456789012",
        options: ConfigCatOptions(baseUrl: "https://my-configcat-proxy"));
    expect(client, isNotNull);
    ConfigCatClient.closeAll();

    // //TEST INVALID KEYS
    var wrongSDKKeys = {
      "sdk-key-90123456789012",
      "sdk-key-9012345678901/1234567890123456789012",
      "sdk-key-90123456789012/123456789012345678901",
      "sdk-key-90123456789012/12345678901234567890123",
      "sdk-key-901234567890123/1234567890123456789012",
      "configcat-sdk-1/sdk-key-90123456789012",
      "configcat-sdk-1/sdk-key-9012345678901/1234567890123456789012",
      "configcat-sdk-1/sdk-key-90123456789012/123456789012345678901",
      "configcat-sdk-1/sdk-key-90123456789012/12345678901234567890123",
      "configcat-sdk-1/sdk-key-901234567890123/1234567890123456789012",
      "configcat-sdk-2/sdk-key-90123456789012/1234567890123456789012",
      "configcat-proxy/",
      "configcat-proxy/sdk-key-90123456789012"
    };

    for (String sdkKey in wrongSDKKeys) {
      expect(
          () => ConfigCatClient.get(sdkKey: sdkKey),
          throwsA(predicate((e) =>
              e is ArgumentError &&
              e.message == "SDK Key '$sdkKey' is invalid.")));
    }

    expect(
        () => ConfigCatClient.get(
            sdkKey: "configcat-proxy/",
            options: ConfigCatOptions(baseUrl: "https://my-configcat-proxy")),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.message == "SDK Key 'configcat-proxy/' is invalid.")));

    //TEST OverrideBehaviour.localOnly skip sdkKey validation
    client = ConfigCatClient.get(
        sdkKey: "sdk-key-90123456789012",
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map({}),
                behaviour: OverrideBehaviour.localOnly)));
    expect(client, isNotNull);

    ConfigCatClient.closeAll();
  });

  test('get string', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'stringValue', defaultValue: '');

    // Assert
    expect(value, equals('testValue'));
  });

  test('get int', () async {
    // Arrange
    final body = createTestConfig({'intValue': 42}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'intValue', defaultValue: 0);

    // Assert
    expect(value, equals(42));
  });

  test('get double', () async {
    // Arrange
    final body = createTestConfig({'doubleValue': 3.14}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'doubleValue', defaultValue: 0.0);

    // Assert
    expect(value, equals(3.14));
  });

  test('get bool', () async {
    // Arrange
    final body = createTestConfig({'boolValue': true}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'boolValue', defaultValue: false);

    // Assert
    expect(value, isTrue);
  });

  test('get default on failure', () async {
    // Arrange
    httpAdapter.enqueueResponse(getPath(), 500, null);

    // Act
    await client.forceRefresh();
    final value = await client.getValue(key: 'boolValue', defaultValue: false);

    // Assert
    expect(value, isFalse);
  });

  test('get default on bad response', () async {
    // Arrange
    httpAdapter.enqueueResponse(getPath(), 200, null);

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

    httpAdapter.enqueueResponse(getPath(), 200, body1, headers: {'Etag': etag});
    httpAdapter.enqueueResponse(getPath(), 200, body2);

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
    expect(httpAdapter.capturedRequests.last.headers['If-None-Match'], etag);
  });

  test('returns cached value on failed latest fetch', () async {
    // Arrange
    final body1 = createTestConfig({'value': 42}).toJson();

    httpAdapter.enqueueResponse(getPath(), 200, body1, headers: {'Etag': etag});
    httpAdapter.enqueueResponse(getPath(), 500, null);

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
    expect(httpAdapter.capturedRequests.last.headers['If-None-Match'], etag);
  });

  test('returns cached value on failed latest fetch', () async {
    // Arrange
    final body1 = createTestConfig({'value': 42}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body1, headers: {'Etag': etag});
    httpAdapter.enqueueResponse(getPath(), 500, null);

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
    expect(httpAdapter.capturedRequests.last.headers['If-None-Match'], etag);
  });

  test('returns cached value on failure', () async {
    // Arrange
    final body = createTestEntry({'value': 42}).serialize();
    when(cache.read(any)).thenAnswer((_) => Future.value(body));

    httpAdapter.enqueueResponse(getPath(), 500, null);

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
    final body = createTestConfig({'value1': true, 'value2': false});
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final keys = await client.getAllKeys();

    // Assert
    expect(keys, equals(['value1', 'value2']));
  });

  test('get all values', () async {
    // Arrange
    final body = createTestConfig({'value1': true, 'value2': false}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final values = await client.getAllValues();

    // Assert
    expect(values, equals({'value1': true, 'value2': false}));
  });

  test('get all value details', () async {
    // Arrange
    final body = createTestConfig({'value1': true, 'value2': false}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();
    final details = await client.getAllValueDetails();

    // Assert
    expect(details.length, equals(2));
    expect(details.first.value, isTrue);
    expect(details[1].value, isFalse);
  });

  test('ensure singleton per sdk key', () async {
    // Act
    final client2 = ConfigCatClient.get(sdkKey: testSdkKey);

    // Assert
    expect(client2, same(client));
  });

  test('ensure close works', () async {
    // Act
    final client = ConfigCatClient.get(
        sdkKey:
            'configcat-sdk-1/TEST_KEY-03-0123456789/1234567890123456789012');
    final client2 = ConfigCatClient.get(
        sdkKey:
            'configcat-sdk-1/TEST_KEY-03-0123456789/1234567890123456789012');

    // Assert
    expect(client2, same(client));

    // Act
    client2.close();
    final client3 = ConfigCatClient.get(
        sdkKey:
            'configcat-sdk-1/TEST_KEY-03-0123456789/1234567890123456789012');

    // Assert
    expect(client3, isNot(same(client2)));

    // Act
    ConfigCatClient.closeAll();
    final client4 = ConfigCatClient.get(
        sdkKey:
            'configcat-sdk-1/TEST_KEY-03-0123456789/1234567890123456789012');

    // Assert
    expect(client4, isNot(same(client3)));
  });

  test('ensure close removes the closing instance only', () async {
    // Act
    final client1 = ConfigCatClient.get(sdkKey: testSdkKey);

    client1.close();

    // Act
    final client2 = ConfigCatClient.get(sdkKey: testSdkKey);

    // Assert
    expect(client1, isNot(same(client2)));

    // Act
    client1.close();
    final client3 = ConfigCatClient.get(sdkKey: testSdkKey);

    // Assert
    expect(client2, same(client3));
  });

  test('online/offline', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();

    // Assert
    expect(httpAdapter.capturedRequests.length, equals(1));

    // Act
    client.setOffline();
    await client.forceRefresh();

    // Assert
    expect(httpAdapter.capturedRequests.length, equals(1));
    expect(client.isOffline(), isTrue);

    // Act
    client.setOnline();
    await client.forceRefresh();

    // Assert
    expect(httpAdapter.capturedRequests.length, equals(2));
  });

  test('init offline', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();

    final localClient = ConfigCatClient.get(
        sdkKey: 'configcat-sdk-1/TEST_KEY-01-0123456789/1234567890123456789012',
        options: ConfigCatOptions(
            pollingMode: PollingMode.manualPoll(),
            cache: cache,
            offline: true));
    final localAdapter = HttpTestAdapter(localClient.httpClient);

    localAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await localClient.forceRefresh();

    // Assert
    expect(localAdapter.capturedRequests.length, equals(0));
    expect(localClient.isOffline(), isTrue);

    // Act
    localClient.setOnline();
    await localClient.forceRefresh();

    // Assert
    expect(localAdapter.capturedRequests.length, equals(1));
    expect(localClient.isOffline(), isFalse);
  });

  test('init offline on ready hook called', () async {
    // Arrange
    final body = createTestConfig({'stringValue': 'testValue'}).toJson();

    var ready = false;
    final localClient = ConfigCatClient.get(
        sdkKey: 'configcat-sdk-1/TEST_KEY-02-0123456789/1234567890123456789012',
        options: ConfigCatOptions(
            pollingMode: PollingMode.autoPoll(),
            cache: cache,
            hooks: Hooks(onClientReady: () => ready = true),
            offline: true));
    final localAdapter = HttpTestAdapter(localClient.httpClient);

    localAdapter.enqueueResponse(getPath(), 200, body);

    // Assert
    expect(localAdapter.capturedRequests.length, equals(0));
    expect(ready, isTrue);
  });

  test('eval details', () async {
    // Arrange
    httpAdapter.enqueueResponse(getPath(), 200, createTestConfigWithRules());

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
    expect(details.matchedPercentageOption, isNull);
    expect(details.matchedTargetingRule?.conditions.length, 1);

    Condition? condition = details.matchedTargetingRule?.conditions[0];
    expect(condition?.userCondition?.comparisonAttribute, equals('Identifier'));
    expect(condition?.userCondition?.comparator, equals(2));
    expect(
        condition?.userCondition?.stringArrayValue?[0], equals('@test2.com'));
    expect(
        details.fetchTime.isAfter(
            DateTime.now().toUtc().subtract(const Duration(seconds: 1))),
        isTrue);
  });

  test('test Special Characters Works', () async {
    //Setup client
    client = ConfigCatClient.get(
        sdkKey:
            "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/u28_1qNyZ0Wz-ldYHIU7-g");
    // Act
    await client.forceRefresh();

    ConfigCatUser user = ConfigCatUser(identifier: "äöüÄÖÜçéèñışğâ¢™✓😀");

    var resultSpecialCharacters = await client.getValue(
        key: "specialCharacters", defaultValue: "NOT_CAT", user: user);
    // Assert
    expect("äöüÄÖÜçéèñışğâ¢™✓😀", equals(resultSpecialCharacters));

    var resultSpecialCharactersHashed = await client.getValue(
        key: "specialCharactersHashed", defaultValue: "NOT_CAT", user: user);
    // Assert
    expect("äöüÄÖÜçéèñışğâ¢™✓😀", equals(resultSpecialCharactersHashed));
  });

  test("getValueValidTypes", () async {
    final body = createTestConfig({
      'fakeKeyString': "fakeValueString",
      'fakeKeyInt': 1,
      'fakeKeyDouble': 2.1,
      'fakeKeyBoolean': true
    });
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();

    //String
    final valueString =
        await client.getValue(key: "fakeKeyString", defaultValue: "default");
    expect(valueString, equals("fakeValueString"));

    //int
    final valueInt = await client.getValue(key: "fakeKeyInt", defaultValue: 0);
    expect(valueInt, equals(1));

    //double
    final valueDouble =
        await client.getValue(key: "fakeKeyDouble", defaultValue: 1.1);
    expect(valueDouble, equals(2.1));

    //bool
    final valueBool =
        await client.getValue(key: "fakeKeyBoolean", defaultValue: false);
    expect(valueBool, equals(true));

    //dynamic
    final valueDynamic = await client.getValue<dynamic>(
        key: "fakeKeyString", defaultValue: "default");
    expect(valueDynamic.toString(), equals("fakeValueString"));

    // dynamic with different default value
    final valueDynamicWithList = await client.getValue<dynamic>(
        key: "fakeKeyString", defaultValue: {"list1", "list2"});
    expect(valueDynamicWithList.toString(), equals("fakeValueString"));
  });

  test("getValueInvalidTypes", () async {
    final body = createTestConfig({
      'fakeKeyString': "fakeValueString",
      'fakeKeyInt': 1,
      'fakeKeyDouble': 2.1,
      'fakeKeyBoolean': true
    });
    httpAdapter.enqueueResponse(getPath(), 200, body);

    // Act
    await client.forceRefresh();

    //List
    expect(
        () => client
            .getValue(key: "fakeKeyString", defaultValue: {"list1", "list2"}),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.message ==
                'Only the following types are supported: String, bool, int, double, Object (both nullable and non-nullable) and dynamic.')));

    //ConfigCatUser
    expect(
        () => client.getValue(
            key: "fakeKeyString",
            defaultValue: ConfigCatUser(identifier: "test")),
        throwsA(predicate((e) =>
            e is ArgumentError &&
            e.message ==
                'Only the following types are supported: String, bool, int, double, Object (both nullable and non-nullable) and dynamic.')));
  });
}

Config createTestConfigWithVariationId(Map<String, Pair<int, String>> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0, "test-salt"),
      map.map((key, value) => MapEntry(
          key,
          Setting(SettingValue(null, null, value.first, null), 2, [], [],
              value.second, ""))),
      List.empty());
}
