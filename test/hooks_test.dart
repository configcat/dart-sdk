import 'package:configcat_client/configcat_client.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:test/test.dart';

import 'helpers.dart';

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
              mode: PollingMode.manualPoll(),
              hooks: Hooks(
                  onConfigChanged: (map) => configChanged = true,
                  onClientReady: () => ready = true,
                  onFlagEvaluated: (ctx) => eval = true)));
      final dioAdapter = DioAdapter(dio: client.httpClient);

      final body = createTestConfig({'stringValue': 'testValue'}).toJson();
      dioAdapter.onGet(getPath(), (server) {
        server.reply(200, body);
      });

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
      dioAdapter.close();
    });

    test('subscribe', () async {
      // Arrange
      var configChanged = false;
      var eval = false;
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(mode: PollingMode.manualPoll()));
      final dioAdapter = DioAdapter(dio: client.httpClient);

      final body = createTestConfig({'stringValue': 'testValue'}).toJson();
      dioAdapter.onGet(getPath(), (server) {
        server.reply(200, body);
      });

      // Act
      client.hooks.addOnConfigChanged((p0) => configChanged = true);
      client.hooks.addOnFlagEvaluated((p0) => eval = true);

      await client.forceRefresh();
      final value = await client.getValue(key: 'stringValue', defaultValue: '');

      // Assert
      expect(configChanged, isTrue);
      expect(eval, isTrue);
      expect(value, equals('testValue'));

      // Cleanup
      client.close();
      dioAdapter.close();
    });

    test('evaluation', () async {
      // Arrange
      var eval = false;
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(mode: PollingMode.manualPoll()));
      final dioAdapter = DioAdapter(dio: client.httpClient);

      dioAdapter.onGet(getPath(), (server) {
        server.reply(200, createTestConfigWithRules());
      });

      // Act
      client.hooks.addOnFlagEvaluated((details) {
        expect(details.value, equals('fake1'));
        expect(details.key, equals('key1'));
        expect(details.variationId, equals('variationId1'));
        expect(details.isDefaultValue, isFalse);
        expect(details.error, isNull);
        expect(details.matchedEvaluationPercentageRule, isNull);
        expect(details.matchedEvaluationRule?.value, equals('fake1'));
        expect(details.matchedEvaluationRule?.comparator, equals(2));
        expect(details.matchedEvaluationRule?.comparisonAttribute,
            equals('Identifier'));
        expect(details.matchedEvaluationRule?.comparisonValue,
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
      dioAdapter.close();
    });
  });
}
