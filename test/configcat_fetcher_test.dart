import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/error_reporter.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/json/entry.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  late RequestCounterInterceptor interceptor;
  setUp(() {
    interceptor = RequestCounterInterceptor();
  });
  tearDown(() {
    interceptor.clear();
  });

  group('Data Governance Tests', () {
    test('should stay on given url', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(0));
      expect(interceptor.requestCountForPath(path), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(1));
      expect(interceptor.requestCountForPath(path), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should stay on same url even with force', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 2);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(200, body.toJson());
      });

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(2));
      expect(interceptor.requestCountForPath(path), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
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
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(0));
      expect(interceptor.requestCountForPath(firstPath), 1);
      expect(interceptor.requestCountForPath(secondPath), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should redirect to another when forced', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
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
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(0));
      expect(interceptor.requestCountForPath(firstPath), 1);
      expect(interceptor.requestCountForPath(secondPath), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should break redirect loop', () async {
      final fetcher = _createFetcher();
      fetcher.httpClient.interceptors.add(interceptor);
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
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(1));
      expect(interceptor.requestCountForPath(firstPath), 2);
      expect(interceptor.requestCountForPath(secondPath), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should respect custom url', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      fetcher.httpClient.interceptors.add(interceptor);
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
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl, equals(customUrl));
      expect(response.entry.config.preferences!.redirect, equals(0));
      expect(interceptor.requestCountForPath(firstPath), null);
      expect(interceptor.requestCountForPath(secondPath), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('should not respect custom url when forced', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      fetcher.httpClient.interceptors.add(interceptor);
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
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences!.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences!.redirect, equals(0));
      expect(interceptor.requestCountForPath(firstPath), 1);
      expect(interceptor.requestCountForPath(secondPath), 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });
  });

  group('Fetcher Tests', () {
    test('etag works', () async {
      final etag = 'test-etag';
      final fetcher = _createFetcher();
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
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFetched, isTrue);
      expect(fetchedResponse.entry.config, isNot(same(Config.empty)));
      expect(fetchedResponse.entry.eTag, equals(etag));

      // Act
      final notModifiedResponse = await fetcher.fetchConfiguration(etag);

      // Assert
      expect(notModifiedResponse.isNotModified, isTrue);
      expect(notModifiedResponse.entry.config, same(Config.empty));

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
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('404 failed fetch response', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(404, null);
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isFalse);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('403 failed fetch response', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.reply(403, null);
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isFalse);
      expect(fetchedResponse.entry.config, same(Config.empty));

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
          500,
          DioError(
            requestOptions: RequestOptions(
              path: path,
            ),
          ),
        );
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('timeout error', () async {
      final fetcher = _createFetcher();
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);

      // Arrange
      final path =
      sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      dioAdapter.onGet(path, (server) {
        server.throws(
          500,
          DioError(
            requestOptions: RequestOptions(
              path: path,
            ),
            type: DioErrorType.connectionTimeout
          ),
        );
      });

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      dioAdapter.close();
    });

    test('entity tests', () async {
      // Assert
      expect(Entry.empty.isEmpty, isTrue);
      expect(Config.empty.isEmpty, isTrue);
    });

    test('real fetch', () async {
      // Arrange
      final fetcher = _createFetcher(
          sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA');

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFetched, isTrue);

      // Act
      final notModifiedResponse =
          await fetcher.fetchConfiguration(fetchedResponse.entry.eTag);

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
      options: options,
      errorReporter: ErrorReporter(logger, Hooks()));
}

Config _createTestConfig(String url, int redirectMode) {
  return Config(Preferences(url, redirectMode), {});
}
