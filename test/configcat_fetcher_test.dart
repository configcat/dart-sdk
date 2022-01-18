import 'dart:convert';

import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/configcat_options.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/config_json_cache.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:configcat_client/src/log/configcat_logger.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  group('Data Governance Tests', () {
    test('should stay on given url', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(body)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(body)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url even with force', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 2);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(body)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      dioAdapter
        ..onGet(firstPath, (server) {
          server.reply(200, firstBody.toJson());
        })
        ..onGet(secondPath, (server) {
          server.reply(200, secondBody.toJson());
        });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(secondBody)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another when forced', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 2);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      dioAdapter
        ..onGet(firstPath, (server) {
          server.reply(200, firstBody.toJson());
        })
        ..onGet(secondPath, (server) {
          server.reply(200, secondBody.toJson());
        });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(secondBody)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should break redirect loop', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      dioAdapter
        ..onGet(firstPath, (server) {
          server.reply(200, firstBody.toJson());
        })
        ..onGet(secondPath, (server) {
          server.reply(200, secondBody.toJson());
        });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(firstBody)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should respect custom url', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(customUrl, 0);
      final secondPath = sprintf(urlTemplate, [customUrl, testSdkKey]);
      dioAdapter
        ..onGet(firstPath, (server) {
          server.reply(200, firstBody.toJson());
        })
        ..onGet(secondPath, (server) {
          server.reply(200, secondBody.toJson());
        });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(secondBody)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should not respect custom url when forced', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 2);
      final firstPath = sprintf(urlTemplate, [customUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter
        ..onGet(firstPath, (server) {
          server.reply(200, firstBody.toJson());
        })
        ..onGet(secondPath, (server) {
          server.reply(200, secondBody.toJson());
        });

      // Act
      final response = await fetcher.fetchConfiguration();

      // Assert
      expect(response.config.jsonString, equals(jsonEncode(secondBody)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });
  });

  group('Fetcher Tests', () {
    test('etag works', () async {
      final etag = 'test-etag';
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0).toJson();
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter
        ..onGet(path, (server) {
          server.reply(200, body, headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': [etag]
          });
        })
        ..onGet(path, (server) {
          server.reply(304, null);
        }, headers: {'If-None-Match': etag});

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(fetchedResponse.isFetched, isTrue);
      expect(fetchedResponse.config, isNot(same(Config.empty)));

      // Act
      final notModifiedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(notModifiedResponse.isNotModified, isTrue);
      expect(notModifiedResponse.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('failed fetch response', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(500, null);
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('exception on fetch', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.throws(
          200,
          DioError(
            requestOptions: RequestOptions(
              path: path,
            ),
          ),
        );
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('return with same future on simultaneous calls', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.client);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0).toJson();
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body);
      });

      String resp1 = '';
      String resp2 = '';

      // Act
      final future1 = fetcher
          .fetchConfiguration()
          .then((value) => value.config.jsonString = 'test');
      final future2 = fetcher
          .fetchConfiguration()
          .then((value) => resp1 = value.config.jsonString);
      final future3 = fetcher
          .fetchConfiguration()
          .then((value) => resp2 = value.config.jsonString);
      await future1;
      await future2;
      await future3;

      // Assert
      expect(resp1, equals('test'));
      expect(resp2, equals('test'));

      // Act
      final result = await fetcher.fetchConfiguration();

      // Assert
      expect(result.config.jsonString, equals(jsonEncode(body)));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('real fetch', () async {
      // Arrange
      final fetcher = _createFetcher(
          sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA');

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(fetchedResponse.isFetched, isTrue);

      // Act
      final notModifiedResponse = await fetcher.fetchConfiguration();

      // Assert
      expect(notModifiedResponse.isNotModified, isTrue);

      // Cleanup
      fetcher.close();
    });
  });
}

ConfigFetcher _createFetcher(
    {ConfigCatOptions options = const ConfigCatOptions(),
    String sdkKey = testSdkKey}) {
  final logger = ConfigCatLogger();
  return ConfigFetcher(
      logger: logger,
      sdkKey: sdkKey,
      mode: 'm',
      jsonCache: ConfigJsonCache(logger),
      options: options);
}

Config _createTestConfig(String url, int redirectMode) {
  return Config(Preferences(url, redirectMode), {});
}
