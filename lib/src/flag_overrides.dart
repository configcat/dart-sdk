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

/// Describes feature flag & setting overrides.
///
/// [overrides] contains the flag values in a key-value map.
/// [behaviour] can be used to set preference on whether the local values should
/// override the remote values, or use local values only when a remote value doesn't exist,
/// or use it for local only mode.
class FlagOverride {
  final Map<String, Object> overrides;
  final OverrideBehaviour behaviour;

  FlagOverride(this.overrides, this.behaviour);
}
