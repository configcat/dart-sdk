import 'package:dart_sdk/src/config_cat_client.dart';
import 'package:test/test.dart';

void main() {
  test('test get int value', () {
    final client = ConfigCatClient(sdkKey: "test");
    client.refresh();
    final config = client.getValue("fakeKey", 10);
    expect(config, 43);
  });

  test('test get int value failed', () {
    final client = ConfigCatClient(sdkKey: "test");
    client.refresh();
    final config = client.getValue("fakeKey", 10);
    expect(config, 10);
  });
}
