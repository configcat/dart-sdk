import 'package:configcat_client/configcat_client.dart';
import 'package:test/test.dart';

void main() {
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
}
