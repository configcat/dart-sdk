import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/fetch/entry.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:configcat_client/src/json/setting.dart';
import 'package:dio/dio.dart';
import 'package:sprintf/sprintf.dart';

const urlTemplate = '%s/configuration-files/%s/$configJsonName';
const testSdkKey = 'test';
const etag = 'test-etag';

Config createTestConfig(Map<String, Object> map) {
  return Config(
      Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
}

Entry createTestEntry(Map<String, Object> map) {
  return Entry(createTestConfig(map), map[0].toString(), '', DateTime.now().toUtc());
}

String getPath() {
  return sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, testSdkKey]);
}

class RequestCounterInterceptor extends Interceptor {
  final requests = <String, int>{};

  int? requestCountForPath(String path) {
    for (final key in requests.keys) {
      if (key.startsWith(path)) {
        return requests[key];
      }
    }
  }

  RequestCounterInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final count = requests[options.path + (options.headers.values.join())];
    if (count != null) {
      requests[options.path + (options.headers.values.join())] = count + 1;
    } else {
      requests[options.path + (options.headers.values.join())] = 1;
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  void clear() {
    requests.clear();
  }
}
