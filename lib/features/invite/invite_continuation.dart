import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/data/local_storage_keys.dart';
import '../../shared/state/chat_list_state.dart';

/// Stores only the token needed to resume an invite after the regular email
/// sign-in. It deliberately carries no language or account-choice state.
class InviteContinuation {
  const InviteContinuation({
    required this.token,
    this.inviterName,
    this.learningLanguage,
  });

  factory InviteContinuation.fromQuery(Map<String, String> query) =>
      InviteContinuation(
        token: query['invite'],
        inviterName: query['inviter'],
        learningLanguage: query['learn'],
      );

  final String? token;
  final String? inviterName;
  final String? learningLanguage;

  bool get canResume => token?.trim().isNotEmpty == true;

  String authLocation({String mode = 'signup'}) => Uri(
    path: '/auth',
    queryParameters: {
      'mode': mode,
      if (canResume) 'invite': token!.trim(),
      if (inviterName?.trim().isNotEmpty == true)
        'inviter': inviterName!.trim(),
      if (learningLanguage?.trim().isNotEmpty == true)
        'learn': learningLanguage!.trim(),
    },
  ).toString();

  String get resolverLocation => '/i/${Uri.encodeComponent(token!.trim())}';
}

Future<void> savePendingInvite(String token) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(kPendingInviteTokenKey, token.trim());
}

Future<String?> loadPendingInvite() async {
  final preferences = await SharedPreferences.getInstance();
  final token = preferences.getString(kPendingInviteTokenKey)?.trim();
  return token?.isEmpty ?? true ? null : token;
}

Future<void> clearPendingInvite() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove(kPendingInviteTokenKey);
}

enum InviteClaimFailure {
  expired,
  alreadyClaimed,
  notFound,
  selfClaim,
  invalidLanguage,
  unknown,
}

InviteClaimFailure inviteClaimFailureFor(Object error) {
  final code = error is PostgrestException ? error.message : '';
  return switch (code) {
    'invite_expired' => InviteClaimFailure.expired,
    'invite_already_claimed' => InviteClaimFailure.alreadyClaimed,
    'invite_not_found' => InviteClaimFailure.notFound,
    'invite_self_claim' => InviteClaimFailure.selfClaim,
    'invalid_language' => InviteClaimFailure.invalidLanguage,
    _ => InviteClaimFailure.unknown,
  };
}

bool isTerminalInviteClaimFailure(InviteClaimFailure failure) =>
    failure != InviteClaimFailure.unknown &&
    failure != InviteClaimFailure.invalidLanguage;

String localizedInviteClaimMessage(
  AppLocalizations localizations,
  InviteClaimFailure failure,
) => switch (failure) {
  InviteClaimFailure.expired => 'This invite is no longer available.',
  InviteClaimFailure.alreadyClaimed => 'This invite has already been claimed',
  InviteClaimFailure.notFound => "We couldn’t find that invite.",
  InviteClaimFailure.selfClaim => "You can’t use your own invite.",
  InviteClaimFailure.invalidLanguage =>
    'Choose a supported language and try again.',
  InviteClaimFailure.unknown => 'Couldn’t accept the invite. Try again.',
};

typedef InviteClaimAction = Future<String> Function(InviteContinuation);

final inviteClaimActionProvider = Provider<InviteClaimAction>((ref) {
  final service = ref.watch(chatServiceProvider);
  return (continuation) async {
    if (!continuation.canResume) {
      throw ArgumentError('Incomplete invite continuation');
    }
    final result = await service.claimInviteDetails(
      token: continuation.token!.trim(),
    );
    await ref.read(chatListProvider.notifier).refresh();
    return result.chatId;
  };
});
