import 'dart:async';

class PeriodicExecutor {
  final Future<void> Function() _task;
  final Duration _interval;
  final Completer<void> _canceller = Completer();

  CancellableDelayed? _delayed;

  bool _isCancelled = false;

  PeriodicExecutor(this._task, this._interval) {
    scheduleMicrotask(_execute);
  }

  void cancel() {
    if (!_canceller.isCompleted) {
      _canceller.complete();
    }
    _isCancelled = true;
    _delayed?.cancel();
  }

  Future<void> _execute() async {
    try {
      while (!_isCancelled) {
        await _task.call();
        await _delay(_interval);
      }
    } finally {
      if (!_isCancelled) {
        scheduleMicrotask(_execute);
      }
    }
  }

  Future<void> _delay(Duration duration) {
    final delayed = _delayed = CancellableDelayed(duration);
    return Future.any([delayed.future, _canceller.future]);
  }
}

class CancellableDelayed {
  final Completer<void> _completer = Completer();
  late final Timer? _timer;

  bool _isCompleted = false;
  bool _isCanceled = false;

  Future<void> get future => _completer.future;

  CancellableDelayed(Duration delay) {
    _timer = Timer(delay, _complete);
  }

  void cancel() {
    if (!_isCompleted && !_isCanceled) {
      _timer?.cancel();
      _isCanceled = true;
      _completer.complete();
    }
  }

  void _complete() {
    if (!_isCompleted && !_isCanceled) {
      _isCompleted = true;
      _completer.complete();
    }
  }
}
