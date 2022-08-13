import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'cache_test.mocks.dart';
import 'helpers.dart';
import 'config_service_test.mocks.dart';

@GenerateMocks([Fetcher])
void main() {
  final ConfigCatLogger logger = ConfigCatLogger();
  late MockConfigCatCache cache;
  late MockFetcher fetcher;
  setUp(() {
    cache = MockConfigCatCache();
    fetcher = MockFetcher();
  });

  group('Auto Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestEntry({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = ConfigService(sdkKey: '',
          mode: PollingMode.autoPoll(),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await service.refresh();

      // Assert
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(1));
      verify(fetcher.fetchConfiguration(any)).called(greaterThanOrEqualTo(1));

      // Cleanup
      service.close();
    });

    test('polling', () async {
      // Arrange
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestEntry({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));
      var onChanged = false;
      final service = ConfigService(sdkKey: '',
          mode: PollingMode.autoPoll(
              autoPollInterval: Duration(milliseconds: 100),
              onConfigChanged: () => onChanged = true),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await Future.delayed(Duration(milliseconds: 250));

      // Assert
      verify(fetcher.fetchConfiguration(any)).called(greaterThanOrEqualTo(3));
      verify(cache.write(any, any)).called(greaterThanOrEqualTo(3));
      expect(onChanged, isTrue);

      // Cleanup
      service.close();
    });

    test('max wait time', () async {
      // Arrange
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.delayed(
          Duration(milliseconds: 200),
          () => FetchResponse.success(createTestEntry({'test': 'value'}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = ConfigService(sdkKey: '',
          mode:
              PollingMode.autoPoll(maxInitWaitTime: Duration(milliseconds: 100)),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      final current = DateTime.now();
      final result = await service.getSettings();

      // Assert
      expect(DateTime.now().difference(current),
          lessThan(Duration(milliseconds: 150)));
      expect(result, isEmpty);

      // Cleanup
      service.close();
    });
  });

  group('Lazy Loading Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestEntry({'test': 'value'}))));

      final service = ConfigService(sdkKey: '',
          mode: PollingMode.lazyLoad(),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await service.refresh();

      // Assert
      verify(cache.write(any, any)).called(1);
      verify(fetcher.fetchConfiguration(any)).called(1);

      // Cleanup
      service.close();
    });

    test('reload', () async {
      // Arrange
      final results = ["value", "value2", "value3"];
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestEntry({'test': results.removeAt(0)}))));
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = ConfigService(sdkKey: '',
          mode: PollingMode.lazyLoad(
                  cacheRefreshInterval: Duration(milliseconds: 100)),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await service.getSettings();
      await service.getSettings();

      await Future.delayed(Duration(milliseconds: 150));
      await service.getSettings();

      // Assert
      verify(fetcher.fetchConfiguration(any)).called(2);
      verify(cache.write(any, any)).called(2);

      // Cleanup
      service.close();
    });
  });

  group('Manual Polling Tests', () {
    test('refresh', () async {
      // Arrange
      when(fetcher.fetchConfiguration(any)).thenAnswer((_) => Future.value(
          FetchResponse.success(createTestEntry({'test': 'value'}))));

      final service = ConfigService(sdkKey: '',
        mode: PollingMode.manualPoll(),
        fetcher: fetcher,
        logger: logger,
        cache: cache,
      );

      // Act
      await service.refresh();

      // Assert
      verify(cache.write(any, any)).called(1);
      verify(fetcher.fetchConfiguration(any)).called(1);

      // Cleanup
      service.close();
    });

    test('get without refresh', () async {
      // Arrange
      when(cache.read(any)).thenAnswer((_) => Future.value(''));

      final service = ConfigService(sdkKey: '',
          mode: PollingMode.manualPoll(),
          fetcher: fetcher,
          logger: logger,
          cache: cache);

      // Act
      await service.getSettings();

      // Assert
      verifyNever(cache.write(any, any));
      verifyNever(fetcher.fetchConfiguration(any));

      // Cleanup
      service.close();
    });
  });
}
