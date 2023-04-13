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
    logger.info(5000, 'info');
    logger.warning(3000, 'warning');
    logger.error(1000, 'error');

    // Assert
    verify(internal.debug('ConfigCat - [0] debug')).called(1);
    verify(internal.info('ConfigCat - [5000] info')).called(1);
    verify(internal.warning('ConfigCat - [3000] warning')).called(1);
    verify(internal.error('ConfigCat - [1000] error')).called(1);
  });

  test('logger info level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.info);

    // Act
    logger.debug('debug');
    logger.info(5000, 'info');
    logger.warning(3000, 'warning');
    logger.error(1000, 'error');

    // Assert
    verifyNever(internal.debug('ConfigCat - [0] debug'));
    verify(internal.info('ConfigCat - [5000] info')).called(1);
    verify(internal.warning('ConfigCat - [3000] warning')).called(1);
    verify(internal.error('ConfigCat - [1000] error')).called(1);
  });

  test('logger warning level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.warning);

    // Act
    logger.debug('debug');
    logger.info(5000, 'info');
    logger.warning(3000, 'warning');
    logger.error(1000, 'error');

    // Assert
    verifyNever(internal.debug('ConfigCat - [0] debug'));
    verifyNever(internal.info('ConfigCat - [5000] info'));
    verify(internal.warning('ConfigCat - [3000] warning')).called(1);
    verify(internal.error('ConfigCat - [1000] error')).called(1);
  });

  test('logger error level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.error);

    // Act
    logger.debug('debug');
    logger.info(5000, 'info');
    logger.warning(3000, 'warning');
    logger.error(1000, 'error');

    // Assert
    verifyNever(internal.debug('ConfigCat - [0] debug'));
    verifyNever(internal.info('ConfigCat - [5000] info'));
    verifyNever(internal.warning('ConfigCat - [3000] warning'));
    verify(internal.error('ConfigCat - [1000] error')).called(1);
  });

  test('logger nothing level tests', () {
    // Arrange
    final internal = MockLogger();
    final logger =
        ConfigCatLogger(internalLogger: internal, level: LogLevel.nothing);

    // Act
    logger.debug('debug');
    logger.info(5000, 'info');
    logger.warning(3000, 'warning');
    logger.error(1000, 'error');

    // Assert
    verifyNever(internal.debug('ConfigCat - [0] debug'));
    verifyNever(internal.info('ConfigCat - [5000] info'));
    verifyNever(internal.warning('ConfigCat - [3000] warning'));
    verifyNever(internal.error('ConfigCat - [1000] error'));
  });
}
