import 'package:configcat_client/configcat_client.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/scaffolding.dart';

import 'logger_test.mocks.dart';

@GenerateMocks([Logger])
void main() {
  test('logger debug level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.debug);

    // Act
    logger.debug('debug');
    logger.info('info');
    logger.warning('warning');
    logger.error('error');

    // Assert
    verify(internal.debug('ConfigCat - debug')).called(1);
    verify(internal.info('ConfigCat - info')).called(1);
    verify(internal.warning('ConfigCat - warning')).called(1);
    verify(internal.error('ConfigCat - error')).called(1);
  });

  test('logger info level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.info);

    // Act
    logger.debug('debug');
    logger.info('info');
    logger.warning('warning');
    logger.error('error');

    // Assert
    verifyNever(internal.debug('ConfigCat - debug'));
    verify(internal.info('ConfigCat - info')).called(1);
    verify(internal.warning('ConfigCat - warning')).called(1);
    verify(internal.error('ConfigCat - error')).called(1);
  });

  test('logger warning level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.warning);

    // Act
    logger.debug('debug');
    logger.info('info');
    logger.warning('warning');
    logger.error('error');

    // Assert
    verifyNever(internal.debug('ConfigCat - debug'));
    verifyNever(internal.info('ConfigCat - info'));
    verify(internal.warning('ConfigCat - warning')).called(1);
    verify(internal.error('ConfigCat - error')).called(1);
  });

  test('logger error level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.error);

    // Act
    logger.debug('debug');
    logger.info('info');
    logger.warning('warning');
    logger.error('error');

    // Assert
    verifyNever(internal.debug('ConfigCat - debug'));
    verifyNever(internal.info('ConfigCat - info'));
    verifyNever(internal.warning('ConfigCat - warning'));
    verify(internal.error('ConfigCat - error')).called(1);
  });

  test('logger nothing level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.nothing);

    // Act
    logger.debug('debug');
    logger.info('info');
    logger.warning('warning');
    logger.error('error');

    // Assert
    verifyNever(internal.debug('ConfigCat - debug'));
    verifyNever(internal.info('ConfigCat - info'));
    verifyNever(internal.warning('ConfigCat - warning'));
    verifyNever(internal.error('ConfigCat - error'));
  });
}
