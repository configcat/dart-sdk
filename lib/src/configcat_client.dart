import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/refresh_result.dart';
import 'package:dio/dio.dart';

import 'error_reporter.dart';
import 'fetch/config_fetcher.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';
import 'override/behaviour.dart';
import 'override/flag_overrides.dart';
import 'rollout_evaluator.dart';
import 'configcat_cache.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';
import 'fetch/config_service.dart';

/// ConfigCat SDK client.
class ConfigCatClient {
  late final ConfigCatLogger _logger;
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
      throw ArgumentError('The SDK key cannot be empty.');
    }

    var client = _instanceRepository[sdkKey];
    if (client != null && options != ConfigCatOptions.defaultOptions) {
      client._logger.warning(
          "Client for '$sdkKey' is already created and will be reused; options passed are being ignored.");
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
                mode: options.mode,
                hooks: _hooks,
                fetcher: _fetcher,
                logger: _logger,
                cache: cache,
                errorReporter: _errorReporter);
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
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        final err =
            'Config JSON is not present. Returning defaultValue: \'$defaultValue\'.';
        _errorReporter.error(err);
        hooks.invokeFlagEvaluated(
            EvaluationDetails.makeError(key, defaultValue, err, user));
        return defaultValue;
      }
      final setting = result.settings[key];
      if (setting == null) {
        final err =
            'Value not found for key $key. Here are the available keys: ${result.settings.keys.join(', ')}';
        _errorReporter.error(err);
        hooks.invokeFlagEvaluated(
            EvaluationDetails.makeError(key, defaultValue, err, user));
        return defaultValue;
      }

      return _evaluate(key, setting, user ?? _defaultUser, result.fetchTime)
          .value;
    } catch (e, s) {
      final err =
          'Evaluating getValue(\'$key\') failed. Returning defaultValue: \'$defaultValue\'.';
      _errorReporter.error(err, e, s);
      hooks.invokeFlagEvaluated(
          EvaluationDetails.makeError(key, defaultValue, err, user));
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
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        final err =
            'Config JSON is not present. Returning defaultValue: \'$defaultValue\'.';
        _errorReporter.error(err);
        final details =
            EvaluationDetails.makeError(key, defaultValue, err, user);
        hooks.invokeFlagEvaluated(details);
        return details;
      }
      final setting = result.settings[key];
      if (setting == null) {
        final err =
            'Value not found for key $key. Here are the available keys: ${result.settings.keys.join(', ')}';
        _errorReporter.error(err);
        final details =
            EvaluationDetails.makeError(key, defaultValue, err, user);
        hooks.invokeFlagEvaluated(details);
        return details;
      }

      return _evaluate(key, setting, user ?? _defaultUser, result.fetchTime);
    } catch (e, s) {
      final err =
          'Evaluating getValue(\'$key\') failed. Returning defaultValue: \'$defaultValue\'.';
      _errorReporter.error(err, e, s);
      final details = EvaluationDetails.makeError(key, defaultValue, err, user);
      hooks.invokeFlagEvaluated(details);
      return details;
    }
  }

  /// Gets the Variation ID (analytics) of a feature flag or setting identified by the given [key].
  ///
  /// [key] is the identifier of the feature flag or setting.
  /// In case of any failure, [defaultVariationId] will be returned.
  /// [user] is the user object to identify the caller.
  Future<String> getVariationId({
    required String key,
    required String defaultVariationId,
    ConfigCatUser? user,
  }) async {
    try {
      final result = await _getSettings();
      if (result.isEmpty) {
        _errorReporter.error(
            'Config JSON is not present. Returning defaultVariationId: \'$defaultVariationId\'.');
        return defaultVariationId;
      }
      final setting = result.settings[key];
      if (setting == null) {
        _errorReporter.error(
            'Variation ID not found for key $key. Here are the available keys: ${result.settings.keys.join(', ')}');
        return defaultVariationId;
      }

      return _evaluate(key, setting, user ?? _defaultUser, result.fetchTime)
          .variationId;
    } catch (e, s) {
      _errorReporter.error(
          'Evaluating getVariationId(\'$key\') failed. Returning defaultVariationId: \'$defaultVariationId\'.',
          e,
          s);
      return defaultVariationId;
    }
  }

  /// Gets the Variation IDs (analytics) of all feature flags or settings.
  ///
  /// [user] is the user object to identify the caller.
  Future<List<String>> getAllVariationIds({ConfigCatUser? user}) async {
    try {
      final settingsResult = await _getSettings();
      if (settingsResult.isEmpty) {
        return [];
      }

      final result = List<String>.empty(growable: true);
      settingsResult.settings.forEach((key, value) {
        result.add(_evaluate(
                key, value, user ?? _defaultUser, settingsResult.fetchTime)
            .variationId);
      });

      return result;
    } catch (e, s) {
      _errorReporter.error(
          'An error occurred during getting all the variation ids. Returning empty list.',
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
        return [];
      }

      return result.settings.keys.toList();
    } catch (e, s) {
      _errorReporter.error(
          'An error occurred during getting all the setting keys. Returning empty list.',
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
        return {};
      }

      final result = <String, dynamic>{};
      settingsResult.settings.forEach((key, value) {
        result[key] = _evaluate(
                key, value, user ?? _defaultUser, settingsResult.fetchTime)
            .value;
      });

      return result;
    } catch (e, s) {
      _errorReporter.error(
          'An error occurred during getting all values. Returning empty map.',
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
        _errorReporter.error('Config JSON is not present. Returning null.');
        return null;
      }

      for (final entry in result.settings.entries) {
        if (entry.value.variationId == variationId) {
          return MapEntry(entry.key, entry.value.value);
        }

        for (final rolloutRule in entry.value.rolloutRules) {
          if (rolloutRule.variationId == variationId) {
            return MapEntry(entry.key, rolloutRule.value);
          }
        }

        for (final percentageRule in entry.value.percentageItems) {
          if (percentageRule.variationId == variationId) {
            return MapEntry(entry.key, percentageRule.value);
          }
        }
      }

      return null;
    } catch (e, s) {
      _errorReporter.error(
          'Could not find the setting for the given variation ID: \'$variationId\'',
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
            "The SDK uses the LOCAL_ONLY flag override behavior which prevents making HTTP requests."));
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

  EvaluationDetails<T> _evaluate<T>(
      String key, Setting setting, ConfigCatUser? user, DateTime fetchTime) {
    final eval = _rolloutEvaluator.evaluate<T>(setting, key, user);
    final details = EvaluationDetails<T>(
        key: key,
        variationId: eval.variationId,
        user: user,
        isDefaultValue: false,
        error: null,
        value: eval.value,
        fetchTime: fetchTime,
        matchedEvaluationRule: eval.matchedEvaluationRule,
        matchedEvaluationPercentageRule: eval.matchedEvaluationPercentageRule);

    _hooks.invokeFlagEvaluated(details);
    return details;
  }
}
