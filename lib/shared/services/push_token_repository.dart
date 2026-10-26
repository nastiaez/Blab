import '../data/firebase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PushTokenRepository {
  Future<void> register({required String token, required bool previewsEnabled});

  Future<void> unregister(String token);
}

PushTokenRepository createPushTokenRepository(SupabaseClient client) =>
    const bool.fromEnvironment('BLAB_STREAM_REVIEW')
    ? StreamPushTokenRepository(client)
    : SupabasePushTokenRepository(client);

/// A leased server command owns both chat providers' device registrations.
class StreamPushTokenRepository implements PushTokenRepository {
  const StreamPushTokenRepository(this._client);
  final SupabaseClient _client;
  Future<void> _command(String action, String token, bool previews) async {
    final owner = _client.auth.currentUser?.id;
    if (owner == null) throw StateError('not_signed_in');
    final result = await _client.functions.invoke(
      'stream-device',
      body: {'action': action, 'token': token, 'previewsEnabled': previews},
    );
    if (_client.auth.currentUser?.id != owner) {
      throw StateError('account_changed');
    }
    if (result.status != 200 ||
        result.data is! Map ||
        result.data['ok'] != true) {
      throw StateError('push_registration_unavailable');
    }
  }

  @override
  Future<void> register({
    required String token,
    required bool previewsEnabled,
  }) => _command('register', token, previewsEnabled);
  @override
  Future<void> unregister(String token) => _command('unregister', token, false);
}

class SupabasePushTokenRepository implements PushTokenRepository {
  const SupabasePushTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required bool previewsEnabled,
  }) async {
    if (BlabFirebaseConfig.isAndroidPlatform) {
      try {
        await _client.rpc(
          'register_custom_android_push_token',
          params: {'p_token': token, 'p_previews_enabled': previewsEnabled},
        );
        return;
      } on PostgrestException catch (error) {
        if (error.code != 'PGRST202') rethrow;
        // An app may be installed before the capability migration is rolled out.
      }
    }
    await _client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': BlabFirebaseConfig.isIosPlatform ? 'ios' : 'android',
        'p_previews_enabled': previewsEnabled,
      },
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_push_token', params: {'p_token': token});
  }
}
