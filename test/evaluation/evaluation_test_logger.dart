import 'package:configcat_client/src/log/logger.dart';

class EvaluationTestLogger implements Logger {
  List<LogEvent> _logs = List<LogEvent>.empty(growable: true);

  final Map<LogLevel, String> _levelMap = {
    LogLevel.debug: "DEBUG",
    LogLevel.warning: "WARNING",
    LogLevel.info: "INFO",
    LogLevel.error: "ERROR",
  };

  @override
  void close() {}

  @override
  void debug(message, [error, StackTrace? stackTrace]) {
    _addLog(LogLevel.debug, message);
  }

  @override
  void error(message, [error, StackTrace? stackTrace]) {
    _addLog(LogLevel.error, message);
  }

  @override
  void info(message, [error, StackTrace? stackTrace]) {
    _addLog(LogLevel.info, message);
  }

  @override
  void warning(message, [error, StackTrace? stackTrace]) {
    _addLog(LogLevel.warning, message);
  }

  void _addLog(LogLevel logLevel, String message) {
    _logs.add(LogEvent(logLevel, _enrichMessage(logLevel, message)));
  }

  List<LogEvent> getLogList() {
    return _logs;
  }

  String _enrichMessage(LogLevel logLevel, String message) {
    return "${_levelMap[logLevel]} $message";
  }

  void reset() {
    _logs = List<LogEvent>.empty(growable: true);
  }
}

class LogEvent {
  final LogLevel logLevel;
  final String message;

  LogEvent(this.logLevel, this.message);
}
