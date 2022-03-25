import 'package:configcat_client/src/override/flag_overrides.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'configcat_client.dart';
import 'data_governance.dart';
import 'log/configcat_logger.dart';
import 'refresh_policy/polling_mode.dart';

/// Represents the config changed callback.
typedef ConfigChangedHandler = void Function();

/// Configuration options for [ConfigCatClient].
class ConfigCatOptions {
  final String baseUrl;
  final DataGovernance dataGovernance;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final PollingMode? mode;
  final ConfigCatCache? cache;
  final ConfigCatLogger? logger;
  final FlagOverrides? override;
  final HttpClientAdapter? httpClientAdapter;
  final ConfigChangedHandler? onConfigChanged;

  const ConfigCatOptions({
    this.baseUrl = '',
    this.dataGovernance = DataGovernance.global,
    this.mode,
    this.cache,
    this.logger,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.httpClientAdapter,
    this.override,
    this.onConfigChanged,
  });
}
