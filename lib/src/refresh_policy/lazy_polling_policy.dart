import '../configcat_cache.dart';
import '../config_fetcher.dart';
import '../json/config_json_cache.dart';
import '../json/config.dart';
import '../log/configcat_logger.dart';
import 'polling_mode.dart';
import 'refresh_policy.dart';

class LazyLoadingPolicy extends DefaultRefreshPolicy {
  final LazyLoadingMode _config;
  late DateTime _latestRefresh;

  LazyLoadingPolicy(this._config, ConfigCatCache cache, Fetcher fetcher,
      ConfigCatLogger logger, ConfigJsonCache jsonCache, String sdkKey)
      : super(cache, fetcher, logger, jsonCache, sdkKey) {
    this._latestRefresh = DateTime.utc(1970, 01, 01);
  }

  @override
  Future<Config> getConfiguration() async {
    final current = DateTime.now();
    if (current
        .isAfter(this._latestRefresh.add(this._config.cacheRefreshInterval))) {
      this.logger.debug('Cache expired, refreshing.');
      final response = await this.fetcher.fetchConfiguration();
      final cached = await readCache();

      if (response.isFetched &&
          response.config!.jsonString != cached.jsonString) {
        await writeCache(response.config!);
      }

      if (!response.isFailed) {
        this._latestRefresh = DateTime.now();
      }

      return response.isFetched ? response.config! : cached;
    }

    return await readCache();
  }
}
