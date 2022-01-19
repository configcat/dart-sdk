import 'dart:async';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';

import 'data_governance.dart';
import 'configcat_options.dart';
import 'mixins.dart';
import 'json/config.dart';
import 'json/config_json_cache.dart';
import 'constants.dart';
import 'log/configcat_logger.dart';

enum _Status { fetched, notModified, failure }

class _RedirectMode {
  static const int noRedirect = 0;
  static const int shouldRedirect = 1;
  static const int forceRedirect = 2;
}

class FetchResponse {
  final _Status _status;
  final Config config;

  FetchResponse._(this._status, this.config);

  bool get isFetched {
    return _status == _Status.fetched;
  }

  bool get isNotModified {
    return _status == _Status.notModified;
  }

  bool get isFailed {
    return _status == _Status.failure;
  }

  factory FetchResponse.success(Config config) {
    return FetchResponse._(_Status.fetched, config);
  }

  factory FetchResponse.failure() {
    return FetchResponse._(_Status.failure, Config.empty);
  }

  factory FetchResponse.notModified() {
    return FetchResponse._(_Status.notModified, Config.empty);
  }
}

abstract class Fetcher {
  Dio get client;

  Future<FetchResponse> fetchConfiguration();

  void close();
}

class ConfigFetcher
    with ContinuousFutureSynchronizer<FetchResponse>
    implements Fetcher {
  static const globalBaseUrl = 'https://cdn-global.configcat.com';
  static const euOnlyBaseUrl = 'https://cdn-eu.configcat.com';
  static const _userAgentHeaderName = 'X-ConfigCat-UserAgent';
  static const _ifNoneMatchHeaderName = 'If-None-Match';
  static const _eTagHeaderName = 'Etag';
  static const _successStatusCodes = [200, 201, 202, 203, 204];

  late final ConfigCatLogger _logger;
  late final ConfigJsonCache _jsonCache;
  late final String _mode;
  late final String _sdkKey;

  late final bool _urlIsCustom;
  late final Dio _client;
  late String _url;

  ConfigFetcher(
      {required ConfigCatLogger logger,
      required String sdkKey,
      required String mode,
      required ConfigJsonCache jsonCache,
      required ConfigCatOptions options}) {
    _logger = logger;
    _jsonCache = jsonCache;
    _mode = mode;
    _sdkKey = sdkKey;

    _urlIsCustom = options.baseUrl.isNotEmpty;
    _url = _urlIsCustom
        ? options.baseUrl
        : options.dataGovernance == DataGovernance.global
            ? globalBaseUrl
            : euOnlyBaseUrl;

    _client = Dio(BaseOptions(
        connectTimeout: options.connectTimeout.inMilliseconds,
        receiveTimeout: options.receiveTimeout.inMilliseconds,
        sendTimeout: options.sendTimeout.inMilliseconds,
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 600)));

    if (options.httpClientAdapter != null) {
      _client.httpClientAdapter = options.httpClientAdapter!;
    }

    if (options.proxyUrl.isNotEmpty &&
        _client.httpClientAdapter is DefaultHttpClientAdapter) {
      (_client.httpClientAdapter as DefaultHttpClientAdapter)
          .onHttpClientCreate = (client) {
        client.findProxy = (uri) {
          return 'PROXY ${options.proxyUrl}';
        };
      };
    }
  }

  /// Gets the underlying [Dio] client.
  @override
  Dio get client {
    return _client;
  }

  /// Fetches the current ConfigCat configuration json.
  @override
  Future<FetchResponse> fetchConfiguration() {
    // ensure fetch requests are not initiated simultaneously
    return syncFuture(() => _executeFetch(2));
  }

  /// Closes the underlying http connection.
  @override
  void close() {
    _client.close();
  }

  Future<FetchResponse> _executeFetch(int executionCount) async {
    final response = await _doFetch();

    final preferences = response.config.preferences;
    if (!response.isFetched || preferences == null) {
      return response;
    }

    if (_urlIsCustom && preferences.redirect != _RedirectMode.forceRedirect) {
      return response;
    }

    _url = preferences.baseUrl;

    if (preferences.redirect == _RedirectMode.noRedirect) {
      return response;
    } else {
      if (preferences.redirect == _RedirectMode.shouldRedirect) {
        _logger.warning(
            'Your \'dataGovernance\' parameter at ConfigCatClient initialization is not in sync with your preferences on the ConfigCat Dashboard: https://app.configcat.com/organization/data-governance. Only Organization Admins can access this preference.');
      }

      if (executionCount > 0) {
        return await _executeFetch(executionCount - 1);
      }
    }

    _logger.error(
        'Redirect loop during config.json fetch. Please contact support@configcat.com.');
    return response;
  }

  Future<FetchResponse> _doFetch() async {
    final cache = await _jsonCache.readCache();
    Map<String, String> headers = {
      _userAgentHeaderName: 'ConfigCat-Dart/$_mode-$version',
      if (cache.eTag.isNotEmpty) _ifNoneMatchHeaderName: cache.eTag
    };

    try {
      final response = await _client.get(
        '$_url/configuration-files/$_sdkKey/$configJsonName',
        options: Options(headers: headers),
      );

      if (_successStatusCodes.contains(response.statusCode)) {
        final eTag = response.headers.value(_eTagHeaderName) ?? '';
        final config =
            await _jsonCache.readFromJson(response.data.toString(), eTag);
        if (config == Config.empty) {
          return FetchResponse.failure();
        }

        _logger.debug('Fetch was successful: new config fetched.');
        return FetchResponse.success(config);
      } else if (response.statusCode == 304) {
        _logger.debug('Fetch was successful: config not modified.');
        return FetchResponse.notModified();
      } else {
        _logger.error(
            'Double-check your API KEY at https://app.configcat.com/apikey. Received unexpected response: ${response.statusCode}');
        return FetchResponse.failure();
      }
    } catch (e, s) {
      _logger.error('Exception occurred during fetching.', e, s);
      return FetchResponse.failure();
    }
  }
}
