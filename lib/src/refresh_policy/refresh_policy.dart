import '../config_fetcher.dart';
import '../json/config.dart';
import '../json/config_json_cache.dart';
import '../log/configcat_logger.dart';

abstract class RefreshPolicy {
  Future<Config> getConfiguration();
  void close();
  Future<void> refresh();
}

abstract class DefaultRefreshPolicy extends RefreshPolicy {
  final Fetcher fetcher;
  final ConfigCatLogger logger;
  final ConfigJsonCache jsonCache;

  DefaultRefreshPolicy(
      {required this.fetcher,
      required this.logger,
      required this.jsonCache});

  @override
  Future<Config> getConfiguration();

  @override
  void close() {
    fetcher.close();
  }

  @override
  Future<void> refresh() async {
    final response = await fetcher.fetchConfiguration();
    if (response.isFetched) {
      await jsonCache.writeCache(response.config);
    }
  }
}

class NullRefreshPolicy implements RefreshPolicy {
  @override
  void close() {}

  @override
  Future<Config> getConfiguration() {
    return Future.value(Config.empty);
  }

  @override
  Future<void> refresh() {
    return Future.value(null);
  }
}
