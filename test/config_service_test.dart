import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/constants.dart';
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
        errorReporter: ErrorReporter(logger, Hooks()));
    fetcher.httpClient.interceptors.add(interceptor);
    dioAdapter = DioAdapter(dio: fetcher.httpClient);
  });
  tearDown(() {
    interceptor.clear();
    dioAdapter.close();
  });

  ConfigService _createService(PollingMode pollingMode,
      {ConfigCatCache? customCache, bool offline = false}) {
    return ConfigService(
        sdkKey: testSdkKey,
        mode: pollingMode,
        hooks: Hooks(),
        fetcher: fetcher,
        logger: logger,
        cache: customCache ?? cache,
        errorReporter: ErrorReporter(logger, Hooks()),
        offline: offline);
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
      expect(settings1.settings['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.value, 'test2');
      verify(cache.write(any, any)).called(equals(2));
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('polling', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(
          PollingMode.autoPoll(autoPollInterval: const Duration(seconds: 1)));
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
                'Etag': ['tag2']
              });
        }, headers: {'If-None-Match': 'tag1'});

      // Act
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1.settings['key']?.value, 'test1');

      // Act
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.value, 'test1');

      await until(() async {
        final settings3 = await service.getSettings();
        final value = settings3.settings['key']?.value ?? '';
        return value == 'test2';
      }, const Duration(milliseconds: 2500));

      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

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

    test('ensure cached fetch time is respected on interval calc', () async {
      // Arrange
      final cached = jsonEncode(createTestEntry({'key': true}).toJson());
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = _createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 200)));
      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(200, createTestConfig({'key': true}).toJson());
      });

      // Assert
      expect(interceptor.allRequestCount(), 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });

    test('online/offline', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 200)));
      dioAdapter.onGet(getPath(), (server) {
        server.reply(200, createTestConfig({'key': 'test1'}).toJson());
      });

      // Act
      await Future.delayed(const Duration(milliseconds: 500));
      service.offline();
      var reqCount = interceptor.allRequestCount();

      // Assert
      expect(reqCount, greaterThanOrEqualTo(3));

      // Act
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(interceptor.allRequestCount(), equals(reqCount));

      // Act
      service.online();
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(interceptor.allRequestCount(), greaterThanOrEqualTo(6));

      // Cleanup
      service.close();
    });

    test('init offline', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = _createService(
          PollingMode.autoPoll(
              autoPollInterval: const Duration(milliseconds: 200)),
          offline: true);
      dioAdapter.onGet(getPath(), (server) {
        server.reply(200, createTestConfig({'key': 'test1'}).toJson());
      });

      // Act
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(interceptor.allRequestCount(), equals(0));

      // Act
      service.online();
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(interceptor.allRequestCount(), greaterThanOrEqualTo(3));

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
      expect(settings1.settings['key']?.value, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 500));
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.value, 'test1');
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
      expect(result.isEmpty, isTrue);

      // Act
      final result2 = await service.getSettings();

      // Assert
      expect(result2.isEmpty, isTrue);
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });

    test('max wait time ignored when the cache is not expired yet', () async {
      // Arrange
      final cached = jsonEncode(createTestEntry({'key': true}).toJson());
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = _createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 300),
          autoPollInterval: const Duration(milliseconds: 100)));

      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(200, createTestConfig({'key': 'test1'}).toJson(),
            delay: const Duration(seconds: 2));
      });

      // Act
      await Future.delayed(const Duration(milliseconds: 110));
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(const Duration(milliseconds: 50)));
      expect(result.isEmpty, isFalse);

      // Act
      final result2 = await service.getSettings();

      // Assert
      expect(result2.isEmpty, isFalse);
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });

    test('max wait timeout returns cached config', () async {
      // Arrange
      final cached = jsonEncode(createTestEntryWithTime({'key': true}, distantPast).toJson());
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = _createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 100)));

      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
              (server) {
            server.reply(200, createTestConfig({'key': false}).toJson(),
                delay: const Duration(seconds: 2));
          });

      // Act
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(const Duration(milliseconds: 200)));
      expect(result.settings['key']?.value , isTrue);

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
      expect(settings1.settings['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.value, 'test2');
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
      expect(settings1.settings['key']?.value, 'test1');
      final settings2 = await service.getSettings();
      expect(settings2.settings['key']?.value, 'test1');

      await until(() async {
        final settings3 = await service.getSettings();
        final value = settings3.settings['key']?.value ?? '';
        return value == 'test2';
      }, const Duration(milliseconds: 150));

      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('ensure cached fetch time is respected on TTL calc', () async {
      // Arrange
      final cache =
          CustomCache(jsonEncode(createTestEntry({'key': true}).toJson()));
      final service = _createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(200, createTestConfig({'key': true}).toJson());
      });

      // Act
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(interceptor.allRequestCount(), 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
    });

    test('ensure cached fetch time is respected on TTL with 301', () async {
      // Arrange
      final cache =
          CustomCache(jsonEncode(createTestEntry({'key': true}).toJson()));

      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(304, {});
      });

      // Act
      final service = _createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(interceptor.allRequestCount(), 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));
      await service.getSettings();

      final service2 = _createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      await service2.getSettings();
      await service2.getSettings();

      // Assert
      expect(interceptor.allRequestCount(), 1);

      // Cleanup
      service.close();
      service2.close();
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
      final result = await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(settings1.settings['key']?.value, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.value, 'test2');
      verify(cache.write(any, any)).called(2);
      expect(interceptor.allRequestCount(), 2);

      // Cleanup
      service.close();
    });

    test('failing refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = _createService(PollingMode.manualPoll());
      dioAdapter.onGet(
          sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]),
          (server) {
        server.reply(500, {});
      });

      // Act
      final result = await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(result.isSuccess, isFalse);
      expect(
          result.error,
          equals(
              "Double-check your API KEY at https://app.configcat.com/apikey. Received unexpected response: 500"));
      expect(settings1.settings, isEmpty);

      verifyNever(cache.write(any, any));
      expect(interceptor.allRequestCount(), 1);

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
