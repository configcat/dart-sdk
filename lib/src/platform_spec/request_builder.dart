import 'default/request_builder.dart'
    if (dart.library.html) 'web/request_builder.dart';

class RequestOptions {
  final Map<String, String>? headers;
  final Map<String, String>? queryParams;

  RequestOptions({this.headers, this.queryParams});
}

class RequestBuilder {
  RequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    return ActualRequestBuilder.build(sdkInfo, etag);
  }
}
