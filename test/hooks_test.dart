import 'package:configcat_client/configcat_client.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  group('Hooks Tests', () {
    test('init', () async {
      // Arrange
      var configChanged = false;
      var eval = false;
      var ready = false;
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(
              pollingMode: PollingMode.manualPoll(),
              hooks: Hooks(
                  onConfigChanged: (map, _) => configChanged = true,
                  onClientReady: (_) => ready = true,
                  onFlagEvaluated: (ctx) => eval = true)));
      final testAdapter = HttpTestAdapter(client.httpClient);

      final body = createTestConfig({'stringValue': 'testValue'}).toJson();
      testAdapter.enqueueResponse(getPath(), 200, body);

      // Act
      await client.forceRefresh();
      final value = await client.getValue(key: 'stringValue', defaultValue: '');

      // Assert
      expect(configChanged, isTrue);
      expect(eval, isTrue);
      expect(ready, isTrue);
      expect(value, equals('testValue'));

      // Cleanup
      client.close();
      testAdapter.close();
    });

    test('subscribe', () async {
      // Arrange
      var configChanged = false;
      var eval = false;
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(pollingMode: PollingMode.manualPoll()));
      final testAdapter = HttpTestAdapter(client.httpClient);

      final body = createTestConfig({'stringValue': 'testValue'}).toJson();
      testAdapter.enqueueResponse(getPath(), 200, body);

      // Act
      client.hooks.addOnConfigChanged((p0, _) => configChanged = true);
      client.hooks.addOnFlagEvaluated((p0) => eval = true);

      await client.forceRefresh();
      final value = await client.getValue(key: 'stringValue', defaultValue: '');

      // Assert
      expect(configChanged, isTrue);
      expect(eval, isTrue);
      expect(value, equals('testValue'));

      // Cleanup
      client.close();
      testAdapter.close();
    });

    test('evaluation', () async {
      // Arrange
      var eval = false;
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(pollingMode: PollingMode.manualPoll()));
      final testAdapter = HttpTestAdapter(client.httpClient);

      testAdapter.enqueueResponse(getPath(), 200, createTestConfigWithRules());

      // Act
      client.hooks.addOnFlagEvaluated((details) {
        expect(details.value, equals('fake1'));
        expect(details.key, equals('key1'));
        expect(details.variationId, equals('variationId1'));
        expect(details.isDefaultValue, isFalse);
        expect(details.error, isNull);

        expect(details.matchedPercentageOption, isNull);
        expect(details.matchedTargetingRule?.conditions.length, 1);

        Condition? condition = details.matchedTargetingRule?.conditions[0];
        expect(condition?.userCondition?.comparisonAttribute,
            equals('Identifier'));
        expect(condition?.userCondition?.comparator, equals(2));
        expect(condition?.userCondition?.stringArrayValue?[0],
            equals('@test1.com'));
        expect(
            details.fetchTime.isAfter(
                DateTime.now().toUtc().subtract(const Duration(seconds: 1))),
            isTrue);
        eval = true;
      });

      await client.forceRefresh();
      final user = ConfigCatUser(identifier: 'test@test1.com');
      await client.getValue(key: 'key1', defaultValue: '', user: user);

      // Assert
      expect(eval, isTrue);

      // Cleanup
      client.close();
      testAdapter.close();
    });
  });

  group("wait for ready", () {
    test("auto poll", () async {
      final client = ConfigCatClient.get(sdkKey: testSdkKey);
      final testAdapter = HttpTestAdapter(client.httpClient);

      final body = createTestConfig({'a': true}).toJson();
      testAdapter.enqueueResponse(getPath(), 200, body);

      final state = await client.waitForReady();
      expect(state, ClientCacheState.hasUpToDateFlagData);

      final a = await client.getValue(key: "a", defaultValue: false);
      expect(a, isTrue);

      client.close();
      testAdapter.close();
    });

    test("auto poll error", () async {
      final client = ConfigCatClient.get(sdkKey: testSdkKey);
      final testAdapter = HttpTestAdapter(client.httpClient);

      final body = createTestConfig({'a': true}).toJson();
      testAdapter.enqueueResponse(getPath(), 400, body);

      final state = await client.waitForReady();
      expect(state, ClientCacheState.noFlagData);

      client.close();
      testAdapter.close();
    });

    test("lazy poll", () async {
      final cache = MockConfigCatCache();
      when(cache.read(any)).thenAnswer(
          (_) => Future.value(createTestEntry({'a': true}).serialize()));

      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(
              pollingMode: PollingMode.lazyLoad(), cache: cache));

      final state = await client.waitForReady();
      expect(state, ClientCacheState.hasUpToDateFlagData);

      final a = await client.getValue(key: "a", defaultValue: false);
      expect(a, isTrue);

      client.close();
    });

    test("lazy poll error", () async {
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(pollingMode: PollingMode.lazyLoad()));
      final testAdapter = HttpTestAdapter(client.httpClient);

      final body = createTestConfig({'a': true}).toJson();
      testAdapter.enqueueResponse(getPath(), 400, body);

      final state = await client.waitForReady();
      expect(state, ClientCacheState.noFlagData);

      client.close();
      testAdapter.close();
    });

    test("manual poll with cache", () async {
      final cache = MockConfigCatCache();
      when(cache.read(any)).thenAnswer(
          (_) => Future.value(createTestEntry({'a': true}).serialize()));

      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(
              pollingMode: PollingMode.manualPoll(), cache: cache));

      final state = await client.waitForReady();
      expect(state, ClientCacheState.hasCachedFlagDataOnly);

      final a = await client.getValue(key: "a", defaultValue: false);
      expect(a, isTrue);

      client.close();
    });

    test("manual poll without cache", () async {
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(pollingMode: PollingMode.manualPoll()));

      final state = await client.waitForReady();
      expect(state, ClientCacheState.noFlagData);

      client.close();
    });

    test("overrides", () async {
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(
              override: FlagOverrides(
                  dataSource: OverrideDataSource.map(
                      {'enabled': true, 'local-only': true}),
                  behaviour: OverrideBehaviour.localOnly)));

      final state = await client.waitForReady();
      expect(state, ClientCacheState.hasLocalOverrideFlagDataOnly);
    });
  });
}
