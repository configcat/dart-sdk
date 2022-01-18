import 'package:configcat_client/src/override/flag_overrides.dart';
import 'package:dio/dio.dart';

import 'configcat_cache.dart';
import 'data_governance.dart';
import 'log/configcat_logger.dart';
import 'refresh_policy/polling_mode.dart';
import 'configcat_client.dart';

/// Configuration options for [ConfigCatClient].
class ConfigCatOptions {
  final String baseUrl;
  final DataGovernance dataGovernance;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final String proxyUrl;
  final PollingMode? mode;
  final ConfigCatCache? cache;
  final ConfigCatLogger? logger;
  final FlagOverrides? override;
  final HttpClientAdapter? httpClientAdapter;

  const ConfigCatOptions({
    this.baseUrl = '',
    this.dataGovernance = DataGovernance.global,
    this.mode,
    this.cache,
    this.logger,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 30),
    this.proxyUrl = '',
    this.httpClientAdapter,
    this.override,
  });
}
