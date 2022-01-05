import 'data_source.dart';
import 'behaviour.dart';

/// Describes feature flag & setting overrides.
///
/// [dataSource] contains the flag values in a key-value map.
/// [behaviour] can be used to set preference on whether the local values should
/// override the remote values, or use local values only when a remote value doesn't exist,
/// or use it for local only mode.
class FlagOverrides {
  final OverrideDataSource dataSource;
  final OverrideBehaviour behaviour;

  FlagOverrides({required this.dataSource, required this.behaviour});
}
