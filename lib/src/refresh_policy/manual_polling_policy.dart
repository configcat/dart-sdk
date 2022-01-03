import '../configcat_cache.dart';
import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';
import 'refresh_policy.dart';

class ManualPollingPolicy extends DefaultRefreshPolicy {
  ManualPollingPolicy(ConfigCatCache cache, Fetcher fetcher,
      ConfigCatLogger logger, ConfigJsonCache jsonCache, String sdkKey)
      : super(cache, fetcher, logger, jsonCache, sdkKey) {}

  @override
  Future<Config> getConfiguration() {
    return readCache();
  }
}
