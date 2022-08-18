import 'dart:async';
import 'dart:convert';

import 'json/config.dart';
import 'error_reporter.dart';

/// This mixin can be used to ensure that an asynchronous operation couldn't be
/// initiated multiple times simultaneously. Each caller will wait for the
/// first operation to be completed.
mixin ContinuousFutureSynchronizer<T> {
  Future<T>? _future;

  /// Ensure [futureToSync] is not executed multiple times simultaneously.
  Future<T> syncFuture(Future<T> Function() futureToSync) async {
    // operation is already running
    if (_future != null) {
      // wait for the completer's result
      final result = await _future!;
      return result;
    }

    // first call, create completer and save it's future for other callers
    final completer = Completer<T>();
    _future = completer.future;

    // wait for the operation to finish
    final result = await futureToSync();

    // operation finished, give result to everybody else except the first caller
    completer.complete(result);
    _future = null;

    // give result to the first caller
    return result;
  }
}

/// This mixin is used to deserialize [Config] from JSON.
mixin ConfigJsonParser {
  /// Parse [Config] from JSON.
  Config parseConfigFromJson(String json, ErrorReporter errorReporter) {
    try {
      final decoded = jsonDecode(json);
      return Config.fromJson(decoded);
    } catch (e, s) {
      errorReporter.error('Config JSON parsing failed.', e, s);
      return Config.empty;
    }
  }
}
