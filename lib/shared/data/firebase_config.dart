import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes the platform Firebase app from its environment configuration.
/// FCM server keys belong only in hosted server/provider credentials, never
/// in the Android configuration.
abstract final class BlabFirebaseConfig {
  static bool get isIosPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isPushPlatform => isAndroidPlatform || isIosPlatform;

  static bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

Future<bool> initializeFirebaseForPush({
  required bool enabled,
  required String expectedProjectId,
  required bool requiredForHostedAndroid,
}) async {
  if (!enabled || !BlabFirebaseConfig.isPushPlatform) return false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final actualProjectId = Firebase.app().options.projectId;
    if (expectedProjectId.isNotEmpty && actualProjectId != expectedProjectId) {
      throw StateError(
        'Firebase project does not match the selected Blab environment.',
      );
    }
    return true;
  } catch (error) {
    if (requiredForHostedAndroid) {
      throw StateError(
        'Firebase configuration is required and must match the selected '
        'Blab environment: $error',
      );
    }
    // Push is auxiliary. A Firebase configuration/provider failure must not
    // prevent a local development build from opening Blab.
    return false;
  }
}
