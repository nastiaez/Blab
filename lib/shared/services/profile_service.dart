import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/languages.dart';
import '../models/onboarding_stage.dart';
import '../models/reading_script.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    this.interfaceLanguage = 'en',
    this.knownLanguages = const [],
    this.primaryKnownLanguage,
    this.grammaticalForm,
    this.readingScript = ReadingScript.native,
    this.onboardingVersion = 0,
    this.onboardingStage = OnboardingStage.intro,
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
      grammaticalForm: row['grammatical_form'] as String?,
      readingScript: readingScriptFromWire(row['reading_script'] as String?),
      onboardingVersion: (row['onboarding_version'] as num?)?.toInt() ?? 0,
      onboardingStage: onboardingStageFromWire(
        row['onboarding_stage'] as String?,
      ),
    );
  }

  final String displayName;
  final String interfaceLanguage;
  final List<String> knownLanguages;
  final String? primaryKnownLanguage;
  final String? grammaticalForm;
  final ReadingScript readingScript;
  final int onboardingVersion;
  final OnboardingStage onboardingStage;

  bool get hasExplicitTranslationLanguage {
    final primary = primaryKnownLanguage;
    return primary != null &&
        knownLanguages.contains(primary) &&
        kBlabLanguages.any((language) => language.code == primary);
  }
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
          'primary_known_language,grammatical_form,reading_script,'
          'onboarding_version,onboarding_stage',
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

  Future<String> fetchReadingScript() async {
    final row = await _client
        .from('profiles')
        .select('reading_script')
        .eq('id', _uid)
        .single();
    return row['reading_script'] as String;
  }

  Future<String> updateReadingScript(String value) async {
    final row = await _client
        .from('profiles')
        .update({'reading_script': value})
        .eq('id', _uid)
        .select('reading_script')
        .single();
    final saved = row['reading_script'];
    if (saved is! String || saved.isEmpty) {
      throw StateError('invalid_profile_response');
    }
    return saved;
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

  Future<OnboardingProgress> acknowledgeOnboarding({
    int version = currentOnboardingVersion,
  }) async {
    final value = await _client.rpc(
      'acknowledge_my_onboarding',
      params: {'p_version': version},
    );
    return _onboardingProgress(value);
  }

  Future<OnboardingProgress> confirmOnboardingName(
    String displayName, {
    int version = currentOnboardingVersion,
  }) async {
    final value = await _client.rpc(
      'confirm_my_onboarding_name',
      params: {'p_version': version, 'p_display_name': displayName},
    );
    return _onboardingProgress(value);
  }

  Future<OnboardingProgress> confirmOnboardingLanguage(
    String languageCode, {
    int version = currentOnboardingVersion,
  }) async {
    final value = await _client.rpc(
      'confirm_my_onboarding_language',
      params: {'p_version': version, 'p_language': languageCode},
    );
    return _onboardingProgress(value);
  }

  OnboardingProgress _onboardingProgress(Object? value) {
    if (value is! Map) {
      throw StateError('invalid_profile_response');
    }
    return OnboardingProgress.fromJson(Map<String, dynamic>.from(value));
  }
}
