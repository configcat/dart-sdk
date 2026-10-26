import 'package:configcat_client/configcat_client.dart';
import 'package:configcat_client/src/constants.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  tearDown(() {
    ConfigCatClient.closeAll();
  });

  test('get', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': true}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();
    final enabled = snapshot.getValue(key: 'enabled', defaultValue: false);

    expect(enabled, isTrue);
  });

  test('get all keys', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();
    final keys = snapshot.getAllKeys();

    expect(keys, equals(['enabled', 'something']));
  });

  test('get all keys empty', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(getPath(), 200, "");

    await client.waitForReady();
    final snapshot = client.snapshot();
    final keys = snapshot.getAllKeys();

    expect(keys, isEmpty);
  });

  test('get details', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();
    final details =
        snapshot.getValueDetails(key: "enabled", defaultValue: false);

    expect(details.value, isTrue);
    expect(details.isDefaultValue, isFalse);
    expect(details.errorCode, EvaluationErrorCode.none);
  });

  test('wait multiple', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    await client.waitForReady();
    final snapshot = client.snapshot();
    final details =
        snapshot.getValueDetails(key: "enabled", defaultValue: false);

    expect(details.value, isTrue);
    expect(details.isDefaultValue, isFalse);
    expect(details.errorCode, EvaluationErrorCode.none);
  });

  test('client state', () async {
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            pollingMode: PollingMode.autoPoll(
                autoPollInterval: const Duration(seconds: 1))));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, "");
    testAdapter.enqueueResponse(getPath(), 200, body);

    final state = await client.waitForReady();

    expect(state, equals(ClientCacheState.noFlagData));

    await until(
        () => Future.value(client.snapshot().cacheState ==
            ClientCacheState.hasUpToDateFlagData),
        const Duration(seconds: 2));
  });

  test('type mismatch', () async {
    final client = ConfigCatClient.get(sdkKey: testSdkKey);
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();

    final details = snapshot.getValueDetails(key: "enabled", defaultValue: 5);

    expect(details.value, equals(5));
    expect(details.isDefaultValue, isTrue);
    expect(details.errorCode,
        equals(EvaluationErrorCode.settingValueTypeMismatch));
  });

  test('config changed hook', () async {
    ConfigCatClientSnapshot? sn;
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            hooks: (h) =>
                h.addOnConfigChanged((_, snapshot) => sn = snapshot)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();

    expect(sn, isNotNull);
    expect(sn!.cacheState, equals(ClientCacheState.hasUpToDateFlagData));
  });

  test('ready hook', () async {
    ConfigCatClientSnapshot? sn;
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            hooks: (h) =>
                h.addOnClientReadyWithSnapshot((snapshot) => sn = snapshot)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body =
        createTestConfig({'enabled': true, 'something': 'some'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();

    expect(sn, isNotNull);
    expect(sn!.cacheState, equals(ClientCacheState.hasUpToDateFlagData));
  });

  test('hooks cache', () async {
    final cache = CustomCache(createTestEntry({'a': true}).serialize());
    ConfigCatClientSnapshot? sn1;
    ConfigCatClientSnapshot? sn2;
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            hooks: (h) {
              h.addOnConfigChanged((_, snapshot) => sn2 = snapshot);
              h.addOnClientReadyWithSnapshot((snapshot) => sn1 = snapshot);
            },
            cache: cache));
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(getPath(), 200, "");

    final state = await client.waitForReady();

    expect(state, equals(ClientCacheState.hasUpToDateFlagData));
    expect(sn1, isNotNull);
    expect(sn1!.cacheState, equals(ClientCacheState.hasUpToDateFlagData));
    expect(sn2, isNotNull);
    expect(sn2!.cacheState, equals(ClientCacheState.hasUpToDateFlagData));
  });

  test('hooks cache expired', () async {
    final cache = CustomCache(
        createTestEntryWithTime({'a': true}, distantPast).serialize());
    ConfigCatClientSnapshot? sn1;
    ConfigCatClientSnapshot? sn2;
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            hooks: (h) {
              h.addOnConfigChanged((_, snapshot) => sn2 = snapshot);
              h.addOnClientReadyWithSnapshot((snapshot) => sn1 = snapshot);
            },
            cache: cache));
    final testAdapter = HttpTestAdapter(client.httpClient);
    testAdapter.enqueueResponse(getPath(), 200, "");

    final state = await client.waitForReady();

    expect(state, equals(ClientCacheState.hasCachedFlagDataOnly));
    expect(sn1, isNotNull);
    expect(sn1!.cacheState, equals(ClientCacheState.hasCachedFlagDataOnly));
    expect(sn2, isNotNull);
    expect(sn2!.cacheState, equals(ClientCacheState.hasCachedFlagDataOnly));
  });

  test('override local only', () async {
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.localOnly)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();

    final found = snapshot.getValue(key: 'enabled', defaultValue: false);
    final localOnly = snapshot.getValue(key: 'local-only', defaultValue: false);
    final notFound =
        snapshot.getValue<dynamic>(key: 'remote', defaultValue: null);

    expect(found, isTrue);
    expect(localOnly, isTrue);
    expect(notFound, isNull);
  });

  test('override local over remote', () async {
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.localOverRemote)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();

    final enabled = snapshot.getValue(key: 'enabled', defaultValue: false);
    final localOnly = snapshot.getValue(key: 'local-only', defaultValue: false);
    final remote = snapshot.getValue(key: 'remote', defaultValue: '');

    expect(enabled, isTrue);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));
  });

  test('override remote over local', () async {
    final client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(
            override: FlagOverrides(
                dataSource: OverrideDataSource.map(
                    {'enabled': true, 'local-only': true}),
                behaviour: OverrideBehaviour.remoteOverLocal)));
    final testAdapter = HttpTestAdapter(client.httpClient);
    final body = createTestConfig({'enabled': false, 'remote': 'rem'}).toJson();
    testAdapter.enqueueResponse(getPath(), 200, body);

    await client.waitForReady();
    final snapshot = client.snapshot();

    final enabled = snapshot.getValue(key: 'enabled', defaultValue: true);
    final localOnly = snapshot.getValue(key: 'local-only', defaultValue: false);
    final remote = snapshot.getValue(key: 'remote', defaultValue: '');

    expect(enabled, isFalse);
    expect(localOnly, isTrue);
    expect(remote, equals('rem'));
  });
}
