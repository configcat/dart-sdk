import '../configcat_client.dart';
import 'default_logger.dart';

import 'logger.dart';

/// Logger used by [ConfigCatClient].
class ConfigCatLogger {
  late final Logger _internal;
  late final LogLevel _globalLevel;

  ConfigCatLogger({
    Logger? logger,
    LogLevel? level,
  }) {
    _globalLevel = level ?? LogLevel.warning;
    _internal = logger ?? DefaultLogger();
  }

  void debug(message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.debug.index >= this._globalLevel.index) {
      this._internal.debug("ConfigCat - $message", error, stackTrace);
    }
  }

  void error(message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.error.index >= this._globalLevel.index) {
      this._internal.error("ConfigCat - $message", error, stackTrace);
    }
  }

  void info(message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.info.index >= this._globalLevel.index) {
      this._internal.info("ConfigCat - $message", error, stackTrace);
    }
  }

  void warning(message, [dynamic error, StackTrace? stackTrace]) {
    if (LogLevel.warning.index >= this._globalLevel.index) {
      this._internal.warning("ConfigCat - $message", error, stackTrace);
    }
  }

  void close() {
    this._internal.close();
  }
}
