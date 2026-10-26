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
import 'errors.dart';
import 'json/setting.dart';
import 'log/configcat_logger.dart';
import 'polling_mode.dart';
import 'configcat_client.dart';
import 'override/flag_overrides.dart';
import 'configcat_user.dart';

/// Additional information about flag evaluation.
class EvaluationDetails<T> {
  final String key;
  final String? variationId;
  final ConfigCatUser? user;
  final bool isDefaultValue;
  final String? error;
  final EvaluationErrorCode errorCode;
  final Object? errorObject;
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
      required this.errorObject,
      required this.value,
      required this.fetchTime,
      required this.matchedTargetingRule,
      required this.matchedPercentageOption});

  static EvaluationDetails<T> makeError<T>(
      String key,
      T defaultValue,
      String error,
      EvaluationErrorCode errorCode,
      Object? errorObject,
      ConfigCatUser? user) {
    return EvaluationDetails<T>(
        key: key,
        variationId: "",
        user: user,
        isDefaultValue: true,
        error: error,
        errorCode: errorCode,
        errorObject: errorObject,
        value: defaultValue,
        fetchTime: distantPast,
        matchedTargetingRule: null,
        matchedPercentageOption: null);
  }
}

class Hooks {
  final List<Function(String, [dynamic error, StackTrace? stackTrace])>
      _onError = [];
  final List<Function(Map<String, Setting>, ConfigCatClientSnapshot)>
      _onConfigChanged = [];
  final List<Function(EvaluationDetails)> _onFlagEvaluated = [];
  final List<Function(ClientCacheState)> _onClientReady = [];
  final List<Function(ConfigCatClientSnapshot)> _onClientReadyWithSnapshot = [];
  ClientCacheState? _clientCacheState;

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
    _onClientReadyWithSnapshot.clear();
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
  final Function(Hooks)? hooks;
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

  static const ConfigCatOptions defaultOptions = ConfigCatOptions();
}
