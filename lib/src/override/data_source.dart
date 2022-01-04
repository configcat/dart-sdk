import 'package:configcat_client/src/json/setting.dart';
import 'package:configcat_client/src/override/flag_overrides.dart';

/// Describes a data source for [FlagOverrides].
abstract class OverrideDataSource {
  /// Gets all the overrides defined in the given source.
  Future<Map<String, Setting>> getOverrides();

  /// Create an [OverrideDataSource] that stores the overrides in a key-value map.
  factory OverrideDataSource.map(Map<String, Object> overrides) {
    return _MapOverrideDataSource(overrides);
  }
}

class _MapOverrideDataSource implements OverrideDataSource {
  late final Map<String, Setting> overrides;

  _MapOverrideDataSource(Map<String, Object> mapOverrides) {
    overrides =
        mapOverrides.map((key, value) => MapEntry(key, value.toSetting()));
  }

  @override
  Future<Map<String, Setting>> getOverrides() {
    return Future.value(overrides);
  }
}
