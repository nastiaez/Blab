import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes the default Android Firebase app from google-services.json.
/// The FCM service-account private key belongs only in Supabase Edge Function
/// secrets and is never part of the Android configuration.
abstract final class BlabFirebaseConfig {
  static bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

Future<bool> initializeFirebaseForPush({
  required bool enabled,
  required String expectedProjectId,
  required bool requiredForHostedAndroid,
}) async {
  if (!enabled || !BlabFirebaseConfig.isAndroidPlatform) return false;
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
