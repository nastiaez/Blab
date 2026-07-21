import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PushTokenRepository {
  Future<void> register({required String token, required bool previewsEnabled});

  Future<void> unregister(String token);
}

class SupabasePushTokenRepository implements PushTokenRepository {
  const SupabasePushTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required bool previewsEnabled,
  }) async {
    await _client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': 'android',
        'p_previews_enabled': previewsEnabled,
      },
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_push_token', params: {'p_token': token});
  }
}
