import 'package:dio/dio.dart';

import 'default/request_builder.dart'
    if (dart.library.html) 'web/request_builder.dart';

class RequestBuilder {
  RequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    return ActualRequestBuilder.build(sdkInfo, etag);
  }
}
