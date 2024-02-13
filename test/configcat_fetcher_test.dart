import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/error_reporter.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/entry.dart';
import 'package:dio/dio.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  group('Data Governance Tests', () {
    test('should stay on given url', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 200, body.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(0));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == path)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should stay on same url', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 200, body.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(1));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == path)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should stay on same url even with force', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 2);
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 200, body.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(2));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == path)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should redirect to another', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(firstPath, 200, firstBody.toJson());
      testAdapter.enqueueResponse(secondPath, 200, secondBody.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(0));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == firstPath)
              .length,
          1);
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == secondPath)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should redirect to another when forced', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 2);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(firstPath, 200, firstBody.toJson());
      testAdapter.enqueueResponse(secondPath, 200, secondBody.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(0));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == firstPath)
              .length,
          1);
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == secondPath)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should break redirect loop', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.euOnlyBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.euOnlyBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(firstPath, 200, firstBody.toJson());
      testAdapter.enqueueResponse(secondPath, 200, secondBody.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.euOnlyBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(1));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == firstPath)
              .length,
          2);
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == secondPath)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should respect custom url', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 1);
      final firstPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      final secondBody = _createTestConfig(customUrl, 0);
      final secondPath = sprintf(urlTemplate, [customUrl, testSdkKey]);
      testAdapter.enqueueResponse(firstPath, 200, firstBody.toJson());
      testAdapter.enqueueResponse(secondPath, 200, secondBody.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl, equals(customUrl));
      expect(response.entry.config.preferences.redirect, equals(0));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == firstPath)
              .length,
          0);
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == secondPath)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('should not respect custom url when forced', () async {
      final customUrl = "https://custom";
      final fetcher =
          _createFetcher(options: ConfigCatOptions(baseUrl: customUrl));
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final firstBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 2);
      final firstPath = sprintf(urlTemplate, [customUrl, testSdkKey]);
      final secondBody = _createTestConfig(ConfigFetcher.globalBaseUrl, 0);
      final secondPath =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(firstPath, 200, firstBody.toJson());
      testAdapter.enqueueResponse(secondPath, 200, secondBody.toJson());

      // Act
      final response = await fetcher.fetchConfiguration('');

      // Assert
      expect(response.entry.config.preferences.baseUrl,
          equals(ConfigFetcher.globalBaseUrl));
      expect(response.entry.config.preferences.redirect, equals(0));
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == firstPath)
              .length,
          1);
      expect(
          testAdapter.capturedRequests
              .where((element) => element.path == secondPath)
              .length,
          1);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });
  });

  group('Fetcher Tests', () {
    test('etag works', () async {
      final etag = 'test-etag';
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final body = _createTestConfig(ConfigFetcher.globalBaseUrl, 0).toJson();
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 200, body, headers: {'Etag': etag});
      testAdapter.enqueueResponse(path, 304, null);

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
      expect(testAdapter.capturedRequests.last.headers['If-None-Match'], etag);

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('failed fetch response', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 500, null);

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('404 failed fetch response', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 404, null);

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isFalse);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('403 failed fetch response', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 403, null);

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isFalse);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('exception on fetch', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
      testAdapter.enqueueResponse(path, 500, null,
          exception: DioException(
            requestOptions: RequestOptions(
              path: path,
            ),
          ));

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      testAdapter.close();
    });

    test('timeout error', () async {
      final fetcher = _createFetcher();
      final testAdapter = HttpTestAdapter(fetcher.httpClient);

      // Arrange
      final path =
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);

      testAdapter.enqueueResponse(path, 500, null,
          exception: DioException(
              requestOptions: RequestOptions(
                path: path,
              ),
              type: DioExceptionType.connectionTimeout));

      // Act
      final fetchedResponse = await fetcher.fetchConfiguration('');

      // Assert
      expect(fetchedResponse.isFailed, isTrue);
      expect(fetchedResponse.isTransientError, isTrue);
      expect(fetchedResponse.entry.config, same(Config.empty));

      // Cleanup
      fetcher.close();
      testAdapter.close();
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
  return Config(Preferences(url, redirectMode, "test_salt"), {}, List.empty());
}
