import 'logger.dart';

/// Default [Logger] implementation used by [ConfigCatLogger].
class DefaultLogger implements Logger {
  @override
  void debug(message, [dynamic error, StackTrace? stackTrace]) {
    _log("[DEBUG]", message, error, stackTrace);
  }

  @override
  void error(message, [dynamic error, StackTrace? stackTrace]) {
    _log("[ERROR]", message, error, stackTrace);
  }

  @override
  void info(message, [dynamic error, StackTrace? stackTrace]) {
    _log("[INFO]", message, error, stackTrace);
  }

  @override
  void warning(message, [dynamic error, StackTrace? stackTrace]) {
    _log("[WARN]", message, error, stackTrace);
  }

  @override
  void close() {}

  void _log(String prefix, dynamic message,
      [dynamic error, StackTrace? stackTrace]) {
    var err = error != null ? ' ERROR: $error' : '';
    print('$prefix ${DateTime.now().toIso8601String()}: $message$err');
  }
}
