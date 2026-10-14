import 'dart:async';
import 'dart:convert';

import 'package:configcat_client/src/client_cache_state.dart';
import 'package:configcat_client/src/errors.dart';
import 'package:configcat_client/src/snapshot_builder.dart';
import 'package:crypto/crypto.dart';

import '../configcat_cache.dart';
import '../configcat_options.dart';
import '../configcat_log_messages.dart';
import '../polling_mode.dart';
import '../mixins.dart';
import '../constants.dart';
import '../log/configcat_logger.dart';
import '../json/setting.dart';
import 'config_fetcher.dart';
import '../entry.dart';
import '../error_reporter.dart';
import 'refresh_result.dart';
import 'periodic_executor.dart';

class SettingResult {
  final Map<String, Setting> settings;
  final DateTime fetchTime;

  SettingResult({required this.settings, required this.fetchTime});

  bool get isEmpty => identical(this, empty);

  static SettingResult empty =
      SettingResult(settings: {}, fetchTime: distantPast);
}

class InMemoryResult {
  final SettingResult settingResult;
  final ClientCacheState cacheState;

  InMemoryResult(this.settingResult, this.cacheState);

  static InMemoryResult empty =
      InMemoryResult(SettingResult.empty, ClientCacheState.noFlagData);
}

class FetchResult {
  final Entry entry;
  final String? error;
  final RefreshErrorCode errorCode;
  final Object? errorObject;

  FetchResult(this.entry,
      [this.error, this.errorCode = RefreshErrorCode.none, this.errorObject]);
}

class ConfigService with ContinuousFutureSynchronizer {
  late final String _cacheKey;
  late final PollingMode _mode;
  late final Hooks _hooks;
  late final Fetcher _fetcher;
  late final ConfigCatLogger _logger;
  late final ConfigCatCache _cache;
  late final ErrorReporter _errorReporter;
  late final SnapshotBuilder _snapshotBuilder;
  Entry _cachedEntry = Entry.empty;
  String _cachedEntryString = '';
  bool _offline = false;
  bool _initialized = false;
  bool _cacheStateReported = false;
  PeriodicExecutor? _periodicExecutor;

  ConfigService(
      {required String sdkKey,
      required PollingMode mode,
      required Hooks hooks,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigCatCache cache,
      required ErrorReporter errorReporter,
      required SnapshotBuilder snapshotBuilder,
      required bool offline}) {
    _cacheKey = sha1
        .convert(
            utf8.encode('${sdkKey}_${configJsonName}_$configJsonCacheVersion'))
        .toString();
    _mode = mode;
    _hooks = hooks;
    _fetcher = fetcher;
    _logger = logger;
    _cache = cache;
    _errorReporter = errorReporter;
    _offline = offline;
    _snapshotBuilder = snapshotBuilder;

    if (mode is AutoPollingMode) {
      _startPoll(mode);
    } else {
      _setInitializedState();
    }
  }

  void _setInitializedState() {
    _initialized = true;
    _readCache().then((cached) => {
          if (!cached.isEmpty && cached.eTag != _cachedEntry.eTag)
            {
              _cachedEntry = cached,
              _hooks.invokeConfigChanged(
                  cached.config.entries, _snapshotBuilder, inMemory)
            },
          _initializeAndReportCacheState()
        });
  }

  InMemoryResult get inMemory {
    return InMemoryResult(
        SettingResult(
            settings: _cachedEntry.config.entries,
            fetchTime: _cachedEntry.fetchTime),
        _determineReadyState());
  }

  Future<SettingResult> getSettings() async {
    final mode = _mode;
    var threshold = distantPast;
    var preferCached = _initialized;
    if (mode is LazyLoadingMode) {
      threshold = DateTime.now().toUtc().subtract(mode.cacheRefreshInterval);
      preferCached = false;
    } else if (!_initialized && mode is AutoPollingMode) {
      threshold = DateTime.now().toUtc().subtract(mode.autoPollInterval);
    }
    final result = await _fetchIfOlder(threshold, preferCached: preferCached);
    return !result.entry.isEmpty
        ? SettingResult(
            settings: result.entry.config.entries,
            fetchTime: result.entry.fetchTime)
        : SettingResult.empty;
  }

  Future<RefreshResult> refresh() async {
    if (_offline && _cache is NullConfigCatCache) {
      String offlineWarning =
          ConfigCatLogMessages.configServiceCannotInitiateHttpCallsWarn;
      _logger.warning(3200, offlineWarning);
      return RefreshResult(
          false, offlineWarning, RefreshErrorCode.offlineClient);
    }
    final result = await _fetchIfOlder(distantFuture);
    return RefreshResult(result.error == null, result.error, result.errorCode,
        result.errorObject);
  }

  void online() {
    if (!_offline) return;
    _offline = false;
    final mode = _mode;
    _periodicExecutor?.cancel();
    if (mode is AutoPollingMode) {
      _startPoll(mode);
    }
    _logger.info(
        5200, ConfigCatLogMessages.getConfigServiceStatusChanged('ONLINE'));
  }

