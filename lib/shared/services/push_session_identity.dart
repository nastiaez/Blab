import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Re-read the SDK's persisted identity across Flutter background isolates.
/// This is a suppression check, never server authorization.
Future<bool> persistedPushAccountMatches(
  String owner,
  String supabaseUrl,
) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final project = Uri.parse(supabaseUrl).host.split('.').first;
    final raw = preferences.getString('sb-$project-auth-token');
    if (raw == null) return false;
    final session = jsonDecode(raw);
    return session is Map &&
        session['user'] is Map &&
        session['user']['id'] == owner;
  } catch (_) {
    return false;
  }
}
