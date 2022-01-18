/// Defines levels to control logging verbosity.
enum LogLevel {
  debug,
  info,
  warning,
  error,
  nothing,
}

/// Describes a logger used by [ConfigCatLogger].
abstract class Logger {
  /// Log a message at level [LogLevel.debug].
  void debug(dynamic message, [dynamic error, StackTrace? stackTrace]);

  /// Log a message at level [LogLevel.info].
  void info(dynamic message, [dynamic error, StackTrace? stackTrace]);

  /// Log a message at level [LogLevel.warning].
  void warning(dynamic message, [dynamic error, StackTrace? stackTrace]);

  /// Log a message at level [LogLevel.error].
  void error(dynamic message, [dynamic error, StackTrace? stackTrace]);

  /// Closes the logger.
  void close();
}
