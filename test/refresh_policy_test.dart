import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/config_fetcher.dart';
import 'package:configcat_client/src/json/config_json_cache.dart';
import 'package:configcat_client/src/refresh_policy/auto_polling_policy.dart';
import 'package:configcat_client/src/refresh_policy/lazy_polling_policy.dart';
import 'package:configcat_client/src/refresh_policy/manual_polling_policy.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'refresh_policy_test.mocks.dart';

@GenerateMocks([Fetcher])
void main() {
  final ConfigCatLogger logger = ConfigCatLogger();
  late ConfigJsonCache jsonCache;
  late MockConfigCatCache cache;
  late MockFetcher fetcher;
  setUp(() {
    cache = MockConfigCatCache();
    fetcher = MockFetcher();
    jsonCache =
        ConfigJsonCache(logger: logger, cache: cache, sdkKey: testSdkKey);
  });

  group('Auto Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestConfig({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final poll = AutoPollingPolicy(
          config: PollingMode.autoPoll() as AutoPollingMode,
          fetcher: fetcher,
          logger: logger,
          jsonCache: jsonCache);

      // Act
      await poll.refresh();

      // Assert
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(1));
      verify(fetcher.fetchConfiguration()).called(greaterThanOrEqualTo(1));

      // Cleanup
      poll.close();
    });

    test('polling', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestConfig({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      var onChanged = false;
      final poll = AutoPollingPolicy(
          config: PollingMode.autoPoll(
              autoPollInterval: Duration(milliseconds: 100),
              onConfigChanged: () => onChanged = true) as AutoPollingMode,
          fetcher: fetcher,
          logger: logger,
          jsonCache: jsonCache);

      // Act
      await Future.delayed(Duration(milliseconds: 250));

      // Assert
      verify(fetcher.fetchConfiguration()).called(greaterThanOrEqualTo(3));
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(3));
      expect(onChanged, isTrue);

      // Cleanup
      poll.close();
    });

    test('max wait time', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.delayed(
          Duration(milliseconds: 200),
          () => FetchResponse.success(createTestConfig({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final poll = AutoPollingPolicy(
          config:
              PollingMode.autoPoll(maxInitWaitTime: Duration(milliseconds: 100))
                  as AutoPollingMode,
          fetcher: fetcher,
          logger: logger,
          jsonCache: jsonCache);

      // Act
      final current = DateTime.now();
      final result = await poll.getConfiguration();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(Duration(milliseconds: 150)));
      expect(result.entries, isEmpty);

      // Cleanup
      poll.close();
    });
  });

  group('Lazy Loading Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestConfig({'test': 'value'}))));

      final poll = LazyLoadingPolicy(
          config: PollingMode.lazyLoad() as LazyLoadingMode,
          fetcher: fetcher,
          logger: logger,
          jsonCache: jsonCache);

      // Act
      await poll.refresh();

      // Assert
      verify(cache.write(any, any)).called(1);
      verify(fetcher.fetchConfiguration()).called(1);

      // Cleanup
      poll.close();
    });

    test('reload', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestConfig({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final poll = LazyLoadingPolicy(
          config: PollingMode.lazyLoad(
                  cacheRefreshIntervalInSeconds: Duration(milliseconds: 100))
              as LazyLoadingMode,
          fetcher: fetcher,
          logger: logger,
          jsonCache: jsonCache);

      // Act
      await poll.getConfiguration();
      await poll.getConfiguration();

      await Future.delayed(Duration(milliseconds: 150));
      await poll.getConfiguration();

      // Assert
      verify(fetcher.fetchConfiguration()).called(2);
      verify(cache.write(any, any)).called(2);

      // Cleanup
      poll.close();
    });
  });

  group('Manual Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration()).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestConfig({'test': 'value'}))));

      final poll = ManualPollingPolicy(
        fetcher: fetcher,
        logger: logger,
        jsonCache: jsonCache,
      );

      // Act
      await poll.refresh();

      // Assert
      verify(cache.write(any, any)).called(1);
      verify(fetcher.fetchConfiguration()).called(1);

      // Cleanup
      poll.close();
    });

    test('get without refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final poll = ManualPollingPolicy(
          fetcher: fetcher, logger: logger, jsonCache: jsonCache);

      // Act
      await poll.getConfiguration();

      // Assert
      verifyNever(cache.write(any, any));
      verifyNever(fetcher.fetchConfiguration());

      // Cleanup
      poll.close();
    });
  });
}
