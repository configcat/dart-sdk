import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../configcat_cache.dart';
import '../configcat_options.dart';
import '../pair.dart';
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

class ConfigService with ContinuousFutureSynchronizer {
  late final String _cacheKey;
  late final PollingMode _mode;
  late final Hooks _hooks;
  late final Fetcher _fetcher;
  late final ConfigCatLogger _logger;
  late final ConfigCatCache _cache;
  late final ErrorReporter _errorReporter;
  Entry _cachedEntry = Entry.empty;
  String _cachedEntryString = '';
  bool _offline = false;
  bool _initialized = false;
  PeriodicExecutor? _periodicExecutor;

  ConfigService(
      {required String sdkKey,
      required PollingMode mode,
      required Hooks hooks,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigCatCache cache,
      required ErrorReporter errorReporter,
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

    if (mode is AutoPollingMode && !offline) {
      _startPoll(mode);
    } else {
      _setInitialized();
    }
  }

  Future<SettingResult> getSettings() async {
    final mode = _mode;
    if (mode is LazyLoadingMode) {
      final entry = await _fetchIfOlder(
          DateTime.now().toUtc().subtract(mode.cacheRefreshInterval));
      return !entry.first.isEmpty
          ? SettingResult(
              settings: entry.first.config.entries,
              fetchTime: entry.first.fetchTime)
          : SettingResult.empty;
    } else {
      final entry =
          await _fetchIfOlder(distantPast, preferCached: _initialized);
      return !entry.first.isEmpty
          ? SettingResult(
              settings: entry.first.config.entries,
              fetchTime: entry.first.fetchTime)
          : SettingResult.empty;
    }
  }

  Future<RefreshResult> refresh() async {
    final fetch = await _fetchIfOlder(distantFuture);
    return RefreshResult(fetch.second == null, fetch.second);
  }

  void online() {
    if (!_offline) return;
    _offline = false;
    final mode = _mode;
    if (mode is AutoPollingMode) {
      _startPoll(mode);
    }
    _logger.info(5200, 'Switched to ONLINE mode.');
  }

  void offline() {
    if (_offline) return;
    _offline = true;
    _periodicExecutor?.cancel();
    _logger.info(5200, 'Switched to OFFLINE mode.');
  }

  bool isOffline() => _offline;

  void close() {
    _periodicExecutor?.cancel();
    _fetcher.close();
  }

  Future<Pair<Entry, String?>> _fetchIfOlder(DateTime time,
      {bool preferCached = false}) async {
    // Sync up with the cache and use it when it's not expired.
    final entry = await _readCache();
    if (!entry.isEmpty && entry.eTag != _cachedEntry.eTag) {
      _cachedEntry = entry;
      _hooks.invokeConfigChanged(entry.config.entries);
    }
    // Cache isn't expired
    if (_cachedEntry.fetchTime.isAfter(time)) {
      _setInitialized();
      return Pair(_cachedEntry, null);
    }

    // If we are in offline mode or the caller prefers cached values, do not initiate fetch.
    if (_offline || preferCached) {
      return Pair(_cachedEntry, null);
    }
    // No fetch is running, initiate a new one.
    // Ensure only one fetch request is running at a time.
    return await syncFuture(_fetch);
  }

  Future<Pair<Entry, String?>> _fetch() async {
    final mode = _mode;
    if (mode is AutoPollingMode && !_initialized) {
      // Waiting for the client initialization.
      // After the maxInitWaitTime timeout the client will be initialized and while
      // the config is not ready the default value will be returned.
      return await _fetchConfig().timeout(mode.maxInitWaitTime, onTimeout: () {
        _logger.warning(4200,
            '`maxInitWaitTime` for the very first fetch reached (${mode.maxInitWaitTime.inMilliseconds}ms). Returning cached config.');
        _setInitialized();
        return Pair(_cachedEntry, null);
      });
    }
    // The service is initialized, start fetch without timeout.
    return await _fetchConfig();
  }

  Future<Pair<Entry, String?>> _fetchConfig() async {
    final response = await _fetcher.fetchConfiguration(_cachedEntry.eTag);
    if (response.isFetched) {
      _cachedEntry = response.entry;
      await _writeCache(response.entry);
      _hooks.invokeConfigChanged(response.entry.config.entries);
    } else if ((response.isNotModified || !response.isTransientError) &&
        !_cachedEntry.isEmpty) {
      _cachedEntry = _cachedEntry.withTime(DateTime.now().toUtc());
      await _writeCache(_cachedEntry);
    }
    _setInitialized();
    return Pair(_cachedEntry, response.error);
  }

  void _startPoll(AutoPollingMode mode) {
    _periodicExecutor = PeriodicExecutor(
        () async => await _fetchIfOlder(
            DateTime.now().toUtc().subtract(mode.autoPollInterval)),
        mode.autoPollInterval);
  }

  void _setInitialized() {
    if (!_initialized) {
      _initialized = true;
      _hooks.invokeOnReady();
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
          2200, 'Error occurred while reading the cache.', e, s);
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
          2201, 'Error occurred while writing the cache.', e, s);
    }
  }
}
