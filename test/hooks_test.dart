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
      final client = ConfigCatClient.get(
          sdkKey: testSdkKey,
          options: ConfigCatOptions(
              mode: PollingMode.manualPoll(),
              hooks: Hooks(
                  onConfigChanged: (map) => configChanged = true,
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
  });
}
