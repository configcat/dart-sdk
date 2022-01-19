import 'package:configcat_client/configcat_client.dart';

Future<void> main() async {
  final client = ConfigCatClient.get(
      sdkKey: 'PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ',
      options: ConfigCatOptions(
          logger: ConfigCatLogger(
              // Info level logging helps to inspect the feature flag evaluation process.
              // Use the default Warning level to avoid too detailed logging in your application.
              level: LogLevel.info)));

  final isAwesomeFeatureEnabled = await client.getValue(
      key: 'isAwesomeFeatureEnabled', defaultValue: false);

  print("isAwesomeFeatureEnabled: $isAwesomeFeatureEnabled");

  final user = ConfigCatUser(
      identifier: '#SOME-USER-ID#', email: 'configcat@example.com');

  final isPOCFeatureEnabled = await client.getValue(
      key: 'isPOCFeatureEnabled', defaultValue: false, user: user);

  print("isPOCFeatureEnabled: $isPOCFeatureEnabled");

  ConfigCatClient.close();
}
