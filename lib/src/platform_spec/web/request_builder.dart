import 'package:dio/dio.dart';

class ActualRequestBuilder {
  static const _sdkInfoName = 'sdk';
  static const _ccEtagName = 'ccetag';

  ActualRequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    Map<String, String> queryParams = {
      _sdkInfoName: sdkInfo,
      if (etag.isNotEmpty) _ccEtagName: etag
    };

    return RequestOptions(queryParameters: queryParams);
  }
}
