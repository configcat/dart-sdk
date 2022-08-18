import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'data_governance.dart';
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
  final RolloutRule? rolloutRule;
  final RolloutPercentageItem? percentageRule;

  EvaluationContext(
      {required this.key,
      required this.variationId,
      required this.user,
      required this.value,
      required this.rolloutRule,
      required this.percentageRule});
}

/// Events fired by [ConfigCatClient].
class Hooks {
  final Function(String, [dynamic error, StackTrace? stackTrace])? onError;
  final Function()? onConfigChanged;
  final Function(EvaluationContext)? onFlagEvaluated;

  Hooks({this.onError, this.onConfigChanged, this.onFlagEvaluated});
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
