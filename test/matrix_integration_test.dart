import 'dart:io';

import 'package:configcat_client/src/configcat_client.dart';
import 'package:configcat_client/src/configcat_options.dart';
import 'package:configcat_client/src/configcat_user.dart';
import 'package:configcat_client/src/log/configcat_logger.dart';
import 'package:configcat_client/src/log/logger.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

void main() {
  final testData = {
    "testmatrix.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A",
      _Kind.value
    ],
    "testmatrix_semantic.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/BAr3KgLTP0ObzKnBTo5nhA",
      _Kind.value
    ],
    "testmatrix_number.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/uGyK3q9_ckmdxRyI7vjwCw",
      _Kind.value
    ],
    "testmatrix_semantic_2.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/q6jMCFIp-EmuAfnmZhPY7w",
      _Kind.value
    ],
    "testmatrix_sensitive.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/qX3TP2dTj06ZpCCT1h_SPA",
      _Kind.value
    ],
    "testmatrix_variationId.csv": [
      "PKDVCLf-Hq-h-kCzMp-L7Q/nQ5qkhRAUEa6beEyyrVLBA",
      _Kind.variation
    ],
  };

  tearDown(() {
    ConfigCatClient.closeAll();
  });

  for (var element in testData.entries) {
    test(element.key, () async {
      await _runTest('test/fixtures/${element.key}', element.value[0] as String,
          element.value[1] as _Kind);
    });
  }
}

enum _Kind { value, variation }

Future<void> _runTest(String fileName, String sdkKey, _Kind kind) async {
  final lines = await File(fileName).readAsLines();
  final headers = lines[0].split(';');
  final customKey = headers[3];
  final client = ConfigCatClient.get(
      sdkKey: sdkKey,
      options:
          ConfigCatOptions(logger: ConfigCatLogger(level: LogLevel.warning)));

  final settingKeys = headers.skip(4).toList();
  final errors = List<String>.empty(growable: true);
  for (final line in lines.skip(1)) {
    final testObject = line.split(';');
    ConfigCatUser? user;
    if (testObject[0] != "##null##") {
      final identifier = testObject[0];
      final email = testObject[1].isNotEmpty && testObject[1] != "##null##"
          ? testObject[1]
          : '';
      final country = testObject[2].isNotEmpty && testObject[2] != "##null##"
          ? testObject[2]
          : '';
      final custom = testObject[3].isNotEmpty && testObject[3] != "##null##"
          ? testObject[3]
          : '';

      user = ConfigCatUser(
          identifier: identifier,
          email: email,
          country: country,
          custom: {customKey: custom});
    }

    int i = 0;
    for (final settingKey in settingKeys) {
      dynamic value = kind == _Kind.value
          ? await client.getValue<dynamic>(
              key: settingKey, defaultValue: null, user: user)
          : await client.getVariationId(
              key: settingKey, defaultVariationId: '', user: user);

      if (value.toString().toLowerCase() != testObject[i + 4].toLowerCase()) {
        errors.add(sprintf(
            'Identifier: %s, Key: %s. UV: %s Expected: %s, Result: %s \n', [
          testObject[0],
          settingKey,
          testObject[3],
          testObject[i + 4],
          value
        ]));
      }
      i++;
    }
  }

  if (errors.isNotEmpty) {
    for (var element in errors) {
      stderr.writeln(element);
    }

    fail("Errors found: ${errors.length}");
  }
}
