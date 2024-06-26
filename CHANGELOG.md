# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 4.1.1 - 2024-05-06
### Fixed
- Fix initial config JSON load when auto poll enabled with results from cache.

## 4.1.0 - 2024-04-03
### Changed
- Rename `SettingsValue` to correct `SettingValue`
- Add `getKeyAndValue` missing exception
- Improve prerequisite flag evaluation type checks
- Typo fixes

## 4.0.1 - 2024-02-13
### Fixed
- `WEB` platform support.

### Changed
- In case of `WEB` platform the SDK now sends the Etag and SDK info in query parameters.

## 4.0.0 - 2024-02-13
### New features and improvements
- Add support for the new Config JSON v6 format: update the config model and implement new features in setting evaluation logic.
- Overhaul setting evaluation-related logging and make it consistent across SDKs.
- SDK key format validation (when client is not set up to use local-only flag overrides).
- Go to the cache in all polling modes instead of using the in memory variable.

### Breaking changes
- Change the `ConfigCatUser` constructor `custom` parameter type to Map<String, Object> to allow other values than string.
- Rename the `matchedEvaluationRule` property to `matchedTargetingRule` and the `matchedEvaluationPercentageRule` property to `matchedPercentageOption` in `EvaluationDetails`.
- Change `Config` model

## 3.0.0 - 2023-08-18
### Changed
- Standardized config cache key generation algorithm and cache payload format to allow shared caches to be used by SDKs of different platforms.

### Removed
- `getVariationId()` / `getAllVariationIds()` methods. Alternative: `getValueDetails()` / `getAllValueDetails()`

## 2.5.2 - 2023-06-21
### Removed
- `logger` package dependency. Switched to simple `print()` as default.

## 2.5.1 - 2023-06-21
### Changed
- Bump to `dio v5.2.0` in order to use `DioException` instead of the deprecated `DioError`.

## 2.5.0 - 2023-05-22
### Changed
- Bumped dependency versions.
- Set min Dart SDK version to `>=2.19.0`.

## 2.4.0 - 2022-12-20
### Added
- New `getAllValueDetails()` method.

### Changed
- Deprecated `getVariationId()` and `getAllVariationIds()` methods in favor of `getValueDetails()` and `getAllValueDetails()`.

## 2.3.0 - 2022-10-18
### Changed
- Renamed `mode` configuration option to `pollingMode`.

## 2.2.1 - 2022-10-17
### Fixed
- Prevent auto-poll from starting when the SDK is initialized in offline mode.

## 2.2.0 - 2022-10-13
### Added
- Allow offline SDK initialization with an `offline` configuration option.

## 2.1.0 - 2022-09-30
### Changed
- `RolloutPercentageItem` -> `PercentageRule`

### Fixed
- Set the `user` field of `EvaluationDetails` in case of error.

## 2.0.2 - 2022-09-28
### Fixed
- Hanging due to non-cancelled `Future.delayed`.

## 2.0.1 - 2022-09-27
### Fixed
- Static analyzer warnings.

## 2.0.0 - 2022-09-27
### Added
- `setDefaultUser(user)` / `clearDefaultUser()` methods to set / remove a default user object used when there's no user passed to `getValue()` / `getValueDetails()` / `getAllValues()` / `getAllVariationIds()` methods.
- `setOffline()` / `setOnline()` methods to indicate whether the SDK is allowed to make HTTP calls or not. In 'offline' mode the SDK works from the cache only.
- `onClientReady()` / `onConfigChanged(Map<string, Setting>)` / `onFlagEvaluated(EvaluationDetails)` / `onError(String)` hooks. Subscription is possible on client initialization options and on the `hooks` property of `ConfigCatClient`.
- `getValueDetails()` method to retrieve evaluation details along with the feature flag / setting value. It returns the same details that is passed to `onFlagEvaluated(EvaluationDetails)` on each evaluation. 

### Changed
- The static `close()` method was split to an instance level `close()` method which closes the given `ConfigCatClient` and to a static `closeAll()` method which closes all instantiated client instances.
- The `forceRefresh()` method now returns with a result object that indicates whether the refresh succeeded or not.
- The TTL of `lazyLoad` and interval of `autoPoll` is compared against a cached `fetchTime`, which allows the SDK not necessarily download a new `config.json` at each application restart.

### Removed
- The `onConfigChanged()` hook parameter of `PollingModes.autoPoll`. It was replaced by the newly introduced `onConfigChanged(Map<string, Setting>)` hook function which is invoked with each polling mode. 

## 1.1.0 - 2022-08-16
### Changed
- Replaced the refresh policies construction with a single config service that takes care of the different polling mechanisms, caching, and the synchronization of HTTP requests.

## 1.0.2 - 2022-08-09
### Fixed
- Send the correct SDK version in HTTP header.

## 1.0.1 - 2022-08-04
### Fixed
- When the `dataGovernance` parameter wasn't in match with the remote setting, it could have happened that the fetcher downloaded the correct `config.json` multiple times.  

## 1.0.0 - 2022-01-24
- First official release.

## 0.1.4 - 2022-01-24
- WIP release.

## 0.1.3 - 2022-01-20
- WIP release.

## 0.1.2 - 2022-01-19
- WIP release.

## 0.1.0 - 2022-01-19
- WIP release.
