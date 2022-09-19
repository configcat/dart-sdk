# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0 -
### Added
- `setDefaultUser(user)` / `clearDefaultUser()` methods to set / remove a default user object used when there's no user passed to `getValue()` / `getValueDetails()` / `getAllValues()` / `getAllVariationIds()` methods.
- `setOffline()` / `setOnline()` methods to indicate whether the SDK is allowed to make HTTP calls or not. In 'offline' mode the SDK works from the cache only.
- `onClientReady()` / `onConfigChanged(Map<string, Setting>)` / `onFlagEvaluated(EvaluationDetails)` / `onError(String)` hooks. Subscription is possible on client initialization options and on the `hooks` property of `ConfigCatClient`.
- `getValueDetails()` method to retrieve evaluation details along with the feature flag / setting value. It returns the same details that is passed to `onFlagEvaluated(EvaluationDetails)` on each evaluation. 

### Changed
- The static `close()` method was split to an instance level `close()` method which closes the given `ConfigCatClient` and to a static `closeAll()` method which closes all instantiated client instances.
- The `forceRefresh()` method now returns with a result object that indicates whether the refresh succeeded or not.

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
