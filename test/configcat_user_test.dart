import 'package:configcat_client/configcat_client.dart';
import 'package:test/test.dart';

import 'helpers.dart';
import 'http_adapter.dart';

void main() {
  late ConfigCatClient client;
  late HttpTestAdapter testAdapter;
  setUp(() {
    client = ConfigCatClient.get(
        sdkKey: testSdkKey,
        options: ConfigCatOptions(pollingMode: PollingMode.manualPoll()));
    testAdapter = HttpTestAdapter(client.httpClient);
  });
  tearDown(() {
    ConfigCatClient.closeAll();
    testAdapter.close();
  });

  test('user attributes case insensitivity', () async {
    // Arrange
    final user = ConfigCatUser(
        identifier: 'id',
        email: 'email',
        country: 'country',
        custom: {'custom': 'test'});

    // Assert
    expect('id', equals(user.identifier));
    expect('email', equals(user.getAttribute('Email')));
    expect('email', isNot(equals(user.getAttribute('EMAIL'))));
    expect('email', isNot(equals(user.getAttribute('email'))));
    expect('country', equals(user.getAttribute('Country')));
    expect('country', isNot(equals(user.getAttribute('COUNTRY'))));
    expect('country', isNot(equals(user.getAttribute('country'))));
    expect('test', equals(user.getAttribute('custom')));
    expect(user.getAttribute('not-existing'), isNull);
  });

  test('default user', () async {
    // Arrange
    testAdapter.enqueueResponse(
        getPath(), 200, createTestConfigWithRules().toJson());
    await client.forceRefresh();
    final user1 = ConfigCatUser(identifier: 'test@test1.com');
    final user2 = ConfigCatUser(identifier: 'test@test2.com');

    // Act
    client.setDefaultUser(user1);
    var value = await client.getValue(key: 'key1', defaultValue: '');

    // Assert
    expect(value, equals('fake1'));

    // Act
    value = await client.getValue(key: 'key1', defaultValue: '', user: user2);

    // Assert
    expect(value, equals('fake2'));

    // Act
    client.clearDefaultUser();
    value = await client.getValue(key: 'key1', defaultValue: '');

    // Assert
    expect(value, equals('def'));
  });
}
