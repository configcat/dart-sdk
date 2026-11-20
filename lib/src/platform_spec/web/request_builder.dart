import '../request_builder.dart';

class ActualRequestBuilder {
  ActualRequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    return RequestOptions(
        queryParams: {'sdk': sdkInfo, if (etag.isNotEmpty) 'ccetag': etag});
  }
}
