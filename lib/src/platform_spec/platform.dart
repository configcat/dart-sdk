import 'default/platform.dart' if (dart.library.io) 'io/platform.dart';

class Platform {
  Platform._();
  static String get lineTerminator => ActualPlatform.lineTerminator;
}
