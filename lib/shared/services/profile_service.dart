import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({required this.displayName, this.interfaceLanguage = 'en'});

  final String displayName;
  final String interfaceLanguage;
}

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  Future<UserProfile> fetchCurrentProfile() async {
    final row = await _client
        .from('profiles')
        .select('display_name,interface_language')
        .eq('id', _uid)
        .single();
    return UserProfile(
      displayName: row['display_name'] as String,
      interfaceLanguage: row['interface_language'] as String,
    );
  }

  Future<String> updateDisplayName(String displayName) async {
    final value = await _client.rpc(
      'update_my_display_name',
      params: {'p_display_name': displayName},
    );
    if (value is! String || value.isEmpty) {
      throw StateError('invalid_profile_response');
    }
    return value;
  }

  Future<String> fetchInterfaceLanguage() async {
    final row = await _client
        .from('profiles')
        .select('interface_language')
        .eq('id', _uid)
        .single();
    return row['interface_language'] as String;
  }

  Future<String> updateInterfaceLanguage(String languageCode) async {
    final value = await _client.rpc(
      'update_my_interface_language',
      params: {'p_interface_language': languageCode},
    );
    if (value is! String || value.isEmpty) {
      throw StateError('invalid_profile_response');
    }
    return value;
  }
}
