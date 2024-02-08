import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/refresh_result.dart';
import 'package:configcat_client/src/json/setting_type.dart';
import 'package:configcat_client/src/json/settings_value.dart';
import 'package:configcat_client/src/log/logger.dart';
import 'package:configcat_client/src/utils.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';
import 'error_reporter.dart';
import 'evaluate_logger.dart';
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
  late ConfigCatUser? _defaultUser;
  static final Map<String, ConfigCatClient> _instanceRepository = {};

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
      client._logger.warning(3000,
          "There is an existing client instance for the specified SDK Key. No new client instance will be created and the specified options are ignored. Returning the existing client instance. SDK Key: '$sdkKey'.");
    }
    client ??= _instanceRepository[sdkKey] = ConfigCatClient._(sdkKey, options);
    return client;
  }

  /// Closes all [ConfigCatClient] instances.
  static closeAll() {
    for (final client in _instanceRepository.entries) {
      client.value._closeResources();
    }
    _instanceRepository.clear();
  }

  ConfigCatClient._(String sdkKey, ConfigCatOptions options) {
    _logger = options.logger ?? ConfigCatLogger();
    _logLevel = _logger.getLogLevel();
    _override = options.override;
    _defaultUser = options.defaultUser;
    _hooks = options.hooks ?? Hooks();

    final cache = options.cache ?? NullConfigCatCache();

    _rolloutEvaluator = RolloutEvaluator(_logger);
    _errorReporter = ErrorReporter(_logger, _hooks);
    _fetcher = ConfigFetcher(
        logger: _logger,
        sdkKey: sdkKey,
        options: options,
        errorReporter: _errorReporter);
    _configService =
        _override != null && _override!.behaviour == OverrideBehaviour.localOnly
            ? null
            : ConfigService(
                sdkKey: sdkKey,
                mode: options.pollingMode,
                hooks: _hooks,
                fetcher: _fetcher,
                logger: _logger,
                cache: cache,
                errorReporter: _errorReporter,
                offline: options.offline);
  }

  /// Gets the value of a feature flag or setting as [T] identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only [String], [int], [double], [bool] or [dynamic] types are supported.
  Future<T> getValue<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    _validateReturnType<T>();

    final evalUser = user ?? _defaultUser;
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        final err =
            'Config JSON is not present when evaluating setting \'$key\'. Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'.';
        _errorReporter.error(1000, err);
        hooks.invokeFlagEvaluated(
            EvaluationDetails.makeError(key, defaultValue, err, evalUser));
        return defaultValue;
      }
      final setting = result.settings[key];
      if (setting == null) {
        final err =
            'Failed to evaluate setting \'$key\' (the key was not found in config JSON). Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'. Available keys: [${result.settings.keys.map((e) => '\'$e\'').join(', ')}].';
        _errorReporter.error(1001, err);
        hooks.invokeFlagEvaluated(
            EvaluationDetails.makeError(key, defaultValue, err, evalUser));
        return defaultValue;
      }

      return _evaluate<T>(
              key, setting, evalUser, result.fetchTime, result.settings)
          .value;
    } catch (e, s) {
      final err =
          'Error occurred in the `getValue` method while evaluating setting \'$key\'. Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'.';
      _errorReporter.error(1002, err, e, s);
      hooks.invokeFlagEvaluated(
          EvaluationDetails.makeError(key, defaultValue, err, evalUser));
      return defaultValue;
    }
  }

  /// Gets the value and evaluation details of a feature flag or setting identified by the given [key].
  ///
  /// [key] the identifier of the feature flag or setting.
  /// [defaultValue] in case of any failure, this value will be returned.
  /// [user] the user object.
  /// [T] the type of the desired feature flag or setting. Only [String], [int], [double], [bool] or [dynamic] types are supported.
  Future<EvaluationDetails<T>> getValueDetails<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
    if (key.isEmpty) {
      throw ArgumentError("'key' cannot be empty.");
    }
    _validateReturnType<T>();

    final evalUser = user ?? _defaultUser;
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        final err =
            'Config JSON is not present when evaluating setting \'$key\'. Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'.';
        _errorReporter.error(1000, err);
        final details =
            EvaluationDetails.makeError(key, defaultValue, err, evalUser);
        hooks.invokeFlagEvaluated(details);
        return details;
      }
      final setting = result.settings[key];
      if (setting == null) {
        final err =
            'Failed to evaluate setting \'$key\' (the key was not found in config JSON). Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'. Available keys: [${result.settings.keys.map((e) => '\'$e\'').join(', ')}].';
        _errorReporter.error(1001, err);
        final details =
            EvaluationDetails.makeError(key, defaultValue, err, evalUser);
        hooks.invokeFlagEvaluated(details);
        return details;
      }

      return _evaluate<T>(
          key, setting, evalUser, result.fetchTime, result.settings);
    } catch (e, s) {
      final err =
          'Error occurred in the `getValueDetails` method while evaluating setting \'$key\'. Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'.';
      _errorReporter.error(1002, err, e, s);
      final details = EvaluationDetails.makeError(
          key, defaultValue, e.toString(), evalUser);
      hooks.invokeFlagEvaluated(details);
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
    final evalUser = user ?? _defaultUser;
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000, 'Config JSON is not present. Returning empty list.');
        return [];
      }
      final detailsResult = List<EvaluationDetails>.empty(growable: true);
      result.settings.forEach((key, value) {
        detailsResult.add(
            _evaluate(key, value, evalUser, result.fetchTime, result.settings));
      });

      return detailsResult;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          'Error occurred in the `getAllValueDetails` method. Returning empty list.',
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
            1000, 'Config JSON is not present. Returning empty list.');
        return [];
      }

      return result.settings.keys.toList();
    } catch (e, s) {
      _errorReporter.error(
          1002,
          'Error occurred in the `getAllKeys` method. Returning empty list.',
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
            1000, 'Config JSON is not present. Returning empty map.');
        return {};
      }

      final result = <String, dynamic>{};
      settingsResult.settings.forEach((key, value) {
        result[key] = _evaluate(key, value, user ?? _defaultUser,
                settingsResult.fetchTime, settingsResult.settings)
            .value;
      });

      return result;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          'Error occurred in the `getAllValues` method. Returning empty map.',
          e,
          s);
      return {};
    }
  }

  /// Gets the key of a setting and its value identified by the given [variationId] (analytics).
  /// [variationId] the Variation ID.
  /// [T] the type of the desired feature flag or setting. Only [String], [int], [double], [bool] or [dynamic] types are supported.
  Future<MapEntry<String, T>?> getKeyAndValue<T>(
      {required String variationId}) async {
    _validateReturnType<T>();

    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000, 'Config JSON is not present. Returning null.');
        return null;
      }

      for (final entry in result.settings.entries) {
        if (entry.value.variationId == variationId) {
          return MapEntry(
              entry.key,
              _parseSettingValue<T>(
                  entry.value.settingsValue, entry.value.type));
        }

        for (final targetingRule in entry.value.targetingRules) {
          if (targetingRule.servedValue != null) {
            if (targetingRule.servedValue?.variationId == variationId) {
              return MapEntry(
                  entry.key,
                  _parseSettingValue<T>(
                      targetingRule.servedValue!.settingsValue,
                      entry.value.type));
            }
          } else {
            var targetRulePercentageOptions = targetingRule.percentageOptions;
            if (targetRulePercentageOptions != null) {
              for (final percentageOption in targetRulePercentageOptions) {
                if (percentageOption.variationId == variationId) {
                  return MapEntry(
                      entry.key,
                      _parseSettingValue<T>(
                          percentageOption.settingsValue, entry.value.type));
                }
              }
            }
          }
        }

        for (final percentageOption in entry.value.percentageOptions) {
          if (percentageOption.variationId == variationId) {
            return MapEntry(
                entry.key,
                _parseSettingValue<T>(
                    percentageOption.settingsValue, entry.value.type));
          }
        }
      }

      _errorReporter.error(2011,
          'Could not find the setting for the specified variation ID: \'$variationId\'.');
      return null;
    } catch (e, s) {
      _errorReporter.error(
          1002,
          'Error occurred in the `getKeyAndValue` method. Returning null.',
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

  /// Initiates a force refresh on the cached configuration.
  Future<RefreshResult> forceRefresh() {
    return _configService?.refresh() ??
        Future.value(RefreshResult(false,
            'The SDK uses the LOCAL_ONLY flag override behavior which prevents making HTTP requests.'));
  }

  /// Sets defaultUser value.
  /// If no user specified in the following calls {getValue}, {getAllValues}, {getValueDetails}, {getAllValueDetails}
  /// the default user value will be used.
  ///
  /// [user] The new default user.
  void setDefaultUser(ConfigCatUser? user) => _defaultUser = user;

  /// Sets the default user to null.
  void clearDefaultUser() => _defaultUser = null;

  /// Set the client to offline mode. HTTP calls are not allowed.
  void setOffline() => _configService?.offline();

  /// Set the client to online mode. HTTP calls are allowed.
  void setOnline() => _configService?.online();

  /// Get the client offline mode status.
  ///
  /// Return true if the client is in offline mode, otherwise false.
  bool isOffline() => _configService?.isOffline() ?? true;

  /// Closes the underlying resources.
  void close() {
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
          final local = await _override!.dataSource.getOverrides();
          return SettingResult(settings: local, fetchTime: distantPast);
        case OverrideBehaviour.localOverRemote:
          final remote =
              await _configService?.getSettings() ?? SettingResult.empty;
          final local = await _override!.dataSource.getOverrides();
          return SettingResult(
              settings: Map<String, Setting>.of(remote.settings)..addAll(local),
              fetchTime: remote.fetchTime);
        case OverrideBehaviour.remoteOverLocal:
          final remote =
              await _configService?.getSettings() ?? SettingResult.empty;
          final local = await _override!.dataSource.getOverrides();
          return SettingResult(
              settings: Map<String, Setting>.of(local)..addAll(remote.settings),
              fetchTime: remote.fetchTime);
      }
    }

    return await _configService?.getSettings() ?? SettingResult.empty;
  }

  EvaluationDetails<T> _evaluate<T>(String key, Setting setting,
      ConfigCatUser? user, DateTime fetchTime, Map<String, Setting> settings) {
    EvaluateLogger? evaluateLogger;
    if (_logLevel.index <= LogLevel.info.index) {
      evaluateLogger = EvaluateLogger();
    }
    final eval = _rolloutEvaluator.evaluate(
        setting, key, user, settings, evaluateLogger);
    final details = EvaluationDetails<T>(
        key: key,
        variationId: eval.variationId,
        user: user,
        isDefaultValue: false,
        error: null,
        value: _parseSettingValue<T>(eval.value, setting.type),
        fetchTime: fetchTime,
        matchedTargetingRule: eval.matchedTargetingRule,
        matchedPercentageOption: eval.matchedPercentageOption);

    _hooks.invokeFlagEvaluated(details);
    return details;
  }

  T _parseSettingValue<T>(SettingsValue settingsValue, int settingType) {
    SettingType settingTypeEnum = SettingType.tryFrom(settingType) ??
        (() => throw ArgumentError("Setting type is invalid."))();

    bool allowsAnyType =
        T == Object || Utils.typesEqual<T, Object?>() || T == dynamic;

    if ((T == bool || Utils.typesEqual<T, bool?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.boolean &&
        settingsValue.booleanValue != null) {
      return settingsValue.booleanValue as T;
    }
    if ((T == String || Utils.typesEqual<T, String?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.string &&
        settingsValue.stringValue != null) {
      return settingsValue.stringValue as T;
    }
    if ((T == int || Utils.typesEqual<T, int?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.int &&
        settingsValue.intValue != null) {
      return settingsValue.intValue as T;
    }
    if ((T == double || Utils.typesEqual<T, double?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.double &&
        settingsValue.doubleValue != null) {
      return settingsValue.doubleValue as T;
    }

    throw ArgumentError(
        "The type of a setting must match the type of the specified default value. Setting's type was ${settingTypeEnum.name} but the default value's type was $T. Please use a default value which corresponds to the setting type ${settingTypeEnum.name}. Learn more: https://configcat.com/docs/sdk-reference/dotnet/#setting-type-mapping");
  }

  void _validateReturnType<T>() {
    if (T != bool &&
        T != String &&
        T != int &&
        T != double &&
        T != Object &&
        !Utils.typesEqual<T, bool?>() &&
        !Utils.typesEqual<T, String?>() &&
        !Utils.typesEqual<T, int?>() &&
        !Utils.typesEqual<T, double?>() &&
        !Utils.typesEqual<T, Object?>() &&
        T != dynamic) {
      throw ArgumentError(
          "Only the following types are supported: $String, $bool, $int, $double, $Object (both nullable and non-nullable) and $dynamic.");
    }
  }
}
