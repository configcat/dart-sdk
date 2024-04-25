import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  const testConfigJson =
      "{\"p\":{ \"u\": \"https://cdn-global.configcat.com\", \"r\": 0 , \"s\": \"test-salt\"}, \"f\":{ \"key1\":{ \"t\":0, \"r\":[ { \"c\":[ { \"u\":{ \"a\": \"Email\", \"c\": 2 , \"l \":[ \"@configcat.com\" ] } } ], \"s\":{ \"v\": { \"b\":true }, \"i\": \"rolloutId1\" } }, { \"c\": [ { \"u\" :{ \"a\": \"Email\", \"c\": 2, \"l\" : [ \"@test.com\" ] } } ], \"s\" : { \"v\" : { \"b\": false }, \"i\": \"rolloutId2\" } } ], \"p\":[ { \"p\":50, \"v\" : { \"b\": true }, \"i\" : \"percentageId1\"  },  { \"p\" : 50, \"v\" : { \"b\": false }, \"i\": \"percentageId2\" } ], \"v\":{ \"b\":true }, \"i\": \"fakeId1\" }, \"key2\": { \"t\":0, \"v\": { \"b\": false }, \"i\": \"fakeId2\" }, \"key3\": { \"t\": 0, \"r\":[ { \"c\": [ { \"u\":{ \"a\": \"Email\", \"c\":2,  \"l\":[ \"@configcat.com\" ] } } ], \"p\": [{ \"p\":50, \"v\":{ \"b\": true  }, \"i\" : \"targetPercentageId1\" },  { \"p\": 50, \"v\": { \"b\":false }, \"i\" : \"targetPercentageId2\" } ] } ], \"v\":{ \"b\": false  }, \"i\": \"fakeId3\" } } }";

  const testIncorrectConfigJson =
      "{\"p\":{ \"u\": \"https://cdn-global.configcat.com\", \"r\": 0, \"s\": \"test-salt\" }, \"f\" :{ \"incorrect\" : { \"t\": 0, \"r\": [ {\"c\": [ {\"u\": {\"a\": \"Email\", \"c\": 2, \"l\": [\"@configcat.com\"] } } ] } ],\"v\": {\"b\": false}, \"i\": \"incorrectId\" } } }";

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

  tearDown(() {
    ConfigCatClient.closeAll();
  });

  test('get key and value', () async {
    // Arrange
    final decoded = jsonDecode(testConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue =
        await client.getKeyAndValue(variationId: 'fakeId2');

    expect(keyValue!.key, equals('key2'));
    expect(keyValue.value, equals(false));

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue2 =
        await client.getKeyAndValue(variationId: 'percentageId2');

    expect(keyValue2!.key, equals('key1'));
    expect(keyValue2.value, equals(false));

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue3 =
        await client.getKeyAndValue(variationId: 'rolloutId1');

    expect(keyValue3!.key, equals('key1'));
    expect(keyValue3.value, equals(true));

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue4 =
        await client.getKeyAndValue(variationId: 'targetPercentageId2');

    expect(keyValue4!.key, equals('key3'));
    expect(keyValue4.value, equals(false));
  });

  test('get key and value not found', () async {
    final decoded = jsonDecode(testConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue =
        await client.getKeyAndValue(variationId: 'nonexisting');

    expect(keyValue, equals(null));
  });
  test('get key and value incorrect target rule', () async {
    final decoded = jsonDecode(testIncorrectConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    await client.forceRefresh();
    final MapEntry<String, bool>? keyValue =
        await client.getKeyAndValue(variationId: 'targetPercentageId2');

    expect(keyValue, equals(null));
  });

  test('variation id test', () async {
    // Arrange
    final decoded = jsonDecode(testConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    // Act
    await client.forceRefresh();
    final details =
        await client.getValueDetails<dynamic>(key: 'key1', defaultValue: null);

    // Assert
    expect(details.variationId, equals('fakeId1'));
  });

  test('variation id test not found', () async {
    // Arrange
    final decoded = jsonDecode(testConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    // Act
    await client.forceRefresh();
    final details = await client.getValueDetails<dynamic>(
        key: 'notexsitingkey', defaultValue: null);

    // Assert
    expect(details.variationId, equals(''));
  });

  test('get all variation ids', () async {
    // Arrange
    final decoded = jsonDecode(testConfigJson);
    Config config = Config.fromJson(decoded);
    httpAdapter.enqueueResponse(getPath(), 200, config);

    // Act
    await client.forceRefresh();
    final details = await client.getAllValueDetails();

    // Assert
    expect(details.map((e) => e.variationId),
        equals(['fakeId1', 'fakeId2', 'fakeId3']));
  });

  test('get all variation ids empty', () async {
    // Arrange
    httpAdapter.enqueueResponse(getPath(), 200, "{}");

    // Act
    await client.forceRefresh();
    final details = await client.getAllValueDetails();

    // Assert
    expect(details.map((e) => e.variationId), equals([]));
  });
}
