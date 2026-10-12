import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:configcat_client/src/json/percentage_option.dart';
import 'package:configcat_client/src/json/targeting_rule.dart';
import 'package:configcat_client/src/snapshot.dart';
import 'package:configcat_client/src/snapshot_builder.dart';
import 'package:dio/dio.dart';

import 'client_cache_state.dart';
import 'configcat_cache.dart';
import 'data_governance.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';
import 'polling_mode.dart';
import 'configcat_client.dart';
import 'override/flag_overrides.dart';
import 'configcat_user.dart';

/// Specifies the possible evaluation error codes.
enum EvaluationErrorCode {
  /// An unexpected error occurred during the evaluation.
  unexpectedError(-1),

  /// No error occurred (the evaluation was successful).
  none(0),

  /// The evaluation failed because of an error in the config model.
  invalidConfigModel(1),

  /// The evaluation failed because of a type mismatch between the evaluated
  /// setting value and the specified default value.
  settingValueTypeMismatch(2),

  /// The evaluation failed because the config JSON was not available locally.
  configJsonNotAvailable(1000),

  /// The evaluation failed because the key of the evaluated setting was not found in
  /// the config JSON.
  settingKeyMissing(1001);

  const EvaluationErrorCode(this.value);
  final int value;
}

/// Additional information about flag evaluation.
class EvaluationDetails<T> {
  final String key;
  final String? variationId;
  final ConfigCatUser? user;
  final bool isDefaultValue;
  final String? error;
  final EvaluationErrorCode errorCode;
  final T value;
  final DateTime fetchTime;
  final TargetingRule? matchedTargetingRule;
  final PercentageOption? matchedPercentageOption;

  EvaluationDetails(
      {required this.key,
      required this.variationId,
      required this.user,
      required this.isDefaultValue,
      required this.error,
      required this.errorCode,
      required this.value,
      required this.fetchTime,
      required this.matchedTargetingRule,
      required this.matchedPercentageOption});

  static EvaluationDetails<T> makeError<T>(String key, T defaultValue,
      String error, EvaluationErrorCode errorCode, ConfigCatUser? user) {
    return EvaluationDetails<T>(
        key: key,
        variationId: "",
        user: user,
        isDefaultValue: true,
        error: error,
        errorCode: errorCode,
        value: defaultValue,
        fetchTime: distantPast,
        matchedTargetingRule: null,
        matchedPercentageOption: null);
  }
}

/// Events fired by [ConfigCatClient].
class Hooks {
  final List<Function(String, [dynamic error, StackTrace? stackTrace])>
      _onError = [];
  final List<Function(Map<String, Setting>, ConfigCatClientSnapshot)>
      _onConfigChanged = [];
  final List<Function(EvaluationDetails)> _onFlagEvaluated = [];
  final List<Function(ClientCacheState)> _onClientReady = [];
  final List<Function(ConfigCatClientSnapshot)> _onClientReadyWithSnapshot = [];
  ClientCacheState? _clientCacheState;

  Hooks(
      {Function(String, [dynamic error, StackTrace? stackTrace])? onError,
      Function(Map<String, Setting>, ConfigCatClientSnapshot)? onConfigChanged,
      Function(EvaluationDetails)? onFlagEvaluated,
      Function(ClientCacheState)? onClientReady,
      Function(ConfigCatClientSnapshot)? onClientReadyWithSnapshot}) {
    if (onError != null) _onError.add(onError);
    if (onConfigChanged != null) _onConfigChanged.add(onConfigChanged);
    if (onFlagEvaluated != null) _onFlagEvaluated.add(onFlagEvaluated);
    if (onClientReady != null) _onClientReady.add(onClientReady);
    if (onClientReadyWithSnapshot != null)
      _onClientReadyWithSnapshot.add(onClientReadyWithSnapshot);
  }

  void addOnError(
      Function(String, [dynamic error, StackTrace? stackTrace]) onError) {
    _onError.add(onError);
  }

