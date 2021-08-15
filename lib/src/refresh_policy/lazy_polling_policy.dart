import 'package:dart_sdk/src/polling_mode/polling_mode.dart';

import '../config_cat_client.dart';
import 'refresh_policy.dart';

/// Unimplemented
class LazyLoadingPolicy extends RefreshPolicy {
  late double autoPollIntervalInSeconds;
  bool initialized = false;
  ConfigChangedHandler? onConfigChanged;

  LazyLoadingPolicy({
    required cache,
    required fetcher,
    required log,
    required sdkKey,
    required LazyLoadingMode config,
  }) : super(
          cache: cache,
          fetcher: fetcher,
          log: log,
          sdkKey: sdkKey,
        ) {
    autoPollIntervalInSeconds = 0.0;
    onConfigChanged = () => {};
  }

  @override
  Future<String> getConfiguration() {
    // TODO: implement getConfiguration
    throw UnimplementedError();
  }
}