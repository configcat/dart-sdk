import 'package:configcat_client/configcat_client.dart';
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
  setUp(() {
    interceptor = RequestCounterInterceptor();
    cache = MockConfigCatCache();
  });
  tearDown(() {
    interceptor.clear();
  });

  group('Auto Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.autoPoll(),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test2' }).toJson());
        }, headers: { 'If-None-Match': 'tag1' });

      // Act
      await service.refresh();

      // Assert
      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');

      // Act
      await service.refresh();

      // Assert
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test2');

      verify(cache.write(any, any)).called(equals(2));

      expect(interceptor.requests.length, 2);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });

    test('polling', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      var onChanged = false;
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.autoPoll(
              autoPollInterval: const Duration(milliseconds: 5000),
              onConfigChanged: () => onChanged = true),
          fetcher: fetcher,
          logger: logger,
          cache: cache);
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test2' }).toJson());
        }, headers: {
          'If-None-Match': 'tag1'
        });

      // Assert
      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 10000));

      // Assert
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(2));
      expect(onChanged, isTrue);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });

    test('failing', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      var onChanged = false;
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.autoPoll(
              autoPollInterval: Duration(milliseconds: 100),
              onConfigChanged: () => onChanged = true),
          fetcher: fetcher,
          logger: logger,
          cache: cache);
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(500, {});
        }, headers: { 'If-None-Match': 'tag1' });

      // Assert
      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test1');
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(1));
      expect(onChanged, isTrue);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });

    test('max wait time', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.autoPoll(maxInitWaitTime: const Duration(milliseconds: 100)),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      dioAdapter
        .onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), delay: const Duration(seconds: 2));
        });

      // Act
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(const Duration(milliseconds: 150)));
      expect(result, isEmpty);

      final result2 = await service.getSettings();
      expect(result2, isEmpty);
      expect(interceptor.requests.length, 1);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });
  });

  group('Lazy Loading Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.lazyLoad(cacheRefreshInterval: const Duration(milliseconds: 100)),
          fetcher: fetcher,
          logger: logger,
          cache: cache);
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test2' }).toJson());
        }, headers: { 'If-None-Match': 'tag1' });

      // Act
      await service.refresh();

      // Assert
      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');

      // Act
      await service.refresh();

      // Assert
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test2');
      verify(cache.write(any, any)).called(2);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });

    test('reload', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.lazyLoad(
                  cacheRefreshInterval: const Duration(milliseconds: 100)),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test2' }).toJson());
        }, headers: { 'If-None-Match': 'tag1' });

      final settings1 = await service.getSettings();
      expect(settings1['key']?.value, 'test1');
      final settings2 = await service.getSettings();
      expect(settings2['key']?.value, 'test1');

      await Future.delayed(Duration(milliseconds: 150));

      final settings3 = await service.getSettings();
      expect(settings3['key']?.value, 'test2');

      verify(cache.write(any, any)).called(2);

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });
  });

  group('Manual Polling Tests', () {
    test('refresh', () async {
      // Arrange
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      fetcher.httpClient.interceptors.add(interceptor);
      final dioAdapter = DioAdapter(dio: fetcher.httpClient);
      final service = ConfigService(sdkKey: testSdkKey,
        mode: PollingMode.manualPoll(),
        fetcher: fetcher,
        logger: logger,
        cache: cache,
      );
      dioAdapter
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test1' }).toJson(), headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'Etag': ['tag1']
          });
        })
        ..onGet(sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]), (server) {
          server.reply(200, createTestConfig({ 'key': 'test2' }).toJson());
        }, headers: { 'If-None-Match': 'tag1' });

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

      // Cleanup
      fetcher.close();
      dioAdapter.close();
      service.close();
    });

    test('get without refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final fetcher = ConfigFetcher(logger: logger, sdkKey: testSdkKey, mode: 'm', options: const ConfigCatOptions());
      final service = ConfigService(sdkKey: testSdkKey,
          mode: PollingMode.manualPoll(),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await service.getSettings();

      // Assert
      verifyNever(cache.write(any, any));

      // Cleanup
      fetcher.close();
      service.close();
    });
  });
}
