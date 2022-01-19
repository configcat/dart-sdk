import '../config_fetcher.dart';
import '../json/config_json_cache.dart';
import '../json/config.dart';
import '../log/configcat_logger.dart';
import 'polling_mode.dart';
import 'refresh_policy.dart';

class LazyLoadingPolicy extends DefaultRefreshPolicy {
  late final LazyLoadingMode _config;
  late DateTime _latestRefresh;

  LazyLoadingPolicy(
      {required LazyLoadingMode config,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigJsonCache jsonCache})
      : super(
            fetcher: fetcher,
            logger: logger,
            jsonCache: jsonCache) {
    _latestRefresh = DateTime.utc(1970, 01, 01);
    _config = config;
  }

  @override
  Future<Config> getConfiguration() async {
    final current = DateTime.now().toUtc();
    if (current.isAfter(_latestRefresh.add(_config.cacheRefreshInterval))) {
      logger.debug('Cache expired, refreshing.');
      final response = await fetcher.fetchConfiguration();
      if (response.isFetched) {
        await jsonCache.writeCache(response.config);
      }

      if (!response.isFailed) {
        _latestRefresh = DateTime.now().toUtc();
      }
    }

    return await jsonCache.readCache();
  }
}
