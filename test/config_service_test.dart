import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/error_reporter.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  final ConfigCatLogger logger = ConfigCatLogger();
  late MockConfigCatCache cache;
  late ConfigFetcher fetcher;
  late HttpTestAdapter testAdapter;
  setUp(() {
    cache = MockConfigCatCache();
    fetcher = ConfigFetcher(
        logger: logger,
        sdkKey: testSdkKey,
        options: const ConfigCatOptions(),
        errorReporter: ErrorReporter(logger, Hooks()));
    testAdapter = HttpTestAdapter(fetcher.httpClient);
  });
  tearDown(() {
    testAdapter.close();
  });

  ConfigService createService(PollingMode pollingMode,
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
      final service = createService(PollingMode.manualPoll());

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson());

      // Act
      final future1 = service.refresh();
      final future2 = service.refresh();
      final future3 = service.refresh();
      await future1;
      await future2;
      await future3;

      // Assert
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });
  });

  group('Auto Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.autoPoll());

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test2'}).toJson());

      // Act
      await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.settingValue.stringValue, 'test2');
      verify(cache.write(any, any)).called(equals(2));
      expect(testAdapter.capturedRequests.length, 2);
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');

      // Cleanup
      service.close();
    });

    test('polling', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(
          PollingMode.autoPoll(autoPollInterval: const Duration(seconds: 1)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test2'}).toJson(),
          headers: {'Etag': 'tag2'});

      // Act
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');
      verify(cache.write(any, argThat(contains("tag1")))).called(1);

      // Act
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.settingValue.stringValue, 'test1');
      verifyNever(cache.write(any, any));

      await until(() async {
        final settings3 = await service.getSettings();
        final value = settings3.settings['key']?.settingValue.stringValue ?? '';
        return value == 'test2';
      }, const Duration(milliseconds: 2500));

      expect(testAdapter.capturedRequests.length, 2);
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');
      verify(cache.write(any, argThat(contains("tag2")))).called(1);

      // Cleanup
      service.close();
    });

    test('ensure not initiate multiple fetches', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.autoPoll());
      testAdapter.enqueueResponse(getPath(), 500, {});

      // Act
      await service.getSettings();
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('ensure cached fetch time is respected on interval calc', () async {
      // Arrange
      final cached = createTestEntry({'key': true}).serialize();
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 200)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': true}).toJson());

      // Assert
      expect(testAdapter.capturedRequests.length, 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));

      // Assert
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('online/offline', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 200)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson());

      // Act
      await Future.delayed(const Duration(milliseconds: 500));
      service.offline();
      var reqCount = testAdapter.capturedRequests.length;

      // Assert
      expect(reqCount, greaterThanOrEqualTo(3));

      // Act
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(testAdapter.capturedRequests.length, equals(reqCount));

      // Act
      service.online();
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(testAdapter.capturedRequests.length, greaterThanOrEqualTo(6));

      // Cleanup
      service.close();
    });

    test('init offline', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(
          PollingMode.autoPoll(
              autoPollInterval: const Duration(milliseconds: 200)),
          offline: true);
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson());

      // Act
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(testAdapter.capturedRequests.length, equals(0));

      // Act
      service.online();
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(testAdapter.capturedRequests.length, greaterThanOrEqualTo(3));

      // Cleanup
      service.close();
    });

    test('failing', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.autoPoll(
          autoPollInterval: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(getPath(), 500, {});

      // Act
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');

      // Act
      await Future.delayed(const Duration(milliseconds: 500));
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.settingValue.stringValue, 'test1');
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(1));
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');

      // Cleanup
      service.close();
    });

    test('max wait time', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          delay: const Duration(seconds: 2));

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
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('max wait time ignored when the cache is not expired yet', () async {
      // Arrange
      final cached = createTestEntry({'key': true}).serialize();
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 300),
          autoPollInterval: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          delay: const Duration(seconds: 2));

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
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('max wait timeout returns cached config', () async {
      // Arrange
      final cached =
          createTestEntryWithTime({'key': true}, distantPast).serialize();
      when(cache.read(any)).thenAnswer((_) => Future.value(cached));

      final service = createService(PollingMode.autoPoll(
          maxInitWaitTime: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': false}).toJson(),
          delay: const Duration(seconds: 2));

      // Act
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(const Duration(milliseconds: 200)));
      expect(result.settings['key']?.settingValue.booleanValue, isTrue);

      // Cleanup
      service.close();
    });
  });

  group('Lazy Loading Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = createService(PollingMode.lazyLoad(
          cacheRefreshInterval: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test2'}).toJson());

      // Act
      await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.settingValue.stringValue, 'test2');
      verify(cache.write(any, any)).called(2);
      expect(testAdapter.capturedRequests.length, 2);
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');

      // Cleanup
      service.close();
    });

    test('reload', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = createService(PollingMode.lazyLoad(
          cacheRefreshInterval: const Duration(milliseconds: 100)));

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test2'}).toJson());

      final settings1 = await service.getSettings();
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');
      final settings2 = await service.getSettings();
      expect(settings2.settings['key']?.settingValue.stringValue, 'test1');

      await until(() async {
        final settings3 = await service.getSettings();
        final value = settings3.settings['key']?.settingValue.stringValue ?? '';
        return value == 'test2';
      }, const Duration(milliseconds: 150));

      verify(cache.write(any, any)).called(2);
      expect(testAdapter.capturedRequests.length, 2);
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');

      // Cleanup
      service.close();
    });

    test('ensure cached fetch time is respected on TTL calc', () async {
      // Arrange
      final cache = CustomCache(createTestEntry({'key': true}).serialize());
      final service = createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': true}).toJson());

      // Act
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(testAdapter.capturedRequests.length, 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('ensure cached fetch time is respected on TTL with 301', () async {
      // Arrange
      final cache = CustomCache(createTestEntry({'key': true}).serialize());

      testAdapter.enqueueResponse(getPath(), 304, {});

      // Act
      final service = createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      await service.getSettings();
      await service.getSettings();

      // Assert
      expect(testAdapter.capturedRequests.length, 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));
      await service.getSettings();

      final service2 = createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);
      await service2.getSettings();
      await service2.getSettings();

      // Assert
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
      service2.close();
    });

    test('ensure cached TTL respects external cache', () async {
      final cache = CustomCache(
          createTestEntryWithETag({'key': 'test-local'}, "etag").serialize());
      final service = createService(
          PollingMode.lazyLoad(
              cacheRefreshInterval: const Duration(milliseconds: 200)),
          customCache: cache);

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test-remote'}).toJson());

      // Act
      final settings = await service.getSettings();

      // Assert
      expect(settings.settings["key"]!.settingValue.stringValue, 'test-local');
      expect(testAdapter.capturedRequests.length, 0);

      // Act
      await Future.delayed(const Duration(milliseconds: 300));
      cache.write("",
          createTestEntryWithETag({'key': 'test-local2'}, "etag2").serialize());

      final settings2 = await service.getSettings();

      // Assert
      expect(
          settings2.settings["key"]!.settingValue.stringValue, 'test-local2');
      expect(testAdapter.capturedRequests.length, 0);

      // Cleanup
      service.close();
    });
  });

  group('Manual Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = createService(PollingMode.manualPoll());

      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test1'}).toJson(),
          headers: {'Etag': 'tag1'});
      testAdapter.enqueueResponse(
          getPath(), 200, createTestConfig({'key': 'test2'}).toJson());

      // Act
      final result = await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(settings1.settings['key']?.settingValue.stringValue, 'test1');

      // Act
      await service.refresh();
      final settings2 = await service.getSettings();

      // Assert
      expect(settings2.settings['key']?.settingValue.stringValue, 'test2');
      verify(cache.write(any, any)).called(2);
      expect(testAdapter.capturedRequests.length, 2);
      expect(
          testAdapter.capturedRequests.last.headers['If-None-Match'], 'tag1');

      // Cleanup
      service.close();
    });

    test('failing refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = createService(PollingMode.manualPoll());

      testAdapter.enqueueResponse(getPath(), 500, {});

      // Act
      final result = await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(result.isSuccess, isFalse);
      expect(
          result.error,
          equals(
              "Unexpected HTTP response was received while trying to fetch config JSON: 500 null"));
      expect(settings1.settings, isEmpty);

      verifyNever(cache.write(any, any));
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('failing refresh 404', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      final service = createService(PollingMode.manualPoll());

      testAdapter.enqueueResponse(getPath(), 404, {});

      // Act
      final result = await service.refresh();
      final settings1 = await service.getSettings();

      // Assert
      expect(result.isSuccess, isFalse);
      expect(
          result.error,
          equals(
              "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey. Received unexpected response: 404 null"));
      expect(settings1.settings, isEmpty);

      verifyNever(cache.write(any, any));
      expect(testAdapter.capturedRequests.length, 1);

      // Cleanup
      service.close();
    });

    test('get without refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = createService(PollingMode.manualPoll());

      // Act
      await service.getSettings();

      // Assert
      verifyNever(cache.write(any, any));
      expect(testAdapter.capturedRequests.length, 0);

      // Cleanup
      service.close();
    });
  });
}
