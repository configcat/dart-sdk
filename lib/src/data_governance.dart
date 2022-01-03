/// Describes the location of your feature flag and setting data within the ConfigCat CDN.
enum DataGovernance {
  /// Select this if your feature flags are published to CDN nodes only in the EU.
  euOnly,

  /// Select this if your feature flags are published to all global CDN nodes.
  global,
}
