import 'package:blab/features/auth/widgets/sso_buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apple sign-in stays hidden on Android', () {
    expect(
      shouldShowAppleSignIn(isWeb: false, platform: TargetPlatform.android),
      isFalse,
    );
  });

  test('Apple sign-in is reserved for the future native iOS app', () {
    expect(
      shouldShowAppleSignIn(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      shouldShowAppleSignIn(isWeb: true, platform: TargetPlatform.iOS),
      isFalse,
    );
  });
}
