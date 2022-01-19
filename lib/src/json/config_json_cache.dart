import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../configcat_cache.dart';
import '../log/configcat_logger.dart';
import '../constants.dart';
import 'config.dart';

class ConfigJsonCache {
  Config _inMemoryConfig = Config.empty;
  String _inMemoryConfigString = '';
  late final ConfigCatLogger _logger;
  late final ConfigCatCache _cache;
  late final String _cacheKey;

  ConfigJsonCache(
      {required ConfigCatLogger logger,
      required ConfigCatCache cache,
      required String sdkKey}) {
    _logger = logger;
    _cache = cache;
    _cacheKey =
        sha1.convert(utf8.encode('dart_${configJsonName}_$sdkKey')).toString();
  }

  Future<Config> readFromJson(String json, String eTag) async {
    if (json.isEmpty) {
      return Config.empty;
    }

    try {
      final decoded = jsonDecode(json);
      final config = Config.fromJson(decoded);
      config.eTag = eTag;
      return config;
    } catch (e, s) {
      _logger.error('Config JSON parsing failed.', e, s);
      return Config.empty;
    }
  }

  Future<Config> readCache() async {
    final fromCache = await _readCache();
    if (fromCache.isEmpty || fromCache == _inMemoryConfigString) {
      return _inMemoryConfig;
    }

    try {
      final decoded = jsonDecode(fromCache);
      final config = Config.fromJson(decoded);
      if (_inMemoryConfig.timeStamp >= config.timeStamp) {
        return _inMemoryConfig;
      }
      _inMemoryConfig = config;
      _inMemoryConfigString = fromCache;
      return config;
    } catch (e, s) {
      _logger.error('Config JSON parsing failed.', e, s);
      return _inMemoryConfig;
    }
  }

  Future<void> writeCache(Config value) async {
    try {
      value.timeStamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      _inMemoryConfig = value;
      _inMemoryConfigString = jsonEncode(value);
      await _cache.write(_cacheKey, _inMemoryConfigString);
    } catch (e, s) {
      _logger.error('An error occurred during the cache write.', e, s);
    }
  }

  Future<String> _readCache() async {
    try {
      return await _cache.read(_cacheKey);
    } catch (e, s) {
      _logger.error('An error occurred during the cache read.', e, s);
      return Future.value('');
    }
  }
}
