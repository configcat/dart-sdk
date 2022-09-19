import 'dart:async';
import 'dart:convert';

import 'package:configcat_client/src/fetch/refresh_result.dart';
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
import '../json/entry.dart';
import '../error_reporter.dart';

class SettingResult {
  final Map<String, Setting> settings;
  final DateTime fetchTime;

  SettingResult({required this.settings, required this.fetchTime});

  bool get isEmpty => settings.isEmpty;

  static SettingResult empty =
      SettingResult(settings: {}, fetchTime: distantPast);
}

class ConfigService with ContinuousFutureSynchronizer, PeriodicExecutor {
  late final String _cacheKey;
  late final PollingMode _mode;
  late final Hooks _hooks;
  late final Fetcher _fetcher;
  late final ConfigCatLogger _logger;
  late final ConfigCatCache _cache;
  late final ErrorReporter _errorReporter;
  Entry _cachedEntry = Entry.empty;
  bool _offline = false;
  bool _initialized = false;

  ConfigService(
      {required String sdkKey,
      required PollingMode mode,
      required Hooks hooks,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigCatCache cache,
      required ErrorReporter errorReporter}) {
    _cacheKey = sha1
        .convert(utf8.encode('dart_${configJsonName}_${sdkKey}_v2'))
        .toString();
    _mode = mode;
    _hooks = hooks;
    _fetcher = fetcher;
    _logger = logger;
    _cache = cache;
    _errorReporter = errorReporter;

    if (mode is AutoPollingMode) {
      _startPoll(mode);
    } else {
      _initialized = true;
      _hooks.invokeOnReady();
    }
  }

  Future<SettingResult> getSettings() async {
    final mode = _mode;
    if (mode is LazyLoadingMode) {
      final entry = await _fetchIfOlder(
          DateTime.now().toUtc().subtract(mode.cacheRefreshInterval));
      return SettingResult(
          settings: entry.first.config.entries,
          fetchTime: entry.first.fetchTime);
    } else {
      final entry = await _fetchIfOlder(distantPast, preferCached: true);
      return SettingResult(
          settings: entry.first.config.entries,
          fetchTime: entry.first.fetchTime);
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
    _logger.debug("Switched to ONLINE mode.");
  }

  void offline() {
    if (_offline) return;
    _offline = true;
    cancelPeriodic();
    _logger.debug("Switched to OFFLINE mode.");
  }

  bool isOffline() => _offline;

  void close() {
    cancelPeriodic();
    _fetcher.close();
  }

  Future<Pair<Entry, String?>> _fetchIfOlder(DateTime time,
      {bool preferCached = false}) async {
    // Sync up with the cache and use it when it's not expired.
    if (_cachedEntry.isEmpty || _cachedEntry.fetchTime.isAfter(time)) {
      final entry = await _readCache();
      if (!entry.isEmpty && entry.eTag != _cachedEntry.eTag) {
        _cachedEntry = entry;
        _hooks.invokeConfigChanged(entry.config.entries);
      }
      if (_cachedEntry.fetchTime.isAfter(time)) {
        return Pair(_cachedEntry, null);
      }
    }
    // Use cache anyway (get calls on auto & manual poll must not initiate fetch).
    // The initialized check ensures that we subscribe for the ongoing fetch during the
    // max init wait time window in case of auto poll.
    if (preferCached && _initialized) {
      return Pair(_cachedEntry, null);
    }
    // If we are in offline mode we are not allowed to initiate fetch.
    if (_offline) {
      return Pair(_cachedEntry,
          "The SDK is in offline mode, it can't initiate HTTP calls.");
    }
    // No fetch is running, initiate a new one.
    // Ensure only one fetch request is running at a time.
    return await syncFuture(_fetch);
  }

  Future<Pair<Entry, String?>> _fetch() async {
    final mode = _mode;
    if (mode is AutoPollingMode && !_initialized) {
      // Waiting for the client initialization.
      // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while
      // the config is not ready the default value will be returned.
      return await _fetchConfig().timeout(mode.maxInitWaitTime, onTimeout: () {
        _logger.warning(
            'Max init wait time for the very first fetch reached (${mode.maxInitWaitTime.inMilliseconds}ms). Returning cached config.');
        _initialized = true;
        _hooks.invokeOnReady();
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
    } else if (response.isNotModified) {
      _cachedEntry = _cachedEntry.withTime(DateTime.now().toUtc());
      await _writeCache(_cachedEntry);
    }
    if (!_initialized) {
      _hooks.invokeOnReady();
      _initialized = true;
    }
    return Pair(_cachedEntry, response.error);
  }

  void _startPoll(AutoPollingMode mode) {
    startPeriodic(
        mode.autoPollInterval,
        () async => await _fetchIfOlder(
            DateTime.now().toUtc().subtract(mode.autoPollInterval)));
  }

  Future<Entry> _readCache() async {
    try {
      final json = await _cache.read(_cacheKey);
      if (json.isEmpty) return Entry.empty;
      final decoded = jsonDecode(json);
      return Entry.fromJson(decoded);
    } catch (e, s) {
      _errorReporter.error('An error occurred during the cache read.', e, s);
      return Entry.empty;
    }
  }

  Future<void> _writeCache(Entry value) async {
    try {
      final map = value.toJson();
      final json = jsonEncode(map);
      await _cache.write(_cacheKey, json);
    } catch (e, s) {
      _errorReporter.error('An error occurred during the cache write.', e, s);
    }
  }
}
