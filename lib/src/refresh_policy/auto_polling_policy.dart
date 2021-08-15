import 'dart:async';

import '../polling_mode/polling_mode.dart';

import 'refresh_policy.dart';

import '../config_cat_client.dart';

class AutoPollingPolicy extends RefreshPolicy {
  late int autoPollIntervalInSeconds;
  ConfigChangedHandler? onConfigChanged;

  AutoPollingPolicy({
    required cache,
    required fetcher,
    required log,
    required sdkKey,
    required AutoPollingMode config,
  }) : super(
          cache: cache,
          fetcher: fetcher,
          log: log,
          sdkKey: sdkKey,
        ) {
    autoPollIntervalInSeconds = config.autoPollIntervalInSeconds;
    onConfigChanged = () => {};

    Timer.periodic(Duration(seconds: autoPollIntervalInSeconds), (Timer t) async {
      final response = await fetcher.fetchConfigurationJson();
      final cached = readCache();
      
      if (response.isFetched && response.body != cached) {
        writeCache(response.body);
        onConfigChanged?.call();
      }
    });
  }

  @override
  Future<String> getConfiguration() {
    final completer = Completer<String>();
    completer.complete(readCache());
    return completer.future;
  }

  
}
