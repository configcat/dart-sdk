import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';
import 'refresh_policy.dart';

class ManualPollingPolicy extends DefaultRefreshPolicy {
  ManualPollingPolicy(
      {required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigJsonCache jsonCache})
      : super(fetcher: fetcher, logger: logger, jsonCache: jsonCache);

  @override
  Future<Config> getConfiguration() {
    return jsonCache.readCache();
  }
}
