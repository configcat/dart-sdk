import '../refresh_policy/auto_polling_policy.dart';
import '../refresh_policy/lazy_polling_policy.dart';
import '../refresh_policy/manual_polling_policy.dart';
import 'package:logging/logging.dart';

import '../config_cache.dart';
import '../config_cat_client.dart';
import '../config_fetcher.dart';
import '../refresh_policy/refresh_policy.dart';

abstract class PollingMode {
  getPollingIdentifier();
  RefreshPolicy accept({visitor: PollingModeVisitor});
}

abstract class PollingModeVisitor {
  RefreshPolicy visitWithAutoPolling({pollingMode: AutoPollingMode});
  RefreshPolicy visitWithManualPolling({pollingMode: ManualPollingMode});
  RefreshPolicy visitWithLazyPolling({pollingMode: LazyLoadingMode});
}

class AutoPollingMode extends PollingMode {
  int autoPollIntervalInSeconds;
  ConfigChangedHandler? onConfigChanged;

  AutoPollingMode(
      {this.autoPollIntervalInSeconds = 120, this.onConfigChanged = null});

  @override
  RefreshPolicy accept({visitor = PollingModeVisitor}) {
    return visitor.visitWithAutoPolling(pollingMode: this);
  }

  @override
  getPollingIdentifier() {
    return 'a';
  }
}

class ManualPollingMode extends PollingMode {
  @override
  RefreshPolicy accept({visitor = PollingModeVisitor}) {
    return visitor.visit(pollingMode: this);
  }

  @override
  getPollingIdentifier() {
    return 'm';
  }
}

class LazyLoadingMode extends PollingMode {
  int cacheRefreshIntervalInSeconds;
  bool useAsyncRefresh;

  LazyLoadingMode(
      {this.cacheRefreshIntervalInSeconds = 120,
      this.useAsyncRefresh = false});

  @override
  RefreshPolicy accept({visitor = PollingModeVisitor}) {
    return visitor.visit(pollingMode: this);
  }

  @override
  getPollingIdentifier() {
    return "l";
  }
}

class RefreshPolicyFactory extends PollingModeVisitor {
  final ConfigCache cache;
  final ConfigFetcher fetcher;
  final String sdkKey;
  final Logger log;

  RefreshPolicyFactory(
      {required this.cache,
      required this.fetcher,
      required this.sdkKey,
      required this.log});

  @override
  RefreshPolicy visitWithAutoPolling({pollingMode = AutoPollingMode}) {
    return AutoPollingPolicy(
        cache: cache,
        fetcher: fetcher,
        log: log,
        sdkKey: sdkKey,
        config: pollingMode);
  }

  @override
  RefreshPolicy visitWithLazyPolling({pollingMode = LazyLoadingMode}) {
    return LazyLoadingPolicy(
        cache: cache,
        fetcher: fetcher,
        log: log,
        sdkKey: sdkKey,
        config: pollingMode);
  }

  @override
  RefreshPolicy visitWithManualPolling({pollingMode = ManualPollingMode}) {
    return ManualPollingPolicy(
        cache: cache,
        fetcher: fetcher,
        log: log,
        sdkKey: sdkKey,
        config: pollingMode);
  }
}
