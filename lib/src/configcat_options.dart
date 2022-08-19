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
/// Used in [Hooks.onFlagEvaluated] event.
class EvaluationContext {
  final String key;
  final String variationId;
  final ConfigCatUser? user;
  final dynamic value;
  final RolloutRule? flagEvaluationRule;
  final RolloutPercentageItem? flagEvaluationPercentageRule;

  EvaluationContext(
      {required this.key,
      required this.variationId,
      required this.user,
      required this.value,
      required this.flagEvaluationRule,
      required this.flagEvaluationPercentageRule});
}

/// Events fired by [ConfigCatClient].
class Hooks {
  final List<Function(String, [dynamic error, StackTrace? stackTrace])>
      _onError = [];
  final List<Function(Map<String, Setting>)> _onConfigChanged = [];
  final List<Function(EvaluationContext)> _onFlagEvaluated = [];

  Hooks(
      {Function(String, [dynamic error, StackTrace? stackTrace])? onError,
      Function(Map<String, Setting>)? onConfigChanged,
      Function(EvaluationContext)? onFlagEvaluated}) {
    if (onError != null) _onError.add(onError);
    if (onConfigChanged != null) _onConfigChanged.add(onConfigChanged);
    if (onFlagEvaluated != null) _onFlagEvaluated.add(onFlagEvaluated);
  }

  void addOnError(
      Function(String, [dynamic error, StackTrace? stackTrace]) onError) {
    _onError.add(onError);
  }

  void addOnConfigChanged(Function(Map<String, Setting>) onConfigChanged) {
    _onConfigChanged.add(onConfigChanged);
  }

  void addOnFlagEvaluated(Function(EvaluationContext) onFlagEvaluated) {
    _onFlagEvaluated.add(onFlagEvaluated);
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

  void invokeFlagEvaluated(EvaluationContext context) {
    for (final hook in _onFlagEvaluated) {
      hook(context);
    }
  }

  void clear() {
    _onError.clear();
    _onConfigChanged.clear();
    _onFlagEvaluated.clear();
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
}
