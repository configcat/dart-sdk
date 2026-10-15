import 'package:configcat_client/src/client_cache_state.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:configcat_client/src/flag_evaluator.dart';
import 'package:configcat_client/src/snapshot.dart';

import 'configcat_options.dart';
import 'configcat_user.dart';
import 'constants.dart';
import 'error_reporter.dart';
import 'json/setting.dart';
import 'override/behaviour.dart';
import 'override/flag_overrides.dart';

class SnapshotBuilder {
  ConfigCatUser? defaultUser;

  final FlagOverrides? _flagOverrides;
  final FlagEvaluator _flagEvaluator;
  final ErrorReporter _errorReporter;
  final Hooks _hooks;

  SnapshotBuilder(this._flagEvaluator, this._flagOverrides, this._errorReporter,
      this.defaultUser, this._hooks);

  ConfigCatClientSnapshot buildSnapshot(InMemoryResult inMemoryResult) {
    final result = calcInMemoryResultWithOverrides(inMemoryResult);
    return ConfigCatClientSnapshot(_flagEvaluator, result.settingResult,
        defaultUser, result.cacheState, _errorReporter, _hooks);
  }

  InMemoryResult calcInMemoryResultWithOverrides(
      InMemoryResult inMemoryResult) {
    final overrides = _flagOverrides;
    if (overrides != null) {
      switch (overrides.behaviour) {
        case OverrideBehaviour.localOnly:
          return InMemoryResult(
              SettingResult(
                settings: overrides.dataSource.getOverrides(),
                fetchTime: distantPast,
              ),
              ClientCacheState.hasLocalOverrideFlagDataOnly);
        case OverrideBehaviour.localOverRemote:
          final remote = inMemoryResult.settingResult.settings;
          final local = overrides.dataSource.getOverrides();
          return InMemoryResult(
              SettingResult(
                  settings: Map<String, Setting>.of(remote)..addAll(local),
                  fetchTime: inMemoryResult.settingResult.fetchTime),
              inMemoryResult.cacheState);
        case OverrideBehaviour.remoteOverLocal:
          final remote = inMemoryResult.settingResult.settings;
          final local = overrides.dataSource.getOverrides();
          return InMemoryResult(
              SettingResult(
                  settings: Map<String, Setting>.of(local)..addAll(remote),
                  fetchTime: inMemoryResult.settingResult.fetchTime),
              inMemoryResult.cacheState);
      }
    }
    return inMemoryResult;
  }
}
