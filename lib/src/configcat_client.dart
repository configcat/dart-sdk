import 'package:configcat_client/src/flag_overrides.dart';
import 'package:dio/dio.dart';

import 'config_fetcher.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';
import 'json/config_json_cache.dart';
import 'refresh_policy/auto_polling_policy.dart';
import 'refresh_policy/lazy_polling_policy.dart';
import 'refresh_policy/manual_polling_policy.dart';
import 'refresh_policy/refresh_policy.dart';
import 'rollout_evaluator.dart';
import 'configcat_cache.dart';
import 'refresh_policy/polling_mode.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';

class ConfigCatClient {
  late final ConfigCatLogger _logger;
  late final RefreshPolicy _refreshPolicy;
  late final RolloutEvaluator _rolloutEvaluator;
  late final Fetcher _fetcher;
  late final FlagOverride? _override;
  static final Map<String, ConfigCatClient> _instanceRepository = Map();

  /// Creates a new or gets an already existing [ConfigCatClient] for the given [sdkKey].
  factory ConfigCatClient.get(String sdkKey,
      {ConfigCatOptions options = const ConfigCatOptions()}) {
    if (sdkKey.isEmpty) {
      throw ArgumentError('The SDK key cannot be empty.');
    }

    var client = _instanceRepository[sdkKey];
    if (client == null) {
      client = _instanceRepository[sdkKey] = ConfigCatClient._(sdkKey, options: options);
    }

    return client;
  }

  /// Closes all [ConfigCatClient] instances.
  static void close() {
    for (final client in _instanceRepository.entries) {
      client.value._close();
    }
    _instanceRepository.clear();
  }

  ConfigCatClient._(String sdkKey,
      {ConfigCatOptions options = const ConfigCatOptions()}) {
    this._logger = options.logger ?? ConfigCatLogger();
    this._override = options.override;

    final mode = options.mode ?? PollingMode.autoPoll();
    final configJsonCache = ConfigJsonCache(_logger);

    this._rolloutEvaluator = RolloutEvaluator(_logger);
    this._fetcher = ConfigFetcher(
        _logger, sdkKey, mode.getPollingIdentifier(), configJsonCache, options);
    this._refreshPolicy = this._override != null &&
            this._override!.behaviour == OverrideBehaviour.localOnly
        ? NullRefreshPolicy()
        : this._produceRefreshPolicy(
            mode,
            options.cache ?? InMemoryConfigCatCache(),
            this._fetcher,
            _logger,
            configJsonCache,
            sdkKey);
  }

