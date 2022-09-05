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
      client._logger.warning("message");
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

    _rolloutEvaluator = RolloutEvaluator(_logger, _hooks);
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        _errorReporter.error(
            'Config JSON is not present. Returning defaultValue: $defaultValue.');
        return defaultValue;
      }
      final setting = settings[key];
      if (setting == null) {
        _errorReporter.error(
            'Value not found for key $key. Here are the available keys: ${settings.keys.join(', ')}');
        return defaultValue;
      }

      return _rolloutEvaluator.evaluate(setting, key, user ?? _defaultUser).key;
    } catch (e, s) {
      _errorReporter.error(
          'Evaluating getValue(\'$key\') failed. Returning defaultValue: $defaultValue.',
          e,
          s);
      return defaultValue;
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        _errorReporter.error(
            'Config JSON is not present. Returning defaultVariationId: $defaultVariationId.');
        return defaultVariationId;
      }
      final setting = settings[key];
      if (setting == null) {
        _errorReporter.error(
            'Variation ID not found for key $key. Here are the available keys: ${settings.keys.join(', ')}');
        return defaultVariationId;
      }

      return _rolloutEvaluator
          .evaluate(setting, key, user ?? _defaultUser)
          .value;
    } catch (e, s) {
      _errorReporter.error(
          'Evaluating getVariationId(\'$key\') failed. Returning defaultVariationId: $defaultVariationId.',
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        return [];
      }

      final result = List<String>.empty(growable: true);
      settings.forEach((key, value) {
        result.add(
            _rolloutEvaluator.evaluate(value, key, user ?? _defaultUser).value);
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        return [];
      }

      return settings.keys.toList();
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        return {};
      }

      final result = <String, dynamic>{};
      settings.forEach((key, value) {
        result[key] =
            _rolloutEvaluator.evaluate(value, key, user ?? _defaultUser).key;
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
      final settings = await _getSettings();
      if (settings.isEmpty) {
        _errorReporter.error('Config JSON is not present. Returning null.');
        return null;
      }

      for (final entry in settings.entries) {
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
          'Could not find the setting for the given variation ID: $variationId',
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
  Future<void> forceRefresh() {
    return _configService?.refresh() ?? Future.value(null);
  }

  /// Sets the default user.
  void setDefaultUser(ConfigCatUser user) => _defaultUser = user;

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

  Future<Map<String, Setting>> _getSettings() async {
    if (_override != null) {
      switch (_override!.behaviour) {
        case OverrideBehaviour.localOnly:
          final local = await _override!.dataSource.getOverrides();
          return local;
        case OverrideBehaviour.localOverRemote:
          final remote = await _configService?.getSettings() ?? {};
          final local = await _override!.dataSource.getOverrides();
          return Map<String, Setting>.of(remote)..addAll(local);
        case OverrideBehaviour.remoteOverLocal:
          final remote = await _configService?.getSettings() ?? {};
          final local = await _override!.dataSource.getOverrides();
          return Map<String, Setting>.of(local)..addAll(remote);
      }
    }

    return await _configService?.getSettings() ?? {};
  }
}
