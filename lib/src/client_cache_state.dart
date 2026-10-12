/// Defines the possible states of the internal cache.
enum ClientCacheState {
  /// No config data is available in the internal cache.
  noFlagData,

  /// Only config data provided by local flag override is available in the internal cache.
  hasLocalOverrideFlagDataOnly,

  /// Only expired config data obtained from the external cache or the ConfigCat CDN is available in the internal cache.
  hasCachedFlagDataOnly,

  /// Up-to-date config data obtained from the external cache or the ConfigCat CDN is available in the internal cache.
  hasUpToDateFlagData,
}
