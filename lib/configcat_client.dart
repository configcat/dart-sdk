/// ConfigCat Dart SDK
///
/// Dart SDK for ConfigCat. ConfigCat is a hosted feature flag service: https://configcat.com. Manage feature toggles across frontend, backend, mobile, desktop apps. Alternative to LaunchDarkly. Management app + feature flag SDKs.

library configcat_client;

// logging
export 'src/log/logger.dart';
export 'src/log/default_logger.dart';
export 'src/log/configcat_logger.dart';

// polling modes
export 'src/polling_mode.dart';

// core
export 'src/configcat_cache.dart';
export 'src/configcat_client.dart';
export 'src/configcat_options.dart';
export 'src/configcat_user.dart';
export 'src/data_governance.dart';

// overrides
export 'src/override/behaviour.dart';
export 'src/override/data_source.dart';
export 'src/override/flag_overrides.dart';

// fetch
export 'src/fetch/refresh_result.dart';

// json models
export 'src/json/config.dart';
export 'src/json/preferences.dart';
export 'src/json/setting.dart';
export 'src/json/targeting_rule.dart';
export 'src/json/percentage_option.dart';
export 'src/json/condition.dart';
export 'src/json/segment.dart';
export 'src/json/segment_condition.dart';
export 'src/json/prerequisite_flag_condition.dart';
export 'src/json/user_condition.dart';
export 'src/json/settings_value.dart';
export 'src/json/served_value.dart';