  void addOnConfigChanged(
      Function(Map<String, Setting>, ConfigCatClientSnapshot) onConfigChanged) {
    _onConfigChanged.add(onConfigChanged);
  }

  void addOnFlagEvaluated(Function(EvaluationDetails) onFlagEvaluated) {
    _onFlagEvaluated.add(onFlagEvaluated);
  }

  void addOnClientReady(Function(ClientCacheState) onClientReady) {
    final clientCacheState = _clientCacheState;
    if (clientCacheState != null) {
      onClientReady(clientCacheState);
    } else {
      _onClientReady.add(onClientReady);
    }
  }

  void addOnClientReadyWithSnapshot(
      Function(ConfigCatClientSnapshot) onClientReady) {
    _onClientReadyWithSnapshot.add(onClientReady);
  }

  void invokeError(String message, [dynamic error, StackTrace? stackTrace]) {
    for (final hook in _onError) {
      hook(message, error, stackTrace);
    }
  }

  void invokeConfigChanged(Map<String, Setting> entries,
      SnapshotBuilder snapshotBuilder, InMemoryResult inMemory) {
    if (_onConfigChanged.isNotEmpty) {
      final snapshot = snapshotBuilder.buildSnapshot(inMemory);
      for (final hook in _onConfigChanged) {
        hook(entries, snapshot);
      }
    }
  }

  void invokeFlagEvaluated(EvaluationDetails context) {
    for (final hook in _onFlagEvaluated) {
      hook(context);
    }
  }

  void invokeOnReady(ClientCacheState clientCacheState,
      SnapshotBuilder snapshotBuilder, InMemoryResult inMemory) {
    _clientCacheState = clientCacheState;
    for (final hook in _onClientReady) {
      hook(clientCacheState);
    }
    if (_onClientReadyWithSnapshot.isNotEmpty) {
      final snapshot = snapshotBuilder.buildSnapshot(inMemory);
      for (final hook in _onClientReadyWithSnapshot) {
        hook(snapshot);
      }
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
  final PollingMode pollingMode;
  final ConfigCatCache? cache;
  final ConfigCatLogger? logger;
  final FlagOverrides? override;
  final HttpClientAdapter? httpClientAdapter;
  final ConfigCatUser? defaultUser;
  final Hooks? hooks;
  final bool offline;

  const ConfigCatOptions({
    this.baseUrl = '',
    this.dataGovernance = DataGovernance.global,
    this.pollingMode = PollingMode.defaultMode,
    this.cache,
    this.logger,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.httpClientAdapter,
    this.override,
    this.defaultUser,
    this.hooks,
    this.offline = false,
  });

  bool isBaseUrlCustom() {
    return baseUrl.isNotEmpty;
  }

  ConfigCatOptions copyWith({
    String? baseUrl,
    DataGovernance? dataGovernance,
    PollingMode? pollingMode,
    ConfigCatCache? cache,
    ConfigCatLogger? logger,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    HttpClientAdapter? httpClientAdapter,
    FlagOverrides? override,
    ConfigCatUser? defaultUser,
    Hooks? hooks,
    bool? offline,
  }) =>
      ConfigCatOptions(
        baseUrl: baseUrl ?? this.baseUrl,
        dataGovernance: dataGovernance ?? this.dataGovernance,
        pollingMode: pollingMode ?? this.pollingMode,
        cache: cache ?? this.cache,
        logger: logger ?? this.logger,
        connectTimeout: connectTimeout ?? this.connectTimeout,
        sendTimeout: sendTimeout ?? this.sendTimeout,
        receiveTimeout: receiveTimeout ?? this.receiveTimeout,
        httpClientAdapter: httpClientAdapter ?? this.httpClientAdapter,
        override: override ?? this.override,
        defaultUser: defaultUser ?? this.defaultUser,
        hooks: hooks ?? this.hooks,
        offline: offline ?? this.offline,
      );

  static const ConfigCatOptions defaultOptions = ConfigCatOptions();
}
