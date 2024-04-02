const version = '4.1.0';
const configJsonCacheVersion = 'v2';
const configJsonName = 'config_v6.json';
final DateTime distantPast = DateTime.utc(1970, 01, 01);
final DateTime distantFuture =
    DateTime.now().toUtc().add(const Duration(days: 1000 * 365));

final String sdkKeyProxyPrefix = "configcat-proxy/";
final String sdkKeyPrefix = "configcat-sdk-1";
final int sdkKeySectionLength = 22;
