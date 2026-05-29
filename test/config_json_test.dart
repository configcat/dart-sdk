import 'package:configcat_client/src/json/config.dart';
import 'package:test/test.dart';

void main() {
  group('Config JSON', () {
    test('uses an empty entries map when f is null', () {
      final config = Config.fromJson({
        'p': {'u': 'https://cdn-global.configcat.com', 'r': 0, 's': null},
        'f': null,
        's': [],
      });

      expect(config.entries, isEmpty);
    });

    test('uses an empty entries map when f is missing', () {
      final config = Config.fromJson({
        'p': {'u': 'https://cdn-global.configcat.com', 'r': 0, 's': null},
        's': [],
      });

      expect(config.entries, isEmpty);
    });
  });
}
