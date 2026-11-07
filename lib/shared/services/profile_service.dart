import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/languages.dart';
import '../models/onboarding_stage.dart';
import '../models/reading_script.dart';
import 'local_profile_cache.dart';

class UserProfile {
  const UserProfile({
    required this.displayName,
    this.avatarUrl,
    this.avatarPath,
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
      avatarUrl: row['avatar_url'] as String?,
      avatarPath: row['avatar_path'] as String?,
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
  final String? avatarUrl;
  final String? avatarPath;

  UserProfile withAvatarUrl(String? url) => UserProfile(
    displayName: displayName,
    avatarUrl: url,
    avatarPath: avatarPath,
    interfaceLanguage: interfaceLanguage,
    knownLanguages: knownLanguages,
    primaryKnownLanguage: primaryKnownLanguage,
    grammaticalForm: grammaticalForm,
    readingScript: readingScript,
    onboardingVersion: onboardingVersion,
    onboardingStage: onboardingStage,
  );
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
          'onboarding_version,onboarding_stage,avatar_path',
        )
        .eq('id', _uid)
        .single();
    try {
      row['avatar_url'] = await resolveAvatarPath(
        row['avatar_path'] as String?,
      );
    } catch (_) {
      row['avatar_url'] = null;
    }
    return UserProfile.fromRow(row);
  }

  Future<String?> resolveAvatarPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (isGoogleAvatarUrl(path)) return path;
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$',
    ).hasMatch(path)) {
      return null;
    }
    return _client.storage.from('profile-avatars').createSignedUrl(path, 60);
  }

  Future<void> updateAvatar(Uint8List? bytes) async {
    final account = _uid;
    String? path;
    if (bytes != null) {
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw ArgumentError('invalid_avatar_size');
      }
      image.Image? decoded;
      try {
        decoded = image.decodeJpg(bytes);
      } catch (_) {
        throw ArgumentError('invalid_avatar_image');
      }
      if (decoded == null || decoded.width > 2048 || decoded.height > 2048) {
        throw ArgumentError('invalid_avatar_image');
      }
      path = '$account/AVATAR_UUID.jpg'.replaceFirst(
        'AVATAR_UUID',
        const Uuid().v4(),
      );
      await _client.storage
          .from('profile-avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }
    try {
      if (_client.auth.currentUser?.id != account) {
        throw StateError('account_changed');
      }
      final previous = await _client.rpc(
        'update_my_avatar',
        params: {'p_path': path, 'p_expected_actor': account},
      );
      if (previous is String &&
          previous.startsWith('$account/') &&
          previous != path &&
          _client.auth.currentUser?.id == account) {
        try {
          await _client.storage.from('profile-avatars').remove([previous]);
        } catch (_) {}
      }
    } catch (_) {
      // An interrupted response can follow a committed write. Never delete the
      // new object here; the server's grace-period collector owns orphan cleanup.
      rethrow;
    }
    await _invalidateCachedProfile(account);
  }

  Future<String> updateDisplayName(String displayName) async {
    final account = _client.auth.currentUser?.id;
    final value = await _client.rpc(
      'update_my_display_name',
      params: {'p_display_name': displayName},
    );
    if (value is! String || value.isEmpty) {
      throw StateError('invalid_profile_response');
    }
    await _invalidateCachedProfile(account);
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
    final account = _client.auth.currentUser?.id;
    final value = await _client.rpc(
      'update_my_interface_language',
      params: {'p_interface_language': languageCode},
    );
    if (value is! String || value.isEmpty) {
      throw StateError('invalid_profile_response');
    }
    await _invalidateCachedProfile(account);
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
    final account = _client.auth.currentUser?.id;
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
    await _invalidateCachedProfile(account);
    return saved;
  }

  Future<void> setKnownLanguages({
    required List<String> languageCodes,
    required String primaryCode,
  }) async {
    final account = _client.auth.currentUser?.id;
    await _client
        .from('profiles')
        .update({
          'known_languages': languageCodes,
          'primary_known_language': primaryCode,
        })
        .eq('id', _uid);
    await _invalidateCachedProfile(account);
  }

  Future<OnboardingProgress> acknowledgeOnboarding({
    int version = currentOnboardingVersion,
  }) async {
    final account = _client.auth.currentUser?.id;
    final value = await _client.rpc(
      'acknowledge_my_onboarding',
      params: {'p_version': version},
    );
    final progress = _onboardingProgress(value);
    await _invalidateCachedProfile(account);
    return progress;
  }

  Future<OnboardingProgress> confirmOnboardingName(
    String displayName, {
    int version = currentOnboardingVersion,
  }) async {
    final account = _client.auth.currentUser?.id;
    final value = await _client.rpc(
      'confirm_my_onboarding_name',
      params: {'p_version': version, 'p_display_name': displayName},
    );
    final progress = _onboardingProgress(value);
    await _invalidateCachedProfile(account);
    return progress;
  }

  Future<OnboardingProgress> confirmOnboardingLanguage(
    String languageCode, {
    int version = currentOnboardingVersion,
  }) async {
    final account = _client.auth.currentUser?.id;
    final value = await _client.rpc(
      'confirm_my_onboarding_language',
      params: {'p_version': version, 'p_language': languageCode},
    );
    final progress = _onboardingProgress(value);
    await _invalidateCachedProfile(account);
    return progress;
  }

  Future<void> _invalidateCachedProfile(String? account) async {
    if (account == null) return;
    try {
      await LocalProfileCache(account).clear();
    } catch (_) {}
  }

  OnboardingProgress _onboardingProgress(Object? value) {
    if (value is! Map) {
      throw StateError('invalid_profile_response');
    }
    return OnboardingProgress.fromJson(Map<String, dynamic>.from(value));
  }
}

bool isGoogleAvatarUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      (uri.host == 'googleusercontent.com' ||
          uri.host.endsWith('.googleusercontent.com'));
}
