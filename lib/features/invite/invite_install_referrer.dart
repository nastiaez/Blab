import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'invite_continuation.dart';

String? inviteTokenFromReferrer(String referrer) {
  try {
    final token = Uri.splitQueryString(referrer)['invite'];
    return token != null && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(token)
        ? token
        : null;
  } on FormatException {
    return null;
  }
}

Future<String?> readInstallInvite() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('invite_install_referrer_retired') == true) return null;
  if (await loadPendingInvite() != null) {
    await retireInstallInvite();
    return null;
  }
  final candidate = prefs.getString('invite_install_candidate');
  if (candidate != null) return candidate;
  if (prefs.getBool('invite_install_referrer_read') == true) return null;
  try {
    final referrer = await const MethodChannel('blab/invite')
        .invokeMethod<String>('getInstallReferrer')
        .timeout(const Duration(seconds: 4));
    if (prefs.getBool('invite_install_referrer_retired') == true) return null;
    final token = referrer == null ? null : inviteTokenFromReferrer(referrer);
    if (token != null) await prefs.setString('invite_install_candidate', token);
    await prefs.setBool('invite_install_referrer_read', true);
    if (await loadPendingInvite() != null) {
      await prefs.remove('invite_install_candidate');
      return null;
    }
    if (prefs.getBool('invite_install_referrer_retired') == true) return null;
    return token;
  } catch (_) {
    return null;
  }
}

Future<void> clearInstallInviteCandidate(String token) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('invite_install_candidate') == token) {
    await prefs.remove('invite_install_candidate');
  }
}

Future<void> retireInstallInvite() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('invite_install_referrer_retired', true);
  await prefs.remove('invite_install_candidate');
  await prefs.setBool('invite_install_referrer_read', true);
}
