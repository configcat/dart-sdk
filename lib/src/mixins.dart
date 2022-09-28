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
  CancellableDelayed? _delayed;

  void startPeriodic(Duration interval, Future<void> Function() task) {
    if (_canceller != null) return;
    _canceller = Completer<void>();
    _task = task;
    _interval = interval;
    scheduleMicrotask(_execute);
  }

  void cancelPeriodic() {
    if (!(_canceller?.isCompleted ?? true)) {
      _canceller?.complete();
      _canceller = null;
    }
    _delayed?.cancel();
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

  Future<void> _delay(Duration duration) {
    final delayed = _delayed = CancellableDelayed(duration);
    return Future.any([delayed.future, _canceller?.future ?? Future.value()]);
  }
}

class CancellableDelayed {
  final Completer<bool> _completer = Completer();
  late final Timer? _timer;

  bool _isCompleted = false;
  bool _isCanceled = false;

  Future<bool> get future => _completer.future;

  CancellableDelayed(Duration delay) {
    _timer = Timer(delay, _complete);
  }

  void cancel() {
    if (!_isCompleted && !_isCanceled) {
      _timer?.cancel();
      _isCanceled = true;
      _completer.complete(false);
    }
  }

  void _complete() {
    if (!_isCompleted && !_isCanceled) {
      _isCompleted = true;
      _completer.complete(true);
    }
  }
}
