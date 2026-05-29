import 'dart:convert';

import 'package:configcat_client/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('Utils.deserializeConfig', () {
    test('successful deserialization', () {
      // Arrange
      final configMap = {
        'p': {
          'u': 'https://cdn-global.configcat.com',
          'r': 0,
          's': 'test-salt'
        },
        'f': {
          'testKey': {
            'v': {'s': 'testValue', 'b': null, 'i': null, 'd': null},
            't': 1,
            'a': '',
            'i': 'test-variation-id',
            'r': [],
            'p': [],
          }
        },
        's': [],
      };
      final configJson = jsonEncode(configMap);

      // Act
      final config = Utils.deserializeConfig(configJson);

      // Assert
      expect(config, isNotNull);
      expect(config.isEmpty, isFalse);
      expect(config.preferences.baseUrl,
          equals('https://cdn-global.configcat.com'));
      expect(config.preferences.salt, equals('test-salt'));
      expect(config.entries, contains('testKey'));
      expect(config.entries['testKey']?.settingValue.stringValue,
          equals('testValue'));
    });

    test('throws on empty configJson', () {
      // Act & Assert
      expect(
          () => Utils.deserializeConfig(''),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Config JSON content is empty.')));
    });

    test('throws on configJson containing literal null', () {
      // Act & Assert
      expect(
          () => Utils.deserializeConfig('null'),
          throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
              contains('Invalid config JSON content'))));
    });
  });
}
