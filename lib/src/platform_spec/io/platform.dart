import 'dart:io';

class ActualPlatform {
  ActualPlatform._();
  static String get lineTerminator => Platform.isWindows ? '\r\n' : '\n';
}
