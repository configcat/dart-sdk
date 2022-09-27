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

mixin PeriodicExecutor {
  Completer<void>? _canceller;
  Future<void> Function()? _task;
  Duration _interval = const Duration(seconds: 1);

  void startPeriodic(Duration interval, Future<void> Function() task) {
    if (_canceller != null) return;
    _canceller = Completer<void>();
    _task = task;
    _interval = interval;
    scheduleMicrotask(_execute);
  }

  void cancelPeriodic() {
    if ((_canceller?.isCompleted ?? true)) return;
    _canceller?.complete();
    _canceller = null;
  }

  Future<void> _execute() async {
    try {
      while (!(_canceller?.isCompleted ?? true)) {
        await _task?.call();
        await _delay(_interval);
      }
    } finally {
      if (!(_canceller?.isCompleted ?? true)) {
        scheduleMicrotask(_execute);
      }
    }
  }

  Future<void> _delay(Duration duration) => Future.any(
      [Future.delayed(duration), _canceller?.future ?? Future.value()]);
}
