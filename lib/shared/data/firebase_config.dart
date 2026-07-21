import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes the default Android Firebase app from google-services.json.
/// The FCM service-account private key belongs only in Supabase Edge Function
/// secrets and is never part of the Android configuration.
abstract final class BlabFirebaseConfig {
  static bool get isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

Future<bool> initializeFirebaseForPush() async {
  if (!BlabFirebaseConfig.isAndroidPlatform) return false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return true;
  } catch (_) {
    // Push is auxiliary. A Firebase configuration/provider failure must not
    // prevent the user from opening Blab and receiving persisted messages.
    return false;
  }
}
