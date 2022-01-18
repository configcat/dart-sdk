import '../configcat_cache.dart';
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
      required ConfigCatCache cache,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigJsonCache jsonCache,
      required String sdkKey})
      : super(
            cache: cache,
            fetcher: fetcher,
            logger: logger,
            jsonCache: jsonCache,
            sdkKey: sdkKey) {
    _latestRefresh = DateTime.utc(1970, 01, 01);
    _config = config;
  }

  @override
  Future<Config> getConfiguration() async {
    final current = DateTime.now();
    if (current.isAfter(_latestRefresh.add(_config.cacheRefreshInterval))) {
      logger.debug('Cache expired, refreshing.');
      final response = await fetcher.fetchConfiguration();
      final cached = await readCache();

      if (response.isFetched &&
          response.config.jsonString != cached.jsonString) {
        await writeCache(response.config);
      }

      if (!response.isFailed) {
        _latestRefresh = DateTime.now();
      }

      return response.isFetched ? response.config : cached;
    }

    return await readCache();
  }
}
