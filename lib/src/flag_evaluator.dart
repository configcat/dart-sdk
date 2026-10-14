import 'package:configcat_client/src/errors.dart';
import 'package:configcat_client/src/fetch/config_service.dart';
import 'package:configcat_client/src/rollout_evaluator.dart';
import 'package:configcat_client/src/utils.dart';

import 'configcat_log_messages.dart';
import 'configcat_options.dart';
import 'configcat_user.dart';
import 'evaluate_logger.dart';
import 'json/setting.dart';
import 'json/setting_type.dart';
import 'json/setting_value.dart';
import 'log/logger.dart';

class FlagEvaluator {
  final Hooks _hooks;
  final RolloutEvaluator _rolloutEvaluator;
  final LogLevel _logLevel;

  FlagEvaluator(this._hooks, this._rolloutEvaluator, this._logLevel);

  EvaluationDetails<T> evaluate<T>(
      String key, ConfigCatUser? user, T defaultValue, SettingResult result) {
    if (result.isEmpty) {
      final errorMsg =
          ConfigCatLogMessages.getConfigJsonIsNotPresentedWithDefaultValue(
              key, "defaultValue", defaultValue);
      throw EvaluationError(
          message: errorMsg,
          messageToLog: errorMsg,
          errorCode: EvaluationErrorCode.configJsonNotAvailable,
          eventId: EvaluationErrorCode.configJsonNotAvailable.value);
    }
    final setting = result.settings[key];
    if (setting == null) {
      final errorMsg =
          ConfigCatLogMessages.getSettingEvaluationFailedDueToMissingKey(
              key, "defaultValue", defaultValue, result.settings.keys.toSet());
      throw EvaluationError(
          message: errorMsg,
          messageToLog: errorMsg,
          errorCode: EvaluationErrorCode.settingKeyMissing,
          eventId: EvaluationErrorCode.settingKeyMissing.value);
    }

    return evaluateSetting(key, setting, user, result);
  }

  EvaluationDetails<T> evaluateSetting<T>(
      String key, Setting setting, ConfigCatUser? user, SettingResult result) {
    final eval = _eval(setting, key, user, result);
    final parsed = parseSettingValue<T>(eval.value, setting.type);
    final details = _produceEvalDetails(eval, parsed, key, user, result);
    _hooks.invokeFlagEvaluated(details);
    return details;
  }

  static void validateReturnType<T>() {
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
          errorObject: null,
          value: value,
          fetchTime: result.fetchTime,
          matchedTargetingRule: eval.matchedTargetingRule,
          matchedPercentageOption: eval.matchedPercentageOption);

  T parseSettingValue<T>(SettingValue settingValue, int settingType) {
    SettingType? settingTypeEnum = SettingType.tryFrom(settingType);
    if (settingTypeEnum == null) {
      throw EvaluationError(
          message: "Setting type is invalid.",
          errorCode: EvaluationErrorCode.settingValueTypeMismatch);
    }

    bool allowsAnyType =
        T == Object || Utils.typesEqual<T, Object?>() || T == dynamic;

    if ((T == bool || Utils.typesEqual<T, bool?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.boolean &&
        settingValue.booleanValue != null) {
      return settingValue.booleanValue as T;
    }
    if ((T == String || Utils.typesEqual<T, String?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.string &&
        settingValue.stringValue != null) {
      return settingValue.stringValue as T;
    }
    if ((T == int || Utils.typesEqual<T, int?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.int &&
        settingValue.intValue != null) {
      return settingValue.intValue as T;
    }
    if ((T == double || Utils.typesEqual<T, double?>() || allowsAnyType) &&
        settingTypeEnum == SettingType.double &&
        settingValue.doubleValue != null) {
      return settingValue.doubleValue as T;
    }

    throw EvaluationError(
        message:
            "The type of a setting must match the type of the specified default value. Setting's type was ${settingTypeEnum.name} but the default value's type was $T. Please use a default value which corresponds to the setting type ${settingTypeEnum.name}. Learn more: https://configcat.com/docs/sdk-reference/dart/#setting-type-mapping",
        errorCode: EvaluationErrorCode.settingValueTypeMismatch);
  }
}

class ParseResult<T> {
  final T? value;
  final String? error;

  ParseResult(this.value, this.error);

  factory ParseResult.ok(T value) => ParseResult(value, null);
  factory ParseResult.error(String error) => ParseResult(null, error);
}
