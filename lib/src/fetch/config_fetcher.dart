import 'dart:async';
import 'package:configcat_client/src/errors.dart';
import 'package:configcat_client/src/platform_spec/request_builder.dart';
import 'package:http/http.dart' as http;

import '../utils.dart';
import '../error_reporter.dart';
import '../entry.dart';
import '../data_governance.dart';
import '../configcat_options.dart';
import '../constants.dart';
import '../json/config.dart';
import '../log/configcat_logger.dart';
import '../configcat_log_messages.dart';

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
  final String? cfRayId;
  final RefreshErrorCode errorCode;
  final Object? errorObject;
  final bool shouldRetry;

  FetchResponse._(this._status, this.entry, this.error, this.isTransientError,
      this.cfRayId, this.errorCode, this.errorObject, this.shouldRetry);

  bool get isFetched {
    return _status == _Status.fetched;
  }

  bool get isNotModified {
    return _status == _Status.notModified;
  }

  bool get isFailed {
    return _status == _Status.failure;
  }

  factory FetchResponse.success(Entry entry, String? cfRayId) {
    return FetchResponse._(_Status.fetched, entry, null, false, cfRayId,
        RefreshErrorCode.none, null, false);
  }

  factory FetchResponse.failure(
      String error,
      bool isTransientError,
      String? cfRayId,
      RefreshErrorCode errorCode,
      Object? errorObject,
      bool shouldRetry) {
    return FetchResponse._(_Status.failure, Entry.empty, error,
        isTransientError, cfRayId, errorCode, errorObject, shouldRetry);
  }

  factory FetchResponse.notModified(String? cfRayId) {
    return FetchResponse._(_Status.notModified, Entry.empty, null, false,
        cfRayId, RefreshErrorCode.none, null, false);
  }
}

class ConfigFetcher {
  static const globalBaseUrl = 'https://cdn-global.configcat.com';
  static const euOnlyBaseUrl = 'https://cdn-eu.configcat.com';
  static const _retryDelay = Duration(milliseconds: 50);

  late final ConfigCatLogger _logger;
  late final ConfigCatOptions _options;
  late final ErrorReporter _errorReporter;
  late final String _sdkKey;

  late final bool _urlIsCustom;
  late final http.Client _httpClient;
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

    _httpClient = options.httpClient ?? http.Client();
  }

  /// Fetches the current ConfigCat configuration json.
  Future<FetchResponse> fetchConfiguration(String eTag) {
    return _executeFetch(2, eTag);
  }

  /// Closes the underlying http connection.
  void close() {
    _httpClient.close();
  }

  Future<FetchResponse> _executeFetch(int executionCount, String eTag) async {
    final response = await _doFetchWithRetry(eTag);

    final preferences = response.entry.config.preferences;

    if (!response.isFetched) {
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
        _logger.warning(
            3002, ConfigCatLogMessages.dataGovernanceIsOutOfSyncWarn);
      }

      if (executionCount > 0) {
        return await _executeFetch(executionCount - 1, eTag);
      }
    }

    _logger.error(1104,
        ConfigCatLogMessages.getFetchFailedDueToRedirectLoop(response.cfRayId));
    return response;
  }

  Future<FetchResponse> _doFetchWithRetry(String eTag) async {
    final response = await _doFetch(eTag);
    if (response.shouldRetry) {
      await Future.delayed(_retryDelay);
      return await _doFetch(eTag);
    }
    return response;
  }

  Future<FetchResponse> _doFetch(String eTag) async {
    String? cfRayId;
    try {
      final request = RequestBuilder.build(
          'ConfigCat-Dart/${_options.pollingMode.getPollingIdentifier()}-$version',
          eTag);
      final url =
          Uri.parse('$_url/configuration-files/$_sdkKey/$configJsonName')
              .replace(queryParameters: request.queryParams);
      final response = await _httpClient
          .get(url, headers: request.headers)
          .timeout(_options.requestTimeout);
      cfRayId = response.headers[cfRayHeaderName];

      if (response.statusCode == 200) {
        final eTag = response.headers[eTagHeaderName] ?? '';
        final configJson = response.body;
        Config config;
        try {
          config = Utils.deserializeConfig(configJson);
        } catch (e) {
          String error =
              ConfigCatLogMessages.getFetchReceived200WithInvalidBodyError(
                  cfRayId);
          _errorReporter.error(1105, error);
          return FetchResponse.failure(error, true, cfRayId,
              RefreshErrorCode.invalidHttpResponseContent, e, false);
        }
        _logger.debug('Fetch was successful: new config fetched.');
        return FetchResponse.success(
            Entry(configJson, config, eTag, DateTime.now().toUtc()), cfRayId);
      } else if (response.statusCode == 304) {
        _logger.debug('Fetch was successful: config not modified.');
        return FetchResponse.notModified(cfRayId);
      } else if (response.statusCode == 404 || response.statusCode == 403) {
        final error =
            ConfigCatLogMessages.getFetchFailedDueToInvalidSDKKey(cfRayId);
        _errorReporter.error(1100, error);
        return FetchResponse.failure(
            error, false, cfRayId, RefreshErrorCode.invalidSdkKey, null, false);
      } else {
        final error =
            ConfigCatLogMessages.getFetchFailedDueToUnexpectedHttpResponse(
                response.statusCode, response.reasonPhrase, cfRayId);
        _errorReporter.error(1101, error);
        return FetchResponse.failure(error, true, cfRayId,
            RefreshErrorCode.unexpectedHttpResponse, null, true);
      }
    } on TimeoutException catch (e, s) {
      final error = ConfigCatLogMessages.getFetchFailedDueToRequestTimeout(
          _options.requestTimeout.inMilliseconds, cfRayId);
      _errorReporter.error(1102, error, e, s);
      return FetchResponse.failure(
          error, true, cfRayId, RefreshErrorCode.httpRequestTimeout, e, true);
    } catch (e, s) {
      _errorReporter.error(
          1103,
          ConfigCatLogMessages.getFetchFailedDueToUnexpectedError(cfRayId),
          e,
          s);
      return FetchResponse.failure(e.toString(), true, cfRayId,
          RefreshErrorCode.httpRequestFailure, e, true);
    }
  }
}
