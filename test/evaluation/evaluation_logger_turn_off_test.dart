import 'package:configcat_client/configcat_client.dart';

import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'evaluation_test_logger.dart';

void main() {
  tearDown(() {
    ConfigCatClient.closeAll();
  });

  test('evaluation log level info', () async {
    // Arrange
    final testLogger = EvaluationTestLogger();

    final client = ConfigCatClient.get(
        sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A",
        options: ConfigCatOptions(
          logger:
              ConfigCatLogger(internalLogger: testLogger, level: LogLevel.info),
          pollingMode: PollingMode.manualPoll(),
        ));

    await client.forceRefresh();

    // Act
    final String value = await client.getValue(
        key: 'stringContainsDogDefaultCat', defaultValue: 'default');

    // Assert
    expect(value, equals('Cat'));

    var logList = testLogger.getLogList();
    expect(2, equals(logList.length));
    expect(LogLevel.warning, equals(logList[0].logLevel));
    expect(LogLevel.info, equals(logList[0].logLevel));
  });

  test('evaluation log level warning', () async {
    // Arrange
    final testLogger = EvaluationTestLogger();

    final client = ConfigCatClient.get(
        sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A",
        options: ConfigCatOptions(
          logger: ConfigCatLogger(
              internalLogger: testLogger, level: LogLevel.warning),
          pollingMode: PollingMode.manualPoll(),
        ));

    await client.forceRefresh();

    // Act
    final String value = await client.getValue(
        key: 'stringContainsDogDefaultCat', defaultValue: 'default');

    // Assert
    expect(value, equals('Cat'));

    var logList = testLogger.getLogList();
    expect(1, equals(logList.length));
    expect(LogLevel.warning, equals(logList[0].logLevel));
  });
}
