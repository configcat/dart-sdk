import 'log/configcat_logger.dart';
import 'configcat_options.dart';

class ErrorReporter {
  final ConfigCatLogger _logger;
  final Hooks _hooks;

  ErrorReporter(this._logger, this._hooks);

  void error(message, [dynamic error, StackTrace? stackTrace]) {
    _logger.error(message, error, stackTrace);
    _hooks.invokeError(message, error, stackTrace);
  }
}
