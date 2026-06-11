/// ConfigCat Log Messages.
class ConfigCatLogMessages {
  /// Log message for Config Service Cannot Initiate Http Calls warning. The log eventId 3200.
  static const String configServiceCannotInitiateHttpCallsWarn =
      "Client is in offline mode, it cannot initiate HTTP calls.";

  /// Log message for Data Governance Is Out Of Sync warning. The log eventId 3002.
  static const String dataGovernanceIsOutOfSyncWarn =
      "The `builder.dataGovernance()` parameter specified at the client initialization is not in sync with the preferences on the ConfigCat Dashboard. Read more: https://configcat.com/docs/advanced/data-governance/";

  /// Log message for Config Service Cache Write error. The log eventId is 2201.
  static const String configServiceCacheWriteError =
      "Error occurred while writing the cache";

  /// Log message for Config Service Cache Read error. The log eventId is 2200.
  static const String configServiceCacheReadError =
      "Error occurred while reading the cache.";

  // Constants for private log messages (used with method helpers)
  static const String _fetchFailedDueToInvalidSdkKeyError =
      "Your SDK Key seems to be wrong. You can find the valid SDK Key at https://app.configcat.com/sdkkey";

  static const String _fetchFailedDueToUnexpectedError =
      "Unexpected error occurred while trying to fetch config JSON. It is most likely due to a local network issue. Please make sure your application can reach the ConfigCat CDN servers (or your proxy server) over HTTP.";

  static const String _fetchFailedDueToRedirectLoopError =
      "Redirection loop encountered while trying to fetch config JSON. Please contact us at https://configcat.com/support/";

  static const String _fetchReceived200WithInvalidBodyError =
      "Fetching config JSON was successful but the HTTP response content was invalid.";

  // Private constructor to prevent instantiation
  ConfigCatLogMessages._();

  /// Log message for Config Json Is Not Presented errors when the method returns with default value.
  /// The log eventId is 1000.
  static String getConfigJsonIsNotPresentedWithDefaultValue(
      String key, String defaultParamName, Object? defaultParamValue) {
    return "Config JSON is not present when evaluating setting '$key'. Returning the `$defaultParamName` parameter that you specified in your application: '$defaultParamValue'.";
  }

  /// Log message for Config Json Is Not Presented errors when the method returns with empty value.
  /// The log eventId is 1000.
  static String getConfigJsonIsNotPresentedWithEmptyResult(String emptyResult) {
    return "Config JSON is not present. Returning $emptyResult.";
  }

  /// Log message for Setting Evaluation Failed Due To Missing Key error. The log eventId is 1001.
  static String getSettingEvaluationFailedDueToMissingKey(
      String key,
      String defaultParamName,
      Object? defaultParamValue,
      Set<String> availableKeysSet) {
    final keysString = availableKeysSet.join(", ");
    return "Failed to evaluate setting '$key' (the key was not found in config JSON). Returning the `$defaultParamName` parameter that you specified in your application: '$defaultParamValue'. Available keys: [$keysString].";
  }

  /// Log message for Setting Evaluation errors when the method returns with default value.
  /// The log eventId is 1002.
  static String getSettingEvaluationErrorWithDefaultValue(String methodName,
      String key, String defaultParamName, Object? defaultParamValue) {
    return "Error occurred in the `$methodName` method while evaluating setting '$key'. Returning the `$defaultParamName` parameter that you specified in your application: '$defaultParamValue'.";
  }

  /// Log message for Setting Evaluation errors when the method returns with empty value.
  /// The log eventId is 1002.
  static String getSettingEvaluationErrorWithEmptyValue(
      String methodName, String emptyResult) {
    return "Error occurred in the `$methodName` method. Returning $emptyResult.";
  }

  /// Log message for Setting For Variation Id Is Not Present error. The log eventId is 2011.
  static String getSettingForVariationIdIsNotPresent(String variationId) {
    return "Could not find the setting for the specified variation ID: '$variationId'.";
  }

  /// Log message for Fetch Failed Due To Invalid Sdk Key error. The log eventId is 1100.
  static String getFetchFailedDueToInvalidSDKKey(String? cfRayId) {
    if (cfRayId != null) {
      return "$_fetchFailedDueToInvalidSdkKeyError ${_getCFRayIdPostFix(cfRayId)}";
    }
    return _fetchFailedDueToInvalidSdkKeyError;
  }

  /// Log message for Fetch Failed Due To Unexpected Http Response error. The log eventId is 1101.
  static String getFetchFailedDueToUnexpectedHttpResponse(
      int responseCode, String responseMessage, String? cfRayId) {
    if (cfRayId != null) {
      return "Unexpected HTTP response was received while trying to fetch config JSON: $responseCode $responseMessage ${_getCFRayIdPostFix(cfRayId)}";
    }
    return "Unexpected HTTP response was received while trying to fetch config JSON: $responseCode $responseMessage";
  }

