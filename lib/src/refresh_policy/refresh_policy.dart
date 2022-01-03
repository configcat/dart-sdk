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
  Config _inMemoryValue = Config(null, new Map());

  DefaultRefreshPolicy(
      this.cache, this.fetcher, this.logger, this.jsonCache, String sdkKey) {
    this._cacheKey = 'dart_${sdkKey}_$configJsonName.json';
  }

  Future<void> writeCache(Config value) async {
    try {
      _inMemoryValue = value;
      await cache.write(_cacheKey, value.jsonString);
    } catch (e, s) {
      this.logger.error('An error occurred during the cache write.', e, s);
    }
  }

  Future<Config> readCache() async {
    try {
      final result =
          this.jsonCache.getConfigFromJson(await cache.read(_cacheKey));
      return result != null ? result : this._inMemoryValue;
    } catch (e, s) {
      this.logger.error('An error occurred during the cache read.', e, s);
      return this._inMemoryValue;
    }
  }

  Future<Config> getConfiguration();

  void close() {
    this.fetcher.close();
  }

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
    return Future.value(Config(null, new Map()));
  }

  @override
  Future<void> refresh() {
    return Future.value(null);
  }
}
