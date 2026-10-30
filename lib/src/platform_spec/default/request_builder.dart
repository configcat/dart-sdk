import '../../constants.dart';
import '../request_builder.dart';

class ActualRequestBuilder {
  ActualRequestBuilder._();

  static RequestOptions build(String sdkInfo, String etag) {
    return RequestOptions(headers: {
      userAgentHeaderName: sdkInfo,
      if (etag.isNotEmpty) ifNoneMatchHeaderName: etag
    });
  }
}
