import 'package:dio/dio.dart';

class ActualRequestBuilder {
  static const _userAgentHeaderName = 'X-ConfigCat-UserAgent';
  static const _ifNoneMatchHeaderName = 'If-None-Match';

  ActualRequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    Map<String, String> headers = {
      _userAgentHeaderName: sdkInfo,
      if (etag.isNotEmpty) _ifNoneMatchHeaderName: etag
    };

    return RequestOptions(headers: headers);
  }
}
