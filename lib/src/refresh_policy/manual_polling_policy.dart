import '../configcat_cache.dart';
import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';
import 'refresh_policy.dart';

class ManualPollingPolicy extends DefaultRefreshPolicy {
  ManualPollingPolicy(
      {required ConfigCatCache cache,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigJsonCache jsonCache,
      required String sdkKey})
      : super(
            cache: cache,
            fetcher: fetcher,
            logger: logger,
            jsonCache: jsonCache,
            sdkKey: sdkKey);

  @override
  Future<Config> getConfiguration() {
    return readCache();
  }
}
