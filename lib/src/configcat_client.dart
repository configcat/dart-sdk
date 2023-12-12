import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/refresh_result.dart';
import 'package:configcat_client/src/json/settings_value.dart';
import 'package:configcat_client/src/log/logger.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
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
  static const _settingTypes = [
    'Boolean',
    'String',
    'Integer',
    'Double',
  ];

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
    if (!_isValidKey(sdkKey, options.isBaseUrlCustom())) {
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
  /// [key] is the identifier of the feature flag or setting.
  /// In case of any failure, [defaultValue] will be returned.
  /// [user] is the user object to identify the caller.
  Future<T> getValue<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
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

      return _evaluate(
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
  /// [key] is the identifier of the feature flag or setting.
  /// [user] is the user object to identify the caller.
  Future<EvaluationDetails<T>> getValueDetails<T>({
    required String key,
    required T defaultValue,
    ConfigCatUser? user,
  }) async {
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

      return _evaluate(
          key, setting, evalUser, result.fetchTime, result.settings);
    } catch (e, s) {
      final err =
          'Error occurred in the `getValueDetails` method while evaluating setting \'$key\'. Returning the `defaultValue` parameter that you specified in your application: \'$defaultValue\'.';
      _errorReporter.error(1002, err, e, s);
      final details =
          EvaluationDetails.makeError(key, defaultValue, err, evalUser);
      hooks.invokeFlagEvaluated(details);
      return details;
    }
  }

  /// Gets the values along with evaluation details of all feature flags and settings.
  ///
  /// [user] is the user object to identify the caller.
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
  /// [user] is the user object to identify the caller.
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
  Future<MapEntry<String, T>?> getKeyAndValue<T>(
      {required String variationId}) async {
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            1000, 'Config JSON is not present. Returning null.');
        return null;
      }

      for (final entry in result.settings.entries) {
        if (entry.value.variationId == variationId) {
          return MapEntry(entry.key,
              _parseSettingValue(entry.value.settingsValue, entry.value.type));
        }

        for (final targetingRule in entry.value.targetingRules) {
          if (targetingRule.servedValue != null &&
              targetingRule.servedValue?.variationId == variationId) {
            return MapEntry(
                entry.key,
                _parseSettingValue(targetingRule.servedValue!.settingsValue,
                    entry.value.type));
          }
        }

        for (final percentageOption in entry.value.percentageOptions) {
          if (percentageOption.variationId == variationId) {
            return MapEntry(
                entry.key,
                _parseSettingValue(
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

  /// Sets the default user.
  void setDefaultUser(ConfigCatUser? user) => _defaultUser = user;

  /// Sets the default user to null.
  void clearDefaultUser() => _defaultUser = null;

  /// Configures the SDK to not initiate HTTP requests.
  void setOffline() => _configService?.offline();

  /// Configures the SDK to allow HTTP requests.
  void setOnline() => _configService?.online();

  /// True when the SDK is configured not to initiate HTTP requests, otherwise false.
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
    final eval = _rolloutEvaluator.evaluate(
        setting, key, user, settings, EvaluateLogger(_logLevel));
    final details = EvaluationDetails<T>(
        key: key,
        variationId: eval.variationId,
        user: user,
        isDefaultValue: false,
        error: null,
        value: _parseSettingValue(eval.value, setting.type),
        fetchTime: fetchTime,
        matchedTargetingRule: eval.matchedTargetingRule,
        matchedPercentageOption: eval.matchedPercentageOption);

    _hooks.invokeFlagEvaluated(details);
    return details;
  }

  T _parseSettingValue<T>(SettingsValue settingsValue, int settingType) {
    if (!(T is bool || T is String || T is int || T is double)) {
      throw ArgumentError(
          "Only String, Integer, Double or Boolean types are supported.");
    }

    if (T is bool && settingType == 0 && settingsValue.booleanValue != null) {
      return settingsValue.booleanValue as T;
    }
    if (T is String && settingType == 1 && settingsValue.stringValue != null) {
      return settingsValue.stringValue as T;
    }
    if (T is int && settingType == 2 && settingsValue.intValue != null) {
      return settingsValue.intValue as T;
    }
    if (T is double && settingType == 3 && settingsValue.doubleValue != null) {
      return settingsValue.doubleValue as T;
    }
    throw ArgumentError(
        "The type of a setting must match the type of the setting's default value. Setting's type was {${_settingTypes[settingType]}} but the default value's type was {${T.runtimeType}}. Please use a default value which corresponds to the setting type {${_settingTypes[settingType]}}. Learn more: https://configcat.com/docs/sdk-reference/dotnet/#setting-type-mapping");
  }
}
