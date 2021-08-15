import 'package:dart_sdk/src/config_cache.dart';
import 'package:dart_sdk/src/polling_mode/polling_mode.dart';
import 'package:logging/logging.dart';

const _globalBaseUrl = 'https://cdn-global.configcat.com';
const _euOnlyBaseUrl = 'https://cdn-eu.configcat.com';
typedef ConfigChangedHandler = void Function();
typedef LogLevel = Level;

class ConfigCatClient {
  late Logger log;

  ConfigCatClient({
    required String sdkKey,
    required DataGovernance dataGovernance,
    ConfigCache? configCache = null,
    PollingMode? refreshMode = null,
    int maxWaitTimeForSyncCallsInSeconds = 0,
    String baseUrl = '',
    LogLevel logLevel = LogLevel.WARNING,
  }) {
    if (sdkKey.isEmpty) {
      throw Exception('projectSecret cannot be empty');
    }

    if (maxWaitTimeForSyncCallsInSeconds != 0 && maxWaitTimeForSyncCallsInSeconds < 2) {
      throw Exception('maxWaitTimeForSyncCallsInSeconds cannot be less than 2');
    }

    this.log = Logger('ConfigCat-Dart');
    this.log.level = logLevel;
  }

}

abstract class DataGovernance {
  static const String url = '';

  DataGovernance._();

  factory DataGovernance.global() = DataGovernanceGlobal;
  factory DataGovernance.euOnly() = DataGovernanceGlobalEuOnly;
}

class DataGovernanceGlobal extends DataGovernance {
  DataGovernanceGlobal() : super._();
  static const String url = _globalBaseUrl;
}

class DataGovernanceGlobalEuOnly extends DataGovernance {
  DataGovernanceGlobalEuOnly() : super._();
  static const String url = _euOnlyBaseUrl;
}
