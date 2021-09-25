import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

import '../config_cache.dart';
import '../config_fetcher.dart';

abstract class RefreshPolicy {
  final ConfigCache cache;
  final ConfigFetcher fetcher;
  final Logger log;
  
  late final String _inMemoryValue;
  late final String _cacheKey;

  RefreshPolicy({required this.cache, required this.fetcher, required this.log, required sdkKey}) {
    this._cacheKey = 'dart_${sdkKey}_$configJsonName.json';
  }

  writeCache(String value) {
    _inMemoryValue = value;
    cache.write(key: _cacheKey, value: value);
  }

  String readCache() {
    return cache.read(key: _cacheKey);
  }

  String get lastCachedConfiguration {
    return _inMemoryValue;
  }

  Future<String> getConfiguration();

  Future<void> refresh() async {
    final response = await fetcher.fetchConfigurationJson(http.Client());
    if (response.isFetched) {
      writeCache(response.body);
    }
  }
}