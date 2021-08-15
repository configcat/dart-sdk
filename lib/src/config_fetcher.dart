import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

const configJsonName = 'config_v5';

enum Status { fetched, notModified, failure }
enum RedirectMode { noRedirect, shouldRedirect, forceRedirect }

class FetchResponse {
  late final Status _status;
  late final String body;

  bool get isFetched {
    return _status == Status.fetched;
  }

  bool get isNotModified {
    return _status == Status.notModified;
  }

  bool get isFailed {
    return _status == Status.failure;
  }
}

class ConfigFetcher {
  static const _version = "7.2.0";
  final Logger log;
  final String etag = "";
  final String mode;
  final String sdkKey;
  late final bool urlIsCustom;
  late final String url;

  ConfigFetcher({
    required this.log,
    required this.sdkKey,
    required this.mode,
    required dataGovernance,
    baseUrl = "",
  }) {
    this.urlIsCustom = !baseUrl.isEmpty;
    this.url = baseUrl.isEmpty ? dataGovernance.url : baseUrl;
  }

  Future<FetchResponse> fetchConfigurationJson() {
    return _executeFetch(executionCount: 2);
  }

  Future<FetchResponse> _executeFetch({int executionCount = 1}) async {
    Map<String, String> headers = {
      'X-ConfigCat-UserAgent': 'ConfigCat-Dart/$mode-$_version',
    };

    if (!etag.isEmpty) {
      headers['If-None-Match'] = etag;
    }

    final response = await http.get(
      Uri.parse('$url/configuration-files/$sdkKey/$configJsonName.json'),
      headers: headers,
    );

    return FetchResponse();
  }
}
