import 'dart:async';

import 'package:configcat_client/src/client_cache_state.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/errors.dart';
import 'package:configcat_client/src/fetch/refresh_result.dart';
import 'package:configcat_client/src/flag_evaluator.dart';
import 'package:configcat_client/src/log/logger.dart';
import 'package:configcat_client/src/snapshot.dart';
import 'package:configcat_client/src/snapshot_builder.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'configcat_log_messages.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';
import 'error_reporter.dart';
import 'fetch/config_fetcher.dart';
import 'fetch/config_service.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';
import 'override/behaviour.dart';
import 'override/flag_overrides.dart';
import 'rollout_evaluator.dart';

/// ConfigCat SDK client.
class ConfigCatClient {
  late final ConfigCatLogger _logger;
  late final LogLevel _logLevel;
  late final ConfigService? _configService;
  late final RolloutEvaluator _rolloutEvaluator;
  late final Fetcher _fetcher;
  late final FlagOverrides? _override;
  late final ErrorReporter _errorReporter;
  late final Hooks _hooks;
  late final FlagEvaluator _flagEvaluator;
  late final SnapshotBuilder _snapshotBuilder;
  static final Map<String, ConfigCatClient> _instanceRepository = {};
  bool _isClosed = false;

  /// Creates a new or gets an already existing [ConfigCatClient] for the given [sdkKey].
  factory ConfigCatClient.get(
      {required String sdkKey,
      ConfigCatOptions options = ConfigCatOptions.defaultOptions}) {
    if (sdkKey.isEmpty) {
      throw ArgumentError('SDK Key cannot be empty.');
    }

    if (options.override?.behaviour != OverrideBehaviour.localOnly &&
        !_isValidKey(sdkKey, options.isBaseUrlCustom())) {
      throw ArgumentError("SDK Key '$sdkKey' is invalid.");
    }

    var client = _instanceRepository[sdkKey];
    if (client != null && options != ConfigCatOptions.defaultOptions) {
      client._logger.warning(
          3000, ConfigCatLogMessages.getClientIsAlreadyCreated(sdkKey));
    }
    client ??= _instanceRepository[sdkKey] = ConfigCatClient._(sdkKey, options);
    return client;
  }

  /// Closes all [ConfigCatClient] instances.
  static void closeAll() {
    for (final client in _instanceRepository.entries) {
      client.value._closeResources();
    }
    _instanceRepository.clear();
  }

  ConfigCatClient._(String sdkKey, ConfigCatOptions options) {
    _logger = options.logger ?? ConfigCatLogger();
    _logLevel = _logger.getLogLevel();
    _override = options.override;
    _hooks = Hooks();
    options.hooks?.call(_hooks);

    final cache = options.cache ?? NullConfigCatCache();

    _rolloutEvaluator = RolloutEvaluator(_logger);
    _errorReporter = ErrorReporter(_logger, _hooks);
    _fetcher = ConfigFetcher(
        logger: _logger,
        sdkKey: sdkKey,
        options: options,
        errorReporter: _errorReporter);

    _flagEvaluator = FlagEvaluator(_hooks, _rolloutEvaluator, _logLevel);
    _snapshotBuilder = SnapshotBuilder(
        _flagEvaluator, _override, _errorReporter, options.defaultUser, _hooks);

    if (_override != null &&
        _override!.behaviour == OverrideBehaviour.localOnly) {
      _configService = null;
      _hooks.invokeOnReady(ClientCacheState.hasLocalOverrideFlagDataOnly,
          _snapshotBuilder, InMemoryResult.empty);
    } else {
      _configService = ConfigService(
          sdkKey: sdkKey,
          mode: options.pollingMode,
          hooks: _hooks,
          fetcher: _fetcher,
          logger: _logger,
          cache: cache,
          errorReporter: _errorReporter,
          snapshotBuilder: _snapshotBuilder,
          offline: options.offline);
    }
  }

  /// Gets the value of a feature flag or setting as [T] identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only the following types are allowed: [String], [bool], [int], [double], [Object] (both nullable and non-nullable) and [dynamic].
  Future<T> getValue<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    FlagEvaluator.validateReturnType<T>();

    final evalUser = user ?? _snapshotBuilder.defaultUser;