  /// Gets the value of a feature flag or setting as [T] identified by the given [key].
  ///
  /// [key] is the identifier of the feature flag or setting.
  /// In case of any failure, [defaultValue] will be returned.
  /// [user] is the user object to identify the caller.
  Future<T> getValue<T>(String key, T defaultValue,
      {ConfigCatUser? user = null}) async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        this._logger.error(
            'Config JSON is not present. Returning defaultValue: $defaultValue.');
        return defaultValue;
      }
      final setting = settings[key];
      if (setting == null) {
        this._logger.error(
            'Value not found for key $key. Here are the available keys: ${settings.keys.join(', ')}');
        return defaultValue;
      }

      return this._rolloutEvaluator.evaluate(setting, key, user).key;
    } catch (e, s) {
      this._logger.error(
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
  Future<String> getVariationId(String key, String defaultVariationId,
      {ConfigCatUser? user = null}) async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        this._logger.error(
            'Config JSON is not present. Returning defaultVariationId: $defaultVariationId.');
        return defaultVariationId;
      }
      final setting = settings[key];
      if (setting == null) {
        this._logger.error(
            'Variation ID not found for key $key. Here are the available keys: ${settings.keys.join(', ')}');
        return defaultVariationId;
      }

      return this._rolloutEvaluator.evaluate(setting, key, user).value;
    } catch (e, s) {
      this._logger.error(
          'Evaluating getVariationId(\'$key\') failed. Returning defaultVariationId: $defaultVariationId.',
          e,
          s);
      return defaultVariationId;
    }
  }

  /// Gets the Variation IDs (analytics) of all feature flags or settings.
  ///
  /// [user] is the user object to identify the caller.
  Future<List<String>> getAllVariationIds({ConfigCatUser? user = null}) async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        return [];
      }

      final result = List<String>.empty(growable: true);
      settings.forEach((key, value) {
        result.add(this._rolloutEvaluator.evaluate(value, key, user).value);
      });

      return result;
    } catch (e, s) {
      this._logger.error(
          'An error occurred during getting all the variation ids. Returning empty list.',
          e,
          s);
      return [];
    }
  }

  /// Gets a collection of all setting keys.
  Future<List<String>> getAllKeys() async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        return [];
      }

      return settings.keys.toList();
    } catch (e, s) {
      this._logger.error(
          'An error occurred during getting all the setting keys. Returning empty list.',
          e,
          s);
      return [];
    }
  }

  /// Gets the values of all feature flags or settings.
  ///
  /// [user] is the user object to identify the caller.
  Future<Map<String, dynamic>> getAllValues(
      {ConfigCatUser? user = null}) async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        return {};
      }

      final result = Map<String, dynamic>();
      settings.forEach((key, value) {
        result[key] = this._rolloutEvaluator.evaluate(value, key, user).key;
      });

      return result;
    } catch (e, s) {
      this._logger.error(
          'An error occurred during getting all values. Returning empty map.',
          e,
          s);
      return {};
    }
  }

  /// Gets the key of a setting and its value identified by the given [variationId] (analytics).
  Future<MapEntry<String, T>?> getKeyAndValue<T>(String variationId) async {
    try {
      final settings = await this._getSettings();
      if (settings.isEmpty) {
        this._logger.error('Config JSON is not present. Returning null.');
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
      this._logger.error(
          'Could not find the setting for the given variation ID: $variationId',
          e,
          s);
      return null;
    }
  }

  /// Gets the underlying [Dio] client.
  Dio get client {
    return this._fetcher.client;
  }

  /// Initiates a force refresh on the cached configuration.
  Future<void> forceRefresh() {
    return this._refreshPolicy.refresh();
  }

  /// Closes the underlying resources.
  void _close() {
    this._refreshPolicy.close();
    this._logger.close();
  }

  RefreshPolicy _produceRefreshPolicy(
      PollingMode mode,
      ConfigCatCache cache,
      Fetcher fetcher,
      ConfigCatLogger logger,
      ConfigJsonCache configJsonCache,
      String sdkKey) {
    if (mode is AutoPollingMode) {
      return new AutoPollingPolicy(
          mode, cache, fetcher, logger, configJsonCache, sdkKey);
    } else if (mode is LazyLoadingMode) {
      return new LazyLoadingPolicy(
          mode, cache, fetcher, logger, configJsonCache, sdkKey);
    } else if (mode is ManualPollingMode) {
      return new ManualPollingPolicy(
          cache, fetcher, logger, configJsonCache, sdkKey);
    } else {
      throw new ArgumentError('The polling mode option is invalid.');
    }
  }

  Future<Map<String, Setting>> _getSettings() async {
    if (this._override != null) {
      switch (this._override!.behaviour) {
        case OverrideBehaviour.localOnly:
          return this._override!.overrides.map(
              (key, value) => MapEntry(key, Setting(value, 0, [], [], '')));
        case OverrideBehaviour.localOverRemote:
          final remote = await this._refreshPolicy.getConfiguration();
          final local = this._override!.overrides;
          return Map<String, Setting>.of(remote.entries)
            ..addAll(local.map(
                (key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
        case OverrideBehaviour.remoteOverLocal:
          final remote = await this._refreshPolicy.getConfiguration();
          final local = this._override!.overrides;
          return local
              .map((key, value) => MapEntry(key, Setting(value, 0, [], [], '')))
            ..addAll(remote.entries);
      }
    }

    final config = await this._refreshPolicy.getConfiguration();
    return config.entries;
  }
}
