import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/error_reporter.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';

void main() {
  late RequestCounterInterceptor interceptor;
  final ConfigCatLogger logger = ConfigCatLogger();
  late MockConfigCatCache cache;
  late ConfigFetcher fetcher;
  late DioAdapter dioAdapter;
  setUp(() {
    interceptor = RequestCounterInterceptor();
    cache = MockConfigCatCache();
    fetcher = ConfigFetcher(
        logger: logger,
        sdkKey: testSdkKey,
        options: const ConfigCatOptions(),
        errorReporter: ErrorReporter(logger, null));
    fetcher.httpClient.interceptors.add(interceptor);
    dioAdapter = DioAdapter(dio: fetcher.httpClient);
  });
  tearDown(() {
    interceptor.clear();
    dioAdapter.close();
  });

  ConfigService _createService(PollingMode pollingMode) {
    return ConfigService(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(mode: pollingMode),
        fetcher: fetcher,
        logger: logger,
        cache: cache,
        errorReporter: ErrorReporter(logger, null));
  }

  group('Service Tests', () {
    test('ensure only one fetch runs at a time', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = _createService(PollingMode.manualPoll());

      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(200, createTestConfig({'key': 'test1'}).toJson());
      });

      // Act
      final future1 = service.refresh();
      final future2 = service.refresh();
      final future3 = service.refresh();
      await future1;
      await future2;
      await future3;

      // Assert
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });
  });

  group('Auto Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll());

      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test2'}).toJson());
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(equals(2));
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('polling', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 1000)));
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test2'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1['key']?.value, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 2500));
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(2));
      expect(interceptor.allRequestCount(), 3);

      // Cleanup
      service.close();
    });

    test('ensure not initiate multiple fetches', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll());
      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(500, {});
      });

      // Act
      await service.getSettings();
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });

    test('failing', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 100)));
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(500, {});
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1['key']?.value, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 500));
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2['key']?.value, 'test1');
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(1));

      // Cleanup
      service.close();
    });

    test('max wait time', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 100)));

      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
            delay: const Duration(seconds: 2));
      });

      // Act
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(const Duration(milliseconds: 150)));
      expect(result, isEmpty);

      // Act
      final result2 = await service.getSettings();

      // Assert
      expect(result2, isEmpty);
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });
  });

  group('Lazy Loading Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = _createService(PollingMode.lazyLoad(
          cacheRefreshInterval: const Duration(milliseconds: 100)));
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test2'}).toJson());
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('reload', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = _createService(PollingMode.lazyLoad(
          cacheRefreshInterval: const Duration(milliseconds: 100)));

      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test2'}).toJson());
        }, headers: {'If-None-Match': 'tag1'});

      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test1');

      await Future.delayed(Duration(milliseconds: 150));

      final settings3 = await service.getSettings();
      expect(settings3['key']?.value, 'test2');

      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });
  });

  group('Manual Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = _createService(PollingMode.manualPoll());
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'Etag': ['tag1']
              });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
            (server) {
          server.reply(200, createTestConfig({'key': 'test2'}).toJson());
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('get without refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.manualPoll());

      // Act
      await service.getSettings();

      // Assert
      verifyNever(cache.write(any, any));
      expect(interceptor.allRequestCount(), 0);

      // Cleanup
      service.close();
    });
  });
}
