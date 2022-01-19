import 'package:logger/logger.dart' as ext;

import 'logger.dart';

/// Default [Logger] implementation used by [ConfigCatLogger].
class DefaultLogger implements Logger {
  late final ext.Logger _internal;

  DefaultLogger({
    ext.Logger? internalLogger,
  }) {
    _internal = internalLogger ??
        ext.Logger(
            level: ext.Level.verbose,
            filter: ext.ProductionFilter(),
            printer: ext.SimplePrinter(printTime: true));
  }

  @override
  void debug(message, [dynamic error, StackTrace? stackTrace]) {
    _internal.d(message, error, stackTrace);
  }

  @override
  void error(message, [dynamic error, StackTrace? stackTrace]) {
    _internal.e(message, error, stackTrace);
  }

  @override
  void info(message, [dynamic error, StackTrace? stackTrace]) {
    _internal.i(message, error, stackTrace);
  }

  @override
  void warning(message, [dynamic error, StackTrace? stackTrace]) {
    _internal.w(message, error, stackTrace);
  }

  @override
  void close() {
    _internal.close();
  }
}
