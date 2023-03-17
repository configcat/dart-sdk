import 'log/configcat_logger.dart';
import 'configcat_options.dart';

class ErrorReporter {
  final ConfigCatLogger _logger;
  final Hooks _hooks;

  ErrorReporter(this._logger, this._hooks);

  void error(int eventId, message, [dynamic error, StackTrace? stackTrace]) {
    _logger.error(eventId, message, error, stackTrace);
    _hooks.invokeError(message, error, stackTrace);
  }
}
