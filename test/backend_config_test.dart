import 'package:drivetalk/real/backend_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google: the app\'s own client id even when the build passes none', () {
    // `flutter test` passes no GOOGLE_WEB_CLIENT_ID, like CI with an empty
    // variable: the built-in public id is used.
    expect(
      BackendConfig.googleWebClientId,
      endsWith('.apps.googleusercontent.com'),
    );
  });
}