  /// Log message for Fetch Failed Due To Request Timeout error. The log eventId is 1102.
  static String getFetchFailedDueToRequestTimeout(int connectTimeoutMillis,
      int readTimeoutMillis, int writeTimeoutMillis, String? cfRayId) {
    if (cfRayId != null) {
      return "Request timed out while trying to fetch config JSON. Timeout values: [connect: ${connectTimeoutMillis}ms, read: ${readTimeoutMillis}ms, write: ${writeTimeoutMillis}ms] ${_getCFRayIdPostFix(cfRayId)}";
    }
    return "Request timed out while trying to fetch config JSON. Timeout values: [connect: ${connectTimeoutMillis}ms, read: ${readTimeoutMillis}ms, write: ${writeTimeoutMillis}ms]";
  }

  /// Log message for Fetch Failed Due To Unexpected error. The log eventId is 1103.
  static String getFetchFailedDueToUnexpectedError(String? cfRayId) {
    if (cfRayId != null) {
      return "$_fetchFailedDueToUnexpectedError ${_getCFRayIdPostFix(cfRayId)}";
    }
    return _fetchFailedDueToUnexpectedError;
  }

  /// Log message for Fetch Failed Due To Redirect Loop error. The log eventId is 1104.
  static String getFetchFailedDueToRedirectLoop(String? cfRayId) {
    if (cfRayId != null) {
      return "$_fetchFailedDueToRedirectLoopError ${_getCFRayIdPostFix(cfRayId)}";
    }
    return _fetchFailedDueToRedirectLoopError;
  }

  /// Log message for Fetch Received 200 With Invalid Body error. The log eventId is 1105.
  static String getFetchReceived200WithInvalidBodyError(String? cfRayId) {
    if (cfRayId != null) {
      return "$_fetchReceived200WithInvalidBodyError ${_getCFRayIdPostFix(cfRayId)}";
    }
    return _fetchReceived200WithInvalidBodyError;
  }

  /// Log message for Client Is Already Created warning. The log eventId 3000.
  static String getClientIsAlreadyCreated(String sdkKey) {
    return "There is an existing client instance for the specified SDK Key. No new client instance will be created and the specified options callback is ignored. Returning the existing client instance. SDK Key: '$sdkKey'.";
  }

  /// Log message for User Object is missing warning. The log eventId 3001.
  static String getUserObjectMissing(String key) {
    return "Cannot evaluate targeting rules and % options for setting '$key' (User Object is missing). You should pass a User Object to the evaluation methods like `getValue()` in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/";
  }

  /// Log message for User Attribute is missing warning. The log eventId 3003.
  static String getUserAttributeMissingWithCondition(
      String key, String userCondition, String attributeName) {
    return "Cannot evaluate condition ($userCondition) for setting '$key' (the User.$attributeName attribute is missing). You should set the User.$attributeName attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/";
  }

  /// Log message for User Attribute is missing warning. The log eventId 3003.
  static String getUserAttributeMissing(String key, String attributeName) {
    return "Cannot evaluate % options for setting '$key' (the User.$attributeName attribute is missing). You should set the User.$attributeName attribute in order to make targeting work properly. Read more: https://configcat.com/docs/advanced/user-object/";
  }

  /// Log message for User Attribute is invalid warning. The log eventId 3004.
  static String getUserAttributeInvalid(
      String key, String userCondition, String reason, String attributeName) {
    return "Cannot evaluate condition ($userCondition) for setting '$key' ($reason). Please check the User.$attributeName attribute and make sure that its value corresponds to the comparison operator.";
  }

  /// Log message for User Attribute value is automatically converted warning. The log eventId 3005.
  static String getUserObjectAttributeIsAutoConverted(String key,
      String userCondition, String attributeName, String attributeValue) {
    return "Evaluation of condition ($userCondition) for setting '$key' may not produce the expected result (the User.$attributeName attribute is not a string value, thus it was automatically converted to the string value '$attributeValue'). Please make sure that using a non-string value was intended.";
  }

  /// Log message for Config Service Method Has No Effect Due To Closed Client warning.
  /// The log eventId 3201.
  static String getConfigServiceMethodHasNoEffectDueToClosedClient(
      String methodName) {
    return "The client object is already closed, thus `$methodName` has no effect.";
  }

  /// Log message for Auto Poll Max Init Wait Time Reached warning. The log eventId 4200.
  static String getAutoPollMaxInitWaitTimeReached(int maxInitWaitTimeSeconds) {
    return "`maxInitWaitTimeSeconds` for the very first fetch reached (${maxInitWaitTimeSeconds}s). Returning cached config.";
  }

  /// Log message for Config Service Status Changed info. The log eventId 5200.
  static String getConfigServiceStatusChanged(String mode) {
    return "Switched to $mode mode.";
  }

  /// Get CF-RAY ID header post fix log message.
  static String _getCFRayIdPostFix(String rayId) {
    return "(Ray ID: $rayId)";
  }
}