    try {
      final result = await _getSettings();
      return _flagEvaluator.evaluate(key, evalUser, defaultValue, result).value;
    } catch (e, s) {
      final evalError = e is EvaluationError ? e : null;
      final messageToLog = evalError?.messageToLog ??
          ConfigCatLogMessages.getSettingEvaluationErrorWithDefaultValue(
              "getValue", key, "defaultValue", defaultValue);
      _errorReporter.error(evalError?.eventId ?? 1002, messageToLog, e, s);
      final details = EvaluationDetails.makeError(
          key,
          defaultValue,
          e is HasMessage ? e.message : messageToLog,
          errorCodeFrom(e),
          e,
          evalUser);
      _hooks.invokeFlagEvaluated(details);
      return defaultValue;
    }
  }

  /// Gets the value and evaluation details of a feature flag or setting identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only the following types are allowed: [String], [bool], [int], [double], [Object] (both nullable and non-nullable) and [dynamic].
  Future<EvaluationDetails<T>> getValueDetails<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    FlagEvaluator.validateReturnType<T>();

    final evalUser = user ?? _snapshotBuilder.defaultUser;
    try {
      final result = await _getSettings();
      return _flagEvaluator.evaluate(key, evalUser, defaultValue, result);
    } catch (e, s) {
      final evalError = e is EvaluationError ? e : null;
      final messageToLog = evalError?.messageToLog ??
          ConfigCatLogMessages.getSettingEvaluationErrorWithDefaultValue(
              "getValueDetails", key, "defaultValue", defaultValue);
      _errorReporter.error(evalError?.eventId ?? 1002, messageToLog, e, s);
      final details = EvaluationDetails.makeError(
          key,
          defaultValue,
          e is HasMessage ? e.message : messageToLog,
          errorCodeFrom(e),
          e,
          evalUser);
      _hooks.invokeFlagEvaluated(details);
      return details;
    }
  }

  /// Gets the detailed values of all feature flags or settings.
  ///
  /// [user] the user object.
  /// Return a collection of all the evaluation results with details.
  Future<List<EvaluationDetails>> getAllValueDetails({
    ConfigCatUser? user,
  }) async {
    final evalUser = user ?? _snapshotBuilder.defaultUser;
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000,
            ConfigCatLogMessages.getConfigJsonIsNotPresentedWithEmptyResult(
                "empty list"));
        return [];
      }
      final detailsResult = List<EvaluationDetails>.empty(growable: true);
      result.settings.forEach((key, value) {
        detailsResult
            .add(_flagEvaluator.evaluateSetting(key, value, evalUser, result));
      });

      return detailsResult;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          ConfigCatLogMessages.getSettingEvaluationErrorWithEmptyValue(
              "getAllValueDetails", "empty list"),
          e,
          s);
      return [];
    }
  }

  /// Gets a collection of all setting keys.
  Future<List<String>> getAllKeys() async {
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000,
            ConfigCatLogMessages.getConfigJsonIsNotPresentedWithEmptyResult(
                "empty list"));
        return [];
      }

      return result.settings.keys.toList();
    } catch (e, s) {
      _errorReporter.error(
          1002,
          ConfigCatLogMessages.getSettingEvaluationErrorWithEmptyValue(
              "getAllKeys", "empty list"),
          e,
          s);
      return [];
    }
  }

  /// Gets the values of all feature flags or settings.
  ///
  /// [user] the user object.
  Future<Map<String, dynamic>> getAllValues({ConfigCatUser? user}) async {
    try {
      final settingsResult = await _getSettings();
      if (settingsResult.isEmpty) {
        _errorReporter.error(
            1000,
            ConfigCatLogMessages.getConfigJsonIsNotPresentedWithEmptyResult(
                "empty map"));
        return {};
      }

      final result = <String, dynamic>{};
      settingsResult.settings.forEach((key, value) {
        result[key] = _flagEvaluator
            .evaluateSetting(key, value, user ?? _snapshotBuilder.defaultUser,
                settingsResult)
            .value;
      });

      return result;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          ConfigCatLogMessages.getSettingEvaluationErrorWithEmptyValue(
              "getAllValues", "empty map"),
          e,
          s);
      return {};
    }
  }

  /// Gets the key of a setting and its value identified by the given [variationId] (analytics).
  /// [variationId] the Variation ID.
  /// [T] the type of the desired feature flag or setting. Only the following types are allowed: [String], [bool], [int], [double], [Object] (both nullable and non-nullable) and [dynamic].
  Future<MapEntry<String, T>?> getKeyAndValue<T>(
      {required String variationId}) async {
    FlagEvaluator.validateReturnType<T>();

    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000,
            ConfigCatLogMessages.getConfigJsonIsNotPresentedWithEmptyResult(
                "null"));
        return null;
      }

      for (final entry in result.settings.entries) {
        if (entry.value.variationId == variationId) {
          return MapEntry(
              entry.key,
              _flagEvaluator.parseSettingValue<T>(
                  entry.value.settingValue, entry.value.type));
        }

        for (final targetingRule in entry.value.targetingRules) {
          if (targetingRule.servedValue != null) {
            if (targetingRule.servedValue?.variationId == variationId) {
              return MapEntry(
                  entry.key,
                  _flagEvaluator.parseSettingValue<T>(
                      targetingRule.servedValue!.settingValue,
                      entry.value.type));
            }
          } else {
            var targetRulePercentageOptions = targetingRule.percentageOptions;
            if (targetRulePercentageOptions != null) {
              for (final percentageOption in targetRulePercentageOptions) {
                if (percentageOption.variationId == variationId) {
                  return MapEntry(
                      entry.key,
                      _flagEvaluator.parseSettingValue<T>(
                          percentageOption.settingValue, entry.value.type));
                }
              }
            } else {
              throw InvalidConfigModelError(
                  "Targeting rule THEN part is missing or invalid.");
            }
          }
        }

        for (final percentageOption in entry.value.percentageOptions) {
          if (percentageOption.variationId == variationId) {
            return MapEntry(
                entry.key,
                _flagEvaluator.parseSettingValue<T>(
                    percentageOption.settingValue, entry.value.type));
          }
        }
      }

      _errorReporter.error(
          2011,
          ConfigCatLogMessages.getSettingForVariationIdIsNotPresent(
              variationId));
      return null;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          ConfigCatLogMessages.getSettingEvaluationErrorWithEmptyValue(
              "getKeyAndValue", "null"),
          e,
          s);
      return null;
    }
  }

  /// Gets the underlying [Dio] HTTP client.
  Dio get httpClient {
    return _fetcher.httpClient;
  }

  /// Gets the [Hooks] object for subscribing events.
  Hooks get hooks {
    return _hooks;
  }

  /// Updates the internally cached config by synchronizing with the external cache (if any),
  /// then by fetching the latest version from the ConfigCat CDN (provided that the client is online).
  Future<RefreshResult> forceRefresh() {
    try {
      return _configService?.refresh() ??
          Future.value(RefreshResult(
              false,
              'Client is configured to use the `localOnly` override behavior, which prevents synchronization with external cache and making HTTP requests.',
              RefreshErrorCode.localOnlyClient));
    } catch (e, s) {
      _errorReporter.error(1003, ConfigCatLogMessages.forceRefreshError, e, s);
      return Future.value(RefreshResult(
          false,
          "An error occurred during the refresh.",
          RefreshErrorCode.unexpectedError,
          e));
    }
  }

  /// Sets defaultUser value.
  /// If no user specified in the following calls {getValue}, {getAllValues}, {getValueDetails}, {getAllValueDetails}
  /// the default user value will be used.
  ///
  /// [user] The new default user.
  void setDefaultUser(ConfigCatUser? user) {
    _snapshotBuilder.defaultUser = user;
  }

  /// Sets the default user to null.
  void clearDefaultUser() {
    _snapshotBuilder.defaultUser = null;
  }

  /// Set the client to offline mode. HTTP calls are not allowed.
  void setOffline() {
    if (_configService != null && !_isClosed) {
      _configService!.offline();
    } else {
      _logger.warning(
          3201,
          ConfigCatLogMessages
              .getConfigServiceMethodHasNoEffectDueToClosedClient(
                  "setOffline"));
    }
  }

  /// Set the client to online mode. HTTP calls are allowed.
  void setOnline() {
    if (_configService != null && !_isClosed) {
      _configService?.online();
    } else {
      _logger.warning(
          3201,
          ConfigCatLogMessages
              .getConfigServiceMethodHasNoEffectDueToClosedClient("setOnline"));
    }
  }

  /// Get the client offline mode status.
  ///
  /// Return true if the client is in offline mode, otherwise false.
  bool isOffline() => _configService?.isOffline() ?? true;

  /// Get the client closed status.
  ///
  /// Return true if the client is closed, otherwise false.
  bool isClosed() => _isClosed;

  /// Waits for the client to reach the ready state, i.e. to complete initialization.
  ///
  /// Ready state is reached as soon as the initial sync with the external cache (if any) completes.
  /// If this does not produce up-to-date config data, and the client is online (i.e. HTTP requests are allowed),
  /// the first config fetch operation is also awaited in Auto Polling mode before ready state is reported.
  ///
  /// That is, reaching the ready state usually means the client is ready to evaluate feature flags and settings.
  /// However, please note that this is not guaranteed. In case of initialization failure or timeout,
  /// the internal cache may be empty or expired even after the ready state is reported. You can verify this by
  /// checking the return value.
  Future<ClientCacheState> waitForReady() async {
    final completer = Completer<ClientCacheState>();
    hooks.addOnClientReady((state) => completer.complete(state));
    return await completer.future;
  }

  /// Captures the SDK's internally cached config data.
  /// It does not attempt to update it by synchronizing with the external cache or by fetching
  /// the latest version from the ConfigCat CDN.
  ///
  /// Therefore, it is recommended to use snapshots in conjunction with the Auto Polling mode,
  /// where the SDK automatically updates the internal cache in the background.
  ///
  /// For other polling modes, you will need to manually initiate a cache
  /// update by invoking [ConfigCatClient.forceRefresh].
  ConfigCatClientSnapshot snapshot() {
    final inMemory = _configService?.inMemory ?? InMemoryResult.empty;
    return _snapshotBuilder.buildSnapshot(inMemory);
  }

  /// Closes the underlying resources.
  void close() {
    _isClosed = true;
    _closeResources();
    _instanceRepository.removeWhere((key, value) => value == this);
  }

  static bool _isValidKey(String sdkKey, bool isCustomBaseURL) {
    if (isCustomBaseURL &&
        sdkKey.length > sdkKeyProxyPrefix.length &&
        sdkKey.startsWith(sdkKeyProxyPrefix)) {
      return true;
    }
    List<String> splitSDKKey = sdkKey.split("/");
    //22/22 rules
    if (splitSDKKey.length == 2 &&
        splitSDKKey[0].length == sdkKeySectionLength &&
        splitSDKKey[1].length == sdkKeySectionLength) {
      return true;
    }
    //configcat-sdk-1/22/22 rules
    return splitSDKKey.length == 3 &&
        splitSDKKey[0] == sdkKeyPrefix &&
        splitSDKKey[1].length == sdkKeySectionLength &&
        splitSDKKey[2].length == sdkKeySectionLength;
  }

  void _closeResources() {
    _configService?.close();
    _logger.close();
    _hooks.clear();
  }

  Future<SettingResult> _getSettings() async {
    if (_override != null) {
      switch (_override!.behaviour) {
        case OverrideBehaviour.localOnly:
          final local = _override!.dataSource.getOverrides();
          return SettingResult(settings: local, fetchTime: distantPast);
        case OverrideBehaviour.localOverRemote:
          final remote =
              await _configService?.getSettings() ?? SettingResult.empty;
          final local = _override!.dataSource.getOverrides();
          return SettingResult(
              settings: Map<String, Setting>.of(remote.settings)..addAll(local),
              fetchTime: remote.fetchTime);
        case OverrideBehaviour.remoteOverLocal:
          final remote =
              await _configService?.getSettings() ?? SettingResult.empty;
          final local = _override!.dataSource.getOverrides();
          return SettingResult(
              settings: Map<String, Setting>.of(local)..addAll(remote.settings),
              fetchTime: remote.fetchTime);
      }
    }

    return await _configService?.getSettings() ?? SettingResult.empty;
  }
}
