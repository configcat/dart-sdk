import 'package:configcat_client/src/override/behaviour.dart';

/// Specifies the possible evaluation error codes.
enum EvaluationErrorCode {
  /// An unexpected error occurred during the evaluation.
  unexpectedError(-1),

  /// No error occurred (the evaluation was successful).
  none(0),

  /// The evaluation failed because of an error in the config model.
  /// (Most likely, invalid data was passed to the SDK via flag overrides.)
  invalidConfigModel(1),

  /// The evaluation failed because of a type mismatch between the evaluated
  /// setting value and the specified default value.
  settingValueTypeMismatch(2),

  /// The evaluation failed because the config JSON was not available locally.
  configJsonNotAvailable(1000),

  /// The evaluation failed because the key of the evaluated setting was not found in
  /// the config JSON.
  settingKeyMissing(1001);

  const EvaluationErrorCode(this.value);
  final int value;
}

/// Specifies the possible config data refresh error codes.
enum RefreshErrorCode {
  /// An unexpected error occurred during the refresh operation.
  unexpectedError(-1),

  /// No error occurred (the refresh operation was successful).
  none(0),

  /// The refresh operation failed because the client is configured to use the [OverrideBehaviour.localOnly]
  /// override behavior, which prevents synchronization with the external cache and making HTTP requests.
  localOnlyClient(1),

  /// The refresh operation failed because an HTTP response indicating an
  /// invalid SDK Key was received (403 Forbidden or 404 Not Found).
  invalidSdkKey(1100),

  /// The refresh operation failed because an invalid HTTP response was received (unexpected HTTP status code).
  unexpectedHttpResponse(1101),

  /// The refresh operation failed because the HTTP request timed out.
  httpRequestTimeout(1102),

  /// The refresh operation failed because the HTTP request failed (most likely due to a local network issue).
  httpRequestFailure(1103),

  /// The refresh operation failed because an invalid HTTP response was received (200 OK with invalid content).
  invalidHttpResponseContent(1105),

  /// The refresh operation failed because the client is in offline mode and cannot initiate HTTP requests.
  offlineClient(3200),

  /// Client initialization could not complete within `maxInitWaitTimeSeconds`.
  clientInitTimeout(4200);

  const RefreshErrorCode(this.value);
  final int value;
}

abstract class HasMessage {
  String get message;
}

class EvaluationError extends Error implements HasMessage {
  @override
  final String message;
  final String? messageToLog;
  final EvaluationErrorCode errorCode;
  final int? eventId;

  EvaluationError(
      {required this.message,
      this.messageToLog,
      required this.errorCode,
      this.eventId});

  @override
  String toString() => message;
}

class InvalidConfigModelError extends Error implements HasMessage {
  @override
  final String message;

  InvalidConfigModelError(this.message);

  @override
  String toString() => message;
}

EvaluationErrorCode errorCodeFrom(Object e) {
  if (e is EvaluationError) return e.errorCode;
  if (e is InvalidConfigModelError) {
    return EvaluationErrorCode.invalidConfigModel;
  }
  return EvaluationErrorCode.unexpectedError;
}
