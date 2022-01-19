/// A cache API used to make custom cache implementations.
abstract class ConfigCatCache {
  /// Child classes has to implement this method, the [ConfigCatClient] is
  /// using it to get the actual value from the cache.
  ///
  /// [key] is the key of the cache entry.
  Future<String> read(String key);

  /// Child classes has to implement this method, the [ConfigCatClient] is
  /// using it to set the actual cached value.
  ///
  /// [key] is the key of the cache entry.
  /// [value] is the new value to cache.
  Future<void> write(String key, String value);
}

/// Represents a null cache.
class NullConfigCatCache extends ConfigCatCache {
  @override
  Future<String> read(String key) {
    return Future.value('');
  }

  @override
  Future<void> write(String key, String value) {
    return Future.value();
  }
}
