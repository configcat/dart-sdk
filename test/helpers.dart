import 'dart:convert';

import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_fetcher.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:configcat_client/src/entry.dart';
import 'package:configcat_client/src/json/config.dart';
import 'package:configcat_client/src/json/preferences.dart';
import 'package:dio/dio.dart';
import 'package:sprintf/sprintf.dart';

const urlTemplate = '%s/configuration-files/%s/$configJsonName';
const testSdkKey = 'test';
const etag = 'test-etag';

Config createTestConfig(Map<String, Object> map) {
  return Config(Preferences(ConfigFetcher.globalBaseUrl, 0),
      map.map((key, value) => MapEntry(key, Setting(value, 0, [], [], ''))));
}

Config createTestConfigWithRules() {
  return Config(Preferences(ConfigFetcher.globalBaseUrl, 0), {
    'key1': Setting(
        "def",
        0,
        [],
        [
          RolloutRule("fake1", "Identifier", 2, "@test1.com", "variationId1"),
          RolloutRule("fake2", "Identifier", 2, "@test2.com", "variationId2")
        ],
        ''),
  });
}

Entry createTestEntry(Map<String, Object> map) {
  Config config = createTestConfig(map);
  return Entry(jsonEncode(config.toJson()), config, map[0].toString(),
      DateTime.now().toUtc());
}

Entry createTestEntryWithTime(Map<String, Object> map, DateTime time) {
  Config config = createTestConfig(map);
  return Entry(jsonEncode(config.toJson()), config, map[0].toString(), time);
}

String getPath({String sdkKey = testSdkKey}) {
  return sprintf(urlTemplate, [ConfigFetcher.globalBaseUrl, sdkKey]);
}

Future<Duration> until(
    Future<bool> Function() predicate, Duration timeout) async {
  final start = DateTime.now().toUtc();
  while (!await predicate()) {
    await Future.delayed(const Duration(milliseconds: 100));
    if (DateTime.now().toUtc().isAfter(start.add(timeout))) {
      throw Exception("Test await timed out.");
    }
  }
  return DateTime.now().toUtc().difference(start);
}

class CustomCache implements ConfigCatCache {
  late String _value;

  CustomCache(String initial) {
    _value = initial;
  }

  @override
  Future<String> read(String key) {
    return Future.value(_value);
  }

  @override
  Future<void> write(String key, String value) {
    _value = value;
    return Future.value();
  }
}

class RequestCounterInterceptor extends Interceptor {
  final requests = <String, int>{};

  int? requestCountForPath(String path) {
    for (final key in requests.keys) {
      if (key.startsWith(path)) {
        return requests[key];
      }
    }
    return null;
  }

  int allRequestCount() {
    if (requests.values.isEmpty) return 0;
    return requests.values.reduce((value, element) => value + element);
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
  void onError(DioException err, ErrorInterceptorHandler handler) {
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
