import 'package:configcat_client/src/client_cache_state.dart';
import 'package:configcat_client/src/error_reporter.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:configcat_client/src/flag_evaluator.dart';

import 'configcat_log_messages.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';

/// Represents the state of [ConfigCatClient] captured at a specific point in time.
class ConfigCatClientSnapshot {
  final FlagEvaluator _flagEvaluator;
  final SettingResult _settingResult;
  final ConfigCatUser? _defaultUser;
  final ClientCacheState _clientCacheState;
  final ErrorReporter _errorReporter;

  ConfigCatClientSnapshot(this._flagEvaluator, this._settingResult,
      this._defaultUser, this._clientCacheState, this._errorReporter);

  /// The state of the internal cache at the time the snapshot was created.
  ClientCacheState get cacheState {
    return _clientCacheState;
  }

  /// Gets the value of a feature flag or setting as [T] identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only the following types are allowed: [String], [bool], [int], [double], [Object] (both nullable and non-nullable) and [dynamic].
  T getValue<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    _flagEvaluator.validateReturnType();

    final evalUser = user ?? _defaultUser;
    return _flagEvaluator
        .evaluate(key, evalUser, defaultValue, _settingResult)
        .value;
  }

  /// Gets the value and evaluation details of a feature flag or setting identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only the following types are allowed: [String], [bool], [int], [double], [Object] (both nullable and non-nullable) and [dynamic].
  EvaluationDetails<T> getValueDetails<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    _flagEvaluator.validateReturnType();

    final evalUser = user ?? _defaultUser;
    return _flagEvaluator.evaluate(key, evalUser, defaultValue, _settingResult);
  }

  /// Gets a collection of all setting keys.
  List<String> getAllKeys() {
    if (_settingResult.isEmpty) {
      _errorReporter.error(
          1000,
          ConfigCatLogMessages.getConfigJsonIsNotPresentedWithEmptyResult(
              "empty list"));
      return [];
    }
    return _settingResult.settings.keys.toList();
  }
}
