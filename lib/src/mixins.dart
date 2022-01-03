import 'dart:async';

/// This mixin can be used to ensure that an asynchronous operation couldn't be
/// initiated multiple times simultaneously. Each caller will wait for the
/// first operation to be completed.
mixin ContinuousFutureSynchronizer<T> {
  Future<T>? _future;

  /// Ensure [futureToSync] is not executed multiple times simultaneously.
  Future<T> syncFuture(Future<T> Function() futureToSync) async {
    // operation is already running
    if (this._future != null) {
      // wait for the completer's result
      final result = await this._future!;
      return result;
    }

    // first call, create completer and save it's future for other callers
    final completer = new Completer<T>();
    this._future = completer.future;

    // wait for the operation to finish
    final result = await futureToSync();

    // operation finished, give result to everybody else except the first caller
    completer.complete(result);
    this._future = null;

    // give result to the first caller
    return result;
  }
}

/// This mixin can be used to set a one time timeout before invoking a
/// given operation.
mixin TimedInitializer<T> {
  final Completer<Null> _initial = new Completer();
  Future<Null>? _timeoutFuture;

  /// Invokes [futureToSync] after [initialized] is called or
  /// when the given [timeout] expires.
  Future<T> syncFuture(Future<T> Function() futureToSync, Duration timeout,
      {Function()? onTimeout = null}) async {
    // if the result we waited for is completed or timed out, simply
    // invoke the given operation.
    if (this._initial.isCompleted) {
      return futureToSync();
    }

    // if we are still waiting for the result, set the current caller to wait
    if (this._timeoutFuture != null) {
      await this._timeoutFuture;
      return futureToSync();
    }

    // very first call, set timeout
    this._timeoutFuture = this._initial.future.timeout(timeout, onTimeout: () {
      onTimeout?.call();
      return null;
    });

    // very first call, await for result or time-out
    await this._timeoutFuture;
    return futureToSync();
  }

  void initialized() {
    if (!this._initial.isCompleted) {
      this._initial.complete(null);
    }
  }
}
