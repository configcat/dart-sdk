import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../configcat_cache.dart';
import '../configcat_options.dart';
import '../polling_mode.dart';
import '../mixins.dart';
import '../constants.dart';
import '../log/configcat_logger.dart';
import '../json/setting.dart';
import '../json/config.dart';
import 'config_fetcher.dart';
import 'entry.dart';
import '../error_reporter.dart';

class ConfigService with ConfigJsonParser, ContinuousFutureSynchronizer {
  late final String _cacheKey;
  late final ConfigCatOptions _options;
  late final Fetcher _fetcher;
  late final ConfigCatLogger _logger;
  late final ConfigCatCache _cache;
  late final ErrorReporter _errorReporter;
  Timer? _timer;
  Entry _cachedEntry = Entry.empty;
  bool _offline = false;
  bool _initialized = false;

  ConfigService(
      {required String sdkKey,
      required ConfigCatOptions options,
      required Fetcher fetcher,
      required ConfigCatLogger logger,
      required ConfigCatCache cache,
      required ErrorReporter errorReporter}) {
    _cacheKey =
        sha1.convert(utf8.encode('dart_${configJsonName}_$sdkKey')).toString();
    _options = options;
    _fetcher = fetcher;
    _logger = logger;
    _cache = cache;
    _errorReporter = errorReporter;

    final mode = options.mode;
    if (mode is AutoPollingMode) {
      _startPoll(mode);
    } else {
      _timer = null;
      _initialized = true;
    }
  }

  Future<Map<String, Setting>> getSettings() async {
    final mode = _options.mode;
    if (mode is LazyLoadingMode) {
      final config = await _fetchIfOlder(
          DateTime.now().toUtc().subtract(mode.cacheRefreshInterval));
      return config.entries;
    } else {
      final config = await _fetchIfOlder(distantPast, preferCached: true);
      return config.entries;
    }
  }

  Future<void> refresh() async {
    await _fetchIfOlder(distantFuture);
  }

  void online() {
    if (!_offline) return;
    _offline = false;
    final mode = _options.mode;
    if (mode is AutoPollingMode) {
      _startPoll(mode);
    }
  }

  void offline() {
    if (_offline) return;
    _offline = true;
    _timer?.cancel();
  }

  bool isOffline() => _offline;

  void close() {
    _timer?.cancel();
    _fetcher.close();
  }

  Future<Config> _fetchIfOlder(DateTime time,
      {bool preferCached = false}) async {
    // Sync up with the cache and use it when it's not expired.
    if (_cachedEntry.isEmpty() || _cachedEntry.fetchTime.isAfter(time)) {
      final json = await _readCache();
      if (json.isNotEmpty && json != _cachedEntry.json) {
        final config = parseConfigFromJson(json, _errorReporter);
        if (!config.isEmpty()) {
          _cachedEntry = Entry(config, json, '', distantPast);
          _options.hooks?.onConfigChanged?.call();
        }
      }
      if (_cachedEntry.fetchTime.isAfter(time)) {
        return _cachedEntry.config;
      }
    }
    // Use cache anyway (either offline mode or get calls on auto & manual poll must not initiate fetch).
    // The initialized check ensures that we subscribe for the ongoing fetch during the
    // max init wait time window in case of auto poll.
    if ((preferCached && _initialized) || _offline) {
      return _cachedEntry.config;
    }

    // No fetch is running, initiate a new one.
    // Ensure only one fetch request is running at a time.
    return await syncFuture(() => _fetch());
  }

  Future<Config> _fetch() async {
    final mode = _options.mode;
    if (mode is AutoPollingMode && !_initialized) {
      // Waiting for the client initialization.
      // After the maxInitWaitTimeInSeconds timeout the client will be initialized and while
      // the config is not ready the default value will be returned.
      return await _fetchConfig().timeout(mode.maxInitWaitTime, onTimeout: () {
        _logger.warning(
            'Max init wait time for the very first fetch reached (${mode.maxInitWaitTime.inMilliseconds}ms). Returning cached config.');
        _initialized = true;
        return _cachedEntry.config;
      });
    }
    // The service is initialized, start fetch without timeout.
    return await _fetchConfig();
  }

  Future<Config> _fetchConfig() async {
    final response = await _fetcher.fetchConfiguration(_cachedEntry.eTag);
    if (response.isFetched && response.entry.json != _cachedEntry.json) {
      _cachedEntry = response.entry;
      await _writeCache(response.entry.json);
      _options.hooks?.onConfigChanged?.call();
    } else if (response.isNotModified) {
      _cachedEntry = _cachedEntry.withTime(DateTime.now().toUtc());
    }
    _initialized = true;
    return _cachedEntry.config;
  }

  void _startPoll(AutoPollingMode mode) {
    final timer = _timer;
    if (timer != null && timer.isActive) return;
    _timer = Timer.periodic(mode.autoPollInterval, (Timer t) async {
      await refresh();
    });
    // execute immediately, because periodic() waits for an interval amount of time before the first tick
    Timer.run(() async {
      await refresh();
    });
  }

  Future<String> _readCache() async {
    try {
      return await _cache.read(_cacheKey);
    } catch (e, s) {
      _errorReporter.error('An error occurred during the cache read.', e, s);
      return '';
    }
  }

  Future<void> _writeCache(String value) async {
    try {
      await _cache.write(_cacheKey, value);
    } catch (e, s) {
      _errorReporter.error('An error occurred during the cache write.', e, s);
    }
  }
}
