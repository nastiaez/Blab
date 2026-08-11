import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    this.interfaceLanguage = 'en',
    this.knownLanguages = const [],
    this.primaryKnownLanguage,
  });

  factory UserProfile.fromRow(Map<String, dynamic> row) {
    return UserProfile(
      displayName: row['display_name'] as String,
      interfaceLanguage: row['interface_language'] as String,
      knownLanguages:
          (row['known_languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      primaryKnownLanguage: row['primary_known_language'] as String?,
    );
  }

  final String displayName;
  final String interfaceLanguage;
  final List<String> knownLanguages;
  final String? primaryKnownLanguage;
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
        .select(
          'display_name,interface_language,known_languages,'
          'primary_known_language',
        )
        .eq('id', _uid)
        .single();
    return UserProfile.fromRow(row);
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

  Future<void> setKnownLanguages({
    required List<String> languageCodes,
    required String primaryCode,
  }) async {
    await _client
        .from('profiles')
        .update({
          'known_languages': languageCodes,
          'primary_known_language': primaryCode,
        })
        .eq('id', _uid);
  }
}
