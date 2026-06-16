import 'dart:async';
import 'dart:convert';
import 'package:configcat_client/src/platform_spec/request_builder.dart';
import 'package:dio/dio.dart';

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

  FetchResponse._(this._status, this.entry, this.error, this.isTransientError,
      this.cfRayId);

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
    return FetchResponse._(_Status.fetched, entry, null, false, cfRayId);
  }

  factory FetchResponse.failure(
      String error, bool isTransientError, String? cfRayId) {
    return FetchResponse._(
        _Status.failure, Entry.empty, error, isTransientError, cfRayId);
  }

  factory FetchResponse.notModified(String? cfRayId) {
    return FetchResponse._(
        _Status.notModified, Entry.empty, null, false, cfRayId);
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
  static const _eTagHeaderName = 'Etag';

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
        responseType: ResponseType.stream,
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

  Future<FetchResponse> _doFetch(String eTag) async {
    String? cfRayId;
    try {
      final request = RequestBuilder.build(
          'ConfigCat-Dart/${_options.pollingMode.getPollingIdentifier()}-$version',
          eTag);
      final response = await _httpClient.get(
          '$_url/configuration-files/$_sdkKey/$configJsonName',
          queryParameters: request.queryParameters,
          options: Options(headers: request.headers));
      cfRayId = response.headers.value("CF-RAY");

      if (response.statusCode == 200) {
        final eTag = response.headers.value(_eTagHeaderName) ?? '';
        final responseData = response.data;
        var configJson = '';
        if (responseData is ResponseBody) {
          configJson = await utf8.decoder.bind(responseData.stream).join();
        }
        Config config;
        try {
          config = Utils.deserializeConfig(configJson);
        } catch (e) {
          String error =
              ConfigCatLogMessages.getFetchReceived200WithInvalidBodyError(
                  cfRayId);
          _errorReporter.error(1105, error);
          return FetchResponse.failure(error, false, cfRayId);
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
        return FetchResponse.failure(error, false, cfRayId);
      } else {
        final error =
            ConfigCatLogMessages.getFetchFailedDueToUnexpectedHttpResponse(
                response.statusCode ?? 0,
                response.statusMessage.toString(),
                cfRayId);
        _errorReporter.error(1101, error);
        return FetchResponse.failure(error, true, cfRayId);
      }
    } on DioException catch (e, s) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        final error = ConfigCatLogMessages.getFetchFailedDueToRequestTimeout(
            _options.connectTimeout.inMilliseconds,
            _options.receiveTimeout.inMilliseconds,
            _options.sendTimeout.inMilliseconds,
            cfRayId);
        _errorReporter.error(1102, error, e, s);
        return FetchResponse.failure(error, true, cfRayId);
      }
      _errorReporter.error(
          1103,
          ConfigCatLogMessages.getFetchFailedDueToUnexpectedError(cfRayId),
          e,
          s);
      return FetchResponse.failure(e.toString(), true, cfRayId);
    } catch (e, s) {
      _errorReporter.error(
          1103,
          ConfigCatLogMessages.getFetchFailedDueToUnexpectedError(cfRayId),
          e,
          s);
      return FetchResponse.failure(e.toString(), true, cfRayId);
    }
  }
}