  void offline() {
    if (_offline) return;
    _offline = true;
    _logger.info(
        5200, ConfigCatLogMessages.getConfigServiceStatusChanged('OFFLINE'));
  }

  bool isOffline() => _offline;

  void close() {
    _periodicExecutor?.cancel();
    _fetcher.close();
  }

  Future<FetchResult> _fetchIfOlder(DateTime time,
      {bool preferCached = false}) async {
    // Sync up with the cache and use it when it's not expired.
    final entry = await _readCache();
    if (!entry.isEmpty && entry.eTag != _cachedEntry.eTag) {
      _cachedEntry = entry;
      _hooks.invokeConfigChanged(
          entry.config.entries, _snapshotBuilder, inMemory);
    }
    // Cache isn't expired
    if (_cachedEntry.fetchTime.isAfter(time)) {
      _initializeAndReportCacheState();
      return FetchResult(_cachedEntry);
    }

    // If we are in offline mode or the caller prefers cached values, do not initiate fetch.
    if (_offline || preferCached) {
      _initializeAndReportCacheState();
      return FetchResult(_cachedEntry);
    }
    // No fetch is running, initiate a new one.
    // Ensure only one fetch request is running at a time.
    return await syncFuture(_fetch);
  }

  Future<FetchResult> _fetch() async {
    final mode = _mode;
    if (mode is AutoPollingMode && !_initialized) {
      // Waiting for the client initialization.
      // After the maxInitWaitTime timeout the client will be initialized and while
      // the config is not ready the default value will be returned.
      return await _fetchConfig().timeout(mode.maxInitWaitTime, onTimeout: () {
        _logger.warning(
            4200,
            ConfigCatLogMessages.getAutoPollMaxInitWaitTimeReached(
                mode.maxInitWaitTime.inSeconds));
        _initializeAndReportCacheState();
        return FetchResult(_cachedEntry);
      });
    }
    // The service is initialized, start fetch without timeout.
    return await _fetchConfig();
  }

  Future<FetchResult> _fetchConfig() async {
    final response = await _fetcher.fetchConfiguration(_cachedEntry.eTag);
    if (response.isFetched) {
      _cachedEntry = response.entry;
      await _writeCache(response.entry);
      _hooks.invokeConfigChanged(
          response.entry.config.entries, _snapshotBuilder, inMemory);
    } else if ((response.isNotModified || !response.isTransientError) &&
        !_cachedEntry.isEmpty) {
      _cachedEntry = _cachedEntry.withTime(DateTime.now().toUtc());
      await _writeCache(_cachedEntry);
    }
    _initializeAndReportCacheState();
    return FetchResult(
        _cachedEntry, response.error, response.errorCode, response.errorObject);
  }

  void _startPoll(AutoPollingMode mode) {
    _periodicExecutor = PeriodicExecutor(
        () async => await _fetchIfOlder(
            DateTime.now().toUtc().subtract(mode.autoPollInterval)),
        mode.autoPollInterval);
  }

  void _initializeAndReportCacheState() {
    _initialized = true;
    if (!_cacheStateReported) {
      _cacheStateReported = true;
      _hooks.invokeOnReady(_determineReadyState(), _snapshotBuilder, inMemory);
    }
  }

  Future<Entry> _readCache() async {
    try {
      final entry = await _cache.read(_cacheKey);
      if (entry.isEmpty) return Entry.empty;
      if (entry == _cachedEntryString) return Entry.empty;
      _cachedEntryString = entry;
      return Entry.fromCached(entry);
    } catch (e, s) {
      _errorReporter.error(
          2200, ConfigCatLogMessages.configServiceCacheReadError, e, s);
      return Entry.empty;
    }
  }

  Future<void> _writeCache(Entry value) async {
    try {
      final entry = value.serialize();
      _cachedEntryString = entry;
      await _cache.write(_cacheKey, entry);
    } catch (e, s) {
      _errorReporter.error(
          2201, ConfigCatLogMessages.configServiceCacheWriteError, e, s);
    }
  }

  ClientCacheState _determineReadyState() {
    if (_cachedEntry.isEmpty) {
      return ClientCacheState.noFlagData;
    }

    if (_mode is AutoPollingMode) {
      final autoPollMode = _mode as AutoPollingMode;
      if (_cachedEntry.isExpired(autoPollMode.autoPollInterval)) {
        return ClientCacheState.hasCachedFlagDataOnly;
      }
    } else if (_mode is LazyLoadingMode) {
      final lazyLoadingMode = _mode as LazyLoadingMode;
      if (_cachedEntry.isExpired(lazyLoadingMode.cacheRefreshInterval)) {
        return ClientCacheState.hasCachedFlagDataOnly;
      }
    } else {
      return ClientCacheState.hasCachedFlagDataOnly;
    }

    return ClientCacheState.hasUpToDateFlagData;
  }
}
