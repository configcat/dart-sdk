import '../configcat_cache.dart';
import '../config_fetcher.dart';
import '../constants.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';

abstract class RefreshPolicy {
  Future<Config> getConfiguration();
  void close();
  Future<void> refresh();
}

abstract class DefaultRefreshPolicy extends RefreshPolicy {
  final ConfigCatCache cache;
  final Fetcher fetcher;
  final ConfigCatLogger logger;
  late final String _cacheKey;
  final ConfigJsonCache jsonCache;
  Config _inMemoryValue = Config(null, {});

  DefaultRefreshPolicy(
      this.cache, this.fetcher, this.logger, this.jsonCache, String sdkKey) {
    _cacheKey = 'dart_${sdkKey}_$configJsonName.json';
  }

  Future<void> writeCache(Config value) async {
    try {
      _inMemoryValue = value;
      await cache.write(_cacheKey, value.jsonString);
    } catch (e, s) {
      logger.error('An error occurred during the cache write.', e, s);
    }
  }

  Future<Config> readCache() async {
    try {
      final result = jsonCache.getConfigFromJson(await cache.read(_cacheKey));
      return result ?? _inMemoryValue;
    } catch (e, s) {
      logger.error('An error occurred during the cache read.', e, s);
      return _inMemoryValue;
    }
  }

  @override
  Future<Config> getConfiguration();

  @override
  void close() {
    fetcher.close();
  }

  @override
  Future<void> refresh() async {
    final response = await fetcher.fetchConfiguration();
    if (response.isFetched) {
      await writeCache(response.config!);
    }
  }
}

class NullRefreshPolicy implements RefreshPolicy {
  @override
  void close() {}

  @override
  Future<Config> getConfiguration() {
    return Future.value(Config(null, {}));
  }

  @override
  Future<void> refresh() {
    return Future.value(null);
  }
}
