import 'package:configcat_client/src/constants.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'data_governance.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';
import 'polling_mode.dart';
import 'configcat_client.dart';
import 'override/flag_overrides.dart';
import 'configcat_user.dart';
import 'json/rollout_rule.dart';
import 'json/percentage_rule.dart';

/// Additional information about flag evaluation.
class EvaluationDetails<T> {
  final String key;
  final String variationId;
  final ConfigCatUser? user;
  final bool isDefaultValue;
  final String? error;
  final T value;
  final DateTime fetchTime;
  final RolloutRule? matchedEvaluationRule;
  final PercentageRule? matchedEvaluationPercentageRule;

  EvaluationDetails(
      {required this.key,
      required this.variationId,
      required this.user,
      required this.isDefaultValue,
      required this.error,
      required this.value,
      required this.fetchTime,
      required this.matchedEvaluationRule,
      required this.matchedEvaluationPercentageRule});

  static EvaluationDetails<T> makeError<T>(
      String key, T defaultValue, String error, ConfigCatUser? user) {
    return EvaluationDetails<T>(
        key: key,
        variationId: "",
        user: user,
        isDefaultValue: true,
        error: error,
        value: defaultValue,
        fetchTime: distantPast,
        matchedEvaluationRule: null,
        matchedEvaluationPercentageRule: null);
  }
}

/// Events fired by [ConfigCatClient].
class Hooks {
  final List<Function(String, [dynamic error, StackTrace? stackTrace])>
      _onError = [];
  final List<Function(Map<String, Setting>)> _onConfigChanged = [];
  final List<Function(EvaluationDetails)> _onFlagEvaluated = [];
  final List<Function()> _onClientReady = [];

  Hooks(
      {Function(String, [dynamic error, StackTrace? stackTrace])? onError,
      Function(Map<String, Setting>)? onConfigChanged,
      Function(EvaluationDetails)? onFlagEvaluated,
      Function()? onClientReady}) {
    if (onError != null) _onError.add(onError);
    if (onConfigChanged != null) _onConfigChanged.add(onConfigChanged);
    if (onFlagEvaluated != null) _onFlagEvaluated.add(onFlagEvaluated);
    if (onClientReady != null) _onClientReady.add(onClientReady);
  }

  void addOnError(
      Function(String, [dynamic error, StackTrace? stackTrace]) onError) {
    _onError.add(onError);
  }

  void addOnConfigChanged(Function(Map<String, Setting>) onConfigChanged) {
    _onConfigChanged.add(onConfigChanged);
  }

  void addOnFlagEvaluated(Function(EvaluationDetails) onFlagEvaluated) {
    _onFlagEvaluated.add(onFlagEvaluated);
  }

  void addOnClientReady(Function() onClientReady) {
    _onClientReady.add(onClientReady);
  }

  void invokeError(String message, [dynamic error, StackTrace? stackTrace]) {
    for (final hook in _onError) {
      hook(message, error, stackTrace);
    }
  }

  void invokeConfigChanged(Map<String, Setting> entries) {
    for (final hook in _onConfigChanged) {
      hook(entries);
    }
  }

  void invokeFlagEvaluated(EvaluationDetails context) {
    for (final hook in _onFlagEvaluated) {
      hook(context);
    }
  }

  void invokeOnReady() {
    for (final hook in _onClientReady) {
      hook();
    }
  }

  void clear() {
    _onError.clear();
    _onConfigChanged.clear();
    _onFlagEvaluated.clear();
    _onClientReady.clear();
  }
}

/// Configuration options for [ConfigCatClient].
class ConfigCatOptions {
  final String baseUrl;
  final DataGovernance dataGovernance;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final PollingMode mode;
  final ConfigCatCache? cache;
  final ConfigCatLogger? logger;
  final FlagOverrides? override;
  final HttpClientAdapter? httpClientAdapter;
  final ConfigCatUser? defaultUser;
  final Hooks? hooks;

  const ConfigCatOptions({
    this.baseUrl = '',
    this.dataGovernance = DataGovernance.global,
    this.mode = PollingMode.defaultMode,
    this.cache,
    this.logger,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.httpClientAdapter,
    this.override,
    this.defaultUser,
    this.hooks,
  });

  static const ConfigCatOptions defaultOptions = ConfigCatOptions();
}
