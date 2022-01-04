/// Describes how the overrides should behave.
enum OverrideBehaviour {
  /// With this mode, the SDK won't fetch the flags & settings from the ConfigCat CDN,
  /// and it will use only the local overrides to evaluate values.
  localOnly,

  /// With this mode, the SDK will fetch the feature flags & settings from the ConfigCat CDN,
  /// and it will replace those that have a matching key in the flag overrides.
  localOverRemote,

  /// With this mode, the SDK will fetch the feature flags & settings from the ConfigCat CDN,
  /// and it will use the overrides for only those flags that doesn't exist in the fetched configuration.
  remoteOverLocal
}
