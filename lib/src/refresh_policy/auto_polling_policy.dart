import 'dart:async';

import '../configcat_cache.dart';
import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../mixins.dart';
import '../log/configcat_logger.dart';
import 'polling_mode.dart';
import 'refresh_policy.dart';

class AutoPollingPolicy extends DefaultRefreshPolicy
    with TimedInitializer<Config> {
  final AutoPollingMode _config;
  late final Timer _timer;

  AutoPollingPolicy(this._config, ConfigCatCache cache, Fetcher fetcher,
      ConfigCatLogger logger, ConfigJsonCache jsonCache, String sdkKey)
      : super(cache, fetcher, logger, jsonCache, sdkKey) {
    this._timer =
        Timer.periodic(this._config.autoPollInterval, (Timer t) async {
      await this._doRefresh();
    });

    // execute immediately, because periodic waits for an interval amount of time before the first tick
    Timer.run(() async {
      await this._doRefresh();
    });
  }

  @override
  Future<Config> getConfiguration() {
    // await for the very first fetch
    return syncFuture(() => this.readCache(), this._config.maxInitWaitTime,
        onTimeout: () {
      this.logger.warning(
          "Max init wait time for the very first fetch reached (${this._config.maxInitWaitTime.inSeconds}s). Reading cache.");
    });
  }

  @override
  void close() {
    this._timer.cancel();
    super.close();
  }

  Future<void> _doRefresh() async {
    final response = await this.fetcher.fetchConfiguration();
    final cached = await this.readCache();

    if (response.isFetched &&
        response.config!.jsonString != cached.jsonString) {
      await writeCache(response.config!);
      this._config.onConfigChanged?.call();
    }

    this.initialized();
  }
}
