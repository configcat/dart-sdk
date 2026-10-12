import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:configcat_client/src/rollout_evaluator.dart';
import 'package:configcat_client/src/utils.dart';

import 'configcat_log_messages.dart';
import 'error_reporter.dart';
import 'evaluate_logger.dart';
import 'json/setting_type.dart';

class FlagEvaluator {
  final Hooks _hooks;
  final ErrorReporter _errorReporter;
  final RolloutEvaluator _rolloutEvaluator;
  final LogLevel _logLevel;

  FlagEvaluator(
      this._hooks, this._errorReporter, this._rolloutEvaluator, this._logLevel);

  EvaluationDetails<T> evaluate<T>(
      String key, ConfigCatUser? user, T defaultValue, SettingResult result) {
    try {
      if (result.isEmpty) {
        final err =
            ConfigCatLogMessages.getConfigJsonIsNotPresentedWithDefaultValue(
                key, "defaultValue", defaultValue);
        _errorReporter.error(1000, err);
        final details = EvaluationDetails.makeError(key, defaultValue, err,
            EvaluationErrorCode.configJsonNotAvailable, user);
        _hooks.invokeFlagEvaluated(details);
        return details;
      }
      final setting = result.settings[key];
      if (setting == null) {
        final err =
            ConfigCatLogMessages.getSettingEvaluationFailedDueToMissingKey(key,
                "defaultValue", defaultValue, result.settings.keys.toSet());
        _errorReporter.error(1001, err);
        final details = EvaluationDetails.makeError(key, defaultValue, err,
            EvaluationErrorCode.settingKeyMissing, user);
        _hooks.invokeFlagEvaluated(details);
        return details;
      }

      final eval = _eval(setting, key, user, result);
      final parsed = _parseSettingValue<T>(eval.value, setting.type);
      if (parsed.value != null) {
        final details =
            _produceEvalDetails(eval, parsed.value as T, key, user, result);
        _hooks.invokeFlagEvaluated(details);
        return details;
      } else {
        final err = parsed.error;
        _errorReporter.error(2002, err);
        final details = EvaluationDetails.makeError(key, defaultValue,
            err.toString(), EvaluationErrorCode.settingValueTypeMismatch, user);
        _hooks.invokeFlagEvaluated(details);
        return details;
      }
    } catch (e, s) {
      final err =
          ConfigCatLogMessages.getSettingEvaluationErrorWithDefaultValue(
              "getValueDetails", key, "defaultValue", defaultValue);
      _errorReporter.error(1002, err, e, s);
      final details = EvaluationDetails.makeError(key, defaultValue,
          e.toString(), EvaluationErrorCode.unexpectedError, user);
      _hooks.invokeFlagEvaluated(details);
      return details;
    }
  }

  EvaluationDetails<T> evaluateSetting<T>(
      String key, Setting setting, ConfigCatUser? user, SettingResult result) {
    final eval = _eval(setting, key, user, result);
    final parsed = _parseSettingValue<T>(eval.value, setting.type);
    if (parsed.value != null) {
      final details =
          _produceEvalDetails(eval, parsed.value as T, key, user, result);
      _hooks.invokeFlagEvaluated(details);
      return details;
    } else {
      throw ArgumentError(parsed.error);
    }
  }

  void validateReturnType<T>() {
    if (T != bool &&
        T != String &&
        T != int &&
        T != double &&
        T != Object &&
        !Utils.typesEqual<T, bool?>() &&
        !Utils.typesEqual<T, String?>() &&
        !Utils.typesEqual<T, int?>() &&
        !Utils.typesEqual<T, double?>() &&
        !Utils.typesEqual<T, Object?>() &&
        T != dynamic) {
      throw ArgumentError(
          "Only the following types are supported: $String, $bool, $int, $double, $Object (both nullable and non-nullable) and $dynamic.");
    }
  }

  T parseSettingValue<T>(SettingValue settingValue, int settingType) {
    final result = _parseSettingValue(settingValue, settingType);
    if (result.value != null) {
      return result.value;
    } else {
      throw ArgumentError(result.error);
    }
  }

  EvaluationResult _eval(
      Setting setting, String key, ConfigCatUser? user, SettingResult result) {
    EvaluateLogger? evaluateLogger;
    if (_logLevel.index <= LogLevel.info.index) {
      evaluateLogger = EvaluateLogger();
    }
    return _rolloutEvaluator.evaluate(
        setting, key, user, result.settings, evaluateLogger);
  }

  EvaluationDetails<T> _produceEvalDetails<T>(EvaluationResult eval, T value,
          String key, ConfigCatUser? user, SettingResult result) =>
      EvaluationDetails<T>(
          key: key,
          variationId: eval.variationId,
          user: user,
          isDefaultValue: false,
          error: null,
          errorCode: EvaluationErrorCode.none,
          value: value,
          fetchTime: result.fetchTime,
          matchedTargetingRule: eval.matchedTargetingRule,
          matchedPercentageOption: eval.matchedPercentageOption);

  ParseResult<T> _parseSettingValue<T>(
      SettingValue settingValue, int settingType) {
    SettingType? settingTypeEnum = SettingType.tryFrom(settingType);
    if (settingTypeEnum == null) {
      return ParseResult.error("Setting type is invalid.");
    }

    bool allowsAnyType =
        T == Object || Utils.typesEqual<T, Object?>() || T == dynamic;

    if ((T == bool || Utils.typesEqual<T, bool?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.boolean &&
        settingValue.booleanValue != null) {
      return ParseResult.ok(settingValue.booleanValue as T);
    }
    if ((T == String || Utils.typesEqual<T, String?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.string &&
        settingValue.stringValue != null) {
      return ParseResult.ok(settingValue.stringValue as T);
    }
    if ((T == int || Utils.typesEqual<T, int?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.int &&
        settingValue.intValue != null) {
      return ParseResult.ok(settingValue.intValue as T);
    }
    if ((T == double || Utils.typesEqual<T, double?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.double &&
        settingValue.doubleValue != null) {
      return ParseResult.ok(settingValue.doubleValue as T);
    }

    return ParseResult.error(
        "The type of a setting must match the type of the specified default value. Setting's type was ${settingTypeEnum.name} but the default value's type was $T. Please use a default value which corresponds to the setting type ${settingTypeEnum.name}. Learn more: https://configcat.com/docs/sdk-reference/dart/#setting-type-mapping");
  }
}

class ParseResult<T> {
  final T? value;
  final String? error;

  ParseResult(this.value, this.error);

  factory ParseResult.ok(T value) => ParseResult(value, null);
  factory ParseResult.error(String error) => ParseResult(null, error);
}
