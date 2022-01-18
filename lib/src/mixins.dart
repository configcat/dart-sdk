import 'dart:async';

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

/// This mixin can be used to set a one time timeout before invoking a
/// given operation.
mixin TimedInitializer<T> {
  final Completer<void> _initial = Completer();
  Future<void>? _timeoutFuture;

  /// Invokes [futureToSync] after [initialized] is called or
  /// when the given [timeout] expires.
  Future<T> syncFuture(Future<T> Function() futureToSync, Duration timeout,
      {Function()? onTimeout}) async {
    // if the result we waited for is completed or timed out, simply
    // invoke the given operation.
    if (_initial.isCompleted) {
      return futureToSync();
    }

    // if we are still waiting for the result, set the current caller to wait
    if (_timeoutFuture != null) {
      await _timeoutFuture;
      return futureToSync();
    }

    // very first call, set timeout
    _timeoutFuture = _initial.future.timeout(timeout, onTimeout: () {
      onTimeout?.call();
      return null;
    });

    // very first call, await for result or time-out
    await _timeoutFuture;
    return futureToSync();
  }

  void initialized() {
    if (!_initial.isCompleted) {
      _initial.complete(null);
    }
  }
}
