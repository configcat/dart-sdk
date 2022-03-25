import 'dart:async';

import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';
import '../mixins.dart';
import 'polling_mode.dart';
import 'refresh_policy.dart';

class AutoPollingPolicy extends DefaultRefreshPolicy
    with TimedInitializer<Config> {
  late final AutoPollingMode _config;
  late final Timer _timer;

  AutoPollingPolicy(
      {required AutoPollingMode config,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigJsonCache jsonCache})
      : super(fetcher: fetcher, logger: logger, jsonCache: jsonCache) {
    _config = config;
    _timer = Timer.periodic(_config.autoPollInterval, (Timer t) async {
      await _doRefresh();
    });

    // execute immediately, because periodic waits for an interval amount of time before the first tick
    Timer.run(() async {
      await _doRefresh();
    });
  }

  @override
  Future<Config> getConfiguration() {
    // await for the very first fetch
    return syncFuture(() => jsonCache.readCache(), _config.maxInitWaitTime,
        onTimeout: () {
      logger.warning(
          'Max init wait time for the very first fetch reached (${_config.maxInitWaitTime.inSeconds}s). Reading cache.');
    });
  }

  @override
  void close() {
    _timer.cancel();
    super.close();
  }

  Future<void> _doRefresh() async {
    final response = await fetcher.fetchConfiguration();
    if (response.isFetched) {
      await jsonCache.writeCache(response.config);
    }

    initialized();
  }
}
