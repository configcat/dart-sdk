import '../configcat_client.dart';
import 'default_logger.dart';

import 'logger.dart';

/// Logger used by [ConfigCatClient].
class ConfigCatLogger {
  late final Logger _internal;
  late final LogLevel _globalLevel;
  bool _isClosed = false;

  ConfigCatLogger({
    Logger? internalLogger,
    LogLevel? level,
  }) {
    _globalLevel = level ?? LogLevel.warning;
    _internal = internalLogger ?? DefaultLogger();
  }

  void debug(message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.debug.index >= _globalLevel.index && !_isClosed) {
      _internal.debug("ConfigCat - [0] $message", error, stackTrace);
    }
  }

  void error(int eventId, message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.error.index >= _globalLevel.index && !_isClosed) {
      _internal.error("ConfigCat - [$eventId] $message", error, stackTrace);
    }
  }

  void info(int eventId, message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.info.index >= _globalLevel.index && !_isClosed) {
      _internal.info("ConfigCat - [$eventId] $message", error, stackTrace);
    }
  }

  void warning(int eventId, message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.warning.index >= _globalLevel.index && !_isClosed) {
      _internal.warning("ConfigCat - [$eventId] $message", error, stackTrace);
    }
  }

  void close() {
    _isClosed = true;
    _internal.close();
  }
}
