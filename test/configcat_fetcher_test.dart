import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/config_json_cache.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  group('Data Governance Tests', () {
    test('should stay on given url', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.config.preferences!.redirect, equals(1));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url even with force', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.config.preferences!.redirect, equals(2));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another when forced', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should break redirect loop', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.config.preferences!.redirect, equals(1));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should respect custom url', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl, equals(customUrl));
      expect(response.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should not respect custom url when forced', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      expect(response.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });
  });

  group('Fetcher Tests', () {
    test('etag works', () async {
      final etag = 'test-etag';
      final cache = ConfigJsonCache(
          logger: ConfigCatLogger(),
          cache: NullConfigCatCache(),
          sdkKey: testSdkKey);
      final fetcher = _createFetcher(cache: cache);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      await cache.writeCache(fetchedResponse.config);

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
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

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
          .then((value) => value.config.eTag = 'test');
      final future2 = fetcher
          .fetchConfiguration()
          .then((value) => resp1 = value.config.eTag);
      final future3 = fetcher
          .fetchConfiguration()
          .then((value) => resp2 = value.config.eTag);
      await future1;
      await future2;
      await future3;

      // Assert
      expect(resp1, equals('test'));
      expect(resp2, equals('test'));

      // Act
      final result = await fetcher.fetchConfiguration();

      // Assert
      expect(result.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(result.config.preferences!.redirect, equals(0));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('real fetch', () async {
      // Arrange
      final cache = ConfigJsonCache(
          logger: ConfigCatLogger(),
          cache: NullConfigCatCache(),
          sdkKey: testSdkKey);
      final fetcher = _createFetcher(
          cache: cache,
          sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA');

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration();
      await cache.writeCache(fetchedResponse.config);

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
    {ConfigJsonCache? cache,
    ConfigCatOptions options = const ConfigCatOptions(),
    String sdkKey = testSdkKey}) {
  final logger = ConfigCatLogger();
  return ConfigFetcher(
      logger: logger,
      sdkKey: sdkKey,
      mode: 'm',
      jsonCache: cache ??
          ConfigJsonCache(
              logger: logger, cache: NullConfigCatCache(), sdkKey: sdkKey),
      options: options);
}

Config _createTestConfig(String url, int redirectMode) {
  return Config(Preferences(url, redirectMode), {}, '', 0);
}
