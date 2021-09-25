import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

import 'config_cat_client.dart';

const configJsonName = 'config_v5';

enum Status { fetched, notModified, failure }
enum RedirectMode { noRedirect, shouldRedirect, forceRedirect }

class FetchResponse {
  late Status status;
  final String body;

  FetchResponse(int statusCode, this.body) {
    if (statusCode >=200 && statusCode < 300) {
      this.status = Status.fetched;
    } else if (statusCode == 304) {
      this.status = Status.notModified;
    } else {
      this.status = Status.failure;
    }
  }

  bool get isFetched {
    return status == Status.fetched;
  }

  bool get isNotModified {
    return status == Status.notModified;
  }

  bool get isFailed {
    return status == Status.failure;
  }
}

class ConfigFetcher {
  static const _version = "7.2.0";
  final Logger log;
  late String etag = "";
  final String mode;
  final String sdkKey;
  late final bool urlIsCustom;
  late final String url;

  ConfigFetcher({
    required this.log,
    required this.sdkKey,
    required this.mode,
    required DataGovernance dataGovernance,
    baseUrl = "",
  }) {
    this.urlIsCustom = !baseUrl.isEmpty;
    this.url = baseUrl.isEmpty ? dataGovernance.url : baseUrl;
  }

  Future<FetchResponse> fetchConfigurationJson(http.Client client) {
    return _executeFetch(client, executionCount: 2);
  }

  Future<FetchResponse> _executeFetch(http.Client client, {int executionCount = 1}) async {
    Map<String, String> headers = {
      'X-ConfigCat-UserAgent': 'ConfigCat-Dart/$mode-$_version',
    };

    if (!etag.isEmpty) {
      headers['If-None-Match'] = etag;
    }

    final response = await client.get(
      Uri.parse('$url/configuration-files/$sdkKey/$configJsonName.json'),
      headers: headers,
    );

    if (response.headers['Etag'] != null) {
      etag = response.headers['Etag']!;
    }

    return FetchResponse(response.statusCode, response.body);
  }
}
