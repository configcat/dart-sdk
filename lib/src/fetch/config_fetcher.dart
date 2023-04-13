import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../error_reporter.dart';
import '../json/entry.dart';
import '../data_governance.dart';
import '../configcat_options.dart';
import '../json/config.dart';
import '../constants.dart';
import '../log/configcat_logger.dart';

enum _Status { fetched, notModified, failure }

class _RedirectMode {
  static const int noRedirect = 0;
  static const int shouldRedirect = 1;
  static const int forceRedirect = 2;
}

class FetchResponse {
  final _Status _status;
  final Entry entry;
  final String? error;
  final bool isTransientError;

  FetchResponse._(this._status, this.entry, this.error, this.isTransientError);

  bool get isFetched {
    return _status == _Status.fetched;
  }

  bool get isNotModified {
    return _status == _Status.notModified;
  }

  bool get isFailed {
    return _status == _Status.failure;
  }

  factory FetchResponse.success(Entry entry) {
    return FetchResponse._(_Status.fetched, entry, null, false);
  }

  factory FetchResponse.failure(String error, bool isTransientError) {
    return FetchResponse._(
        _Status.failure, Entry.empty, error, isTransientError);
  }

  factory FetchResponse.notModified() {
    return FetchResponse._(_Status.notModified, Entry.empty, null, false);
  }
}

abstract class Fetcher {
  Dio get httpClient;

  Future<FetchResponse> fetchConfiguration(String eTag);

  void close();
}

class ConfigFetcher implements Fetcher {
  static const globalBaseUrl = 'https://cdn-global.configcat.com';
  static const euOnlyBaseUrl = 'https://cdn-eu.configcat.com';
  static const _userAgentHeaderName = 'X-ConfigCat-UserAgent';
  static const _ifNoneMatchHeaderName = 'If-None-Match';
  static const _eTagHeaderName = 'Etag';
  static const _successStatusCodes = [200, 201, 202, 203, 204];

  late final ConfigCatLogger _logger;
  late final ConfigCatOptions _options;
  late final ErrorReporter _errorReporter;
  late final String _sdkKey;

  late final bool _urlIsCustom;
  late final Dio _httpClient;
  late String _url;

  ConfigFetcher(
      {required ConfigCatLogger logger,
      required String sdkKey,
      required ConfigCatOptions options,
      required ErrorReporter errorReporter}) {
    _logger = logger;
    _sdkKey = sdkKey;
    _options = options;
    _errorReporter = errorReporter;

    _urlIsCustom = options.baseUrl.isNotEmpty;
    _url = _urlIsCustom
        ? options.baseUrl
        : options.dataGovernance == DataGovernance.global
            ? globalBaseUrl
            : euOnlyBaseUrl;

    _httpClient = Dio(BaseOptions(
        connectTimeout: options.connectTimeout,
        receiveTimeout: options.receiveTimeout,
        sendTimeout: options.sendTimeout,
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && (status >= 200 && status < 600)));

    if (options.httpClientAdapter != null) {
      _httpClient.httpClientAdapter = options.httpClientAdapter!;
    }
  }

  /// Gets the underlying [Dio] HTTP client.
  @override
  Dio get httpClient {
    return _httpClient;
  }

  /// Fetches the current ConfigCat configuration json.
  @override
  Future<FetchResponse> fetchConfiguration(String eTag) {
    return _executeFetch(2, eTag);
  }

  /// Closes the underlying http connection.
  @override
  void close() {
    _httpClient.close();
  }

  Future<FetchResponse> _executeFetch(int executionCount, String eTag) async {
    final response = await _doFetch(eTag);

    final preferences = response.entry.config.preferences;
    if (!response.isFetched || preferences == null) {
      return response;
    }

    if (preferences.baseUrl.isNotEmpty && _url == preferences.baseUrl) {
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
        _logger.warning(3002,
            'The `dataGovernance` parameter specified at the client initialization is not in sync with the preferences on the ConfigCat Dashboard. Read more: https://configcat.com/docs/advanced/data-governance/');
      }

      if (executionCount > 0) {
        return await _executeFetch(executionCount - 1, eTag);
      }
    }

    _logger.error(1104,
        'Redirection loop encountered while trying to fetch config JSON. Please contact us at https://configcat.com/support/');
    return response;
  }

  Future<FetchResponse> _doFetch(String eTag) async {
    Map<String, String> headers = {
      _userAgentHeaderName:
          'ConfigCat-Dart/${_options.pollingMode.getPollingIdentifier()}-$version',
      if (eTag.isNotEmpty) _ifNoneMatchHeaderName: eTag
    };

    try {
      final response = await _httpClient.get(
        '$_url/configuration-files/$_sdkKey/$configJsonName',
        options: Options(headers: headers),
      );
      if (_successStatusCodes.contains(response.statusCode)) {
        final eTag = response.headers.value(_eTagHeaderName) ?? '';
        final decoded = jsonDecode(response.data.toString());
        final config = Config.fromJson(decoded);
        _logger.debug('Fetch was successful: new config fetched.');
        return FetchResponse.success(
            Entry(config, eTag, DateTime.now().toUtc()));
      } else if (response.statusCode == 304) {
        _logger.debug('Fetch was successful: config not modified.');
        return FetchResponse.notModified();
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        final error =
            'Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey. Received unexpected response: ${response.statusCode} ${response.statusMessage}';
        _errorReporter.error(1100, error);
        return FetchResponse.failure(error, false);
      } else {
        final error =
            'Unexpected HTTP response was received while trying to fetch config JSON: ${response.statusCode} ${response.statusMessage}';
        _errorReporter.error(1101, error);
        return FetchResponse.failure(error, true);
      }
    } on DioError catch (e, s) {
      if (e.type == DioErrorType.connectionTimeout ||
          e.type == DioErrorType.receiveTimeout ||
          e.type == DioErrorType.sendTimeout) {
        final error =
            'Request timed out while trying to fetch config JSON. Timeout values: [connect: ${_options.connectTimeout.inSeconds}s, receive: ${_options.receiveTimeout.inSeconds}s, send: ${_options.sendTimeout.inSeconds}s]';
        _errorReporter.error(1102, error, e, s);
        return FetchResponse.failure(error, true);
      }
      _errorReporter.error(1103,
          'Unexpected error occurred while trying to fetch config JSON.', e, s);
      return FetchResponse.failure(e.toString(), true);
    } catch (e, s) {
      _errorReporter.error(1103,
          'Unexpected error occurred while trying to fetch config JSON.', e, s);
      return FetchResponse.failure(e.toString(), true);
    }
  }
}
