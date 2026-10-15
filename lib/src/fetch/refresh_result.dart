import 'package:configcat_client/src/errors.dart';

/// Represents the result of a forceRefresh() call.
class RefreshResult {
  final bool isSuccess;
  final String? error;
  final Object? errorObject;
  final RefreshErrorCode errorCode;

  RefreshResult(this.isSuccess, this.error, this.errorCode, [this.errorObject]);
}
