import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/state/chat_list_state.dart';

class InviteContinuation {
  const InviteContinuation({
    required this.token,
    required this.inviterName,
    required this.learningLanguage,
  });

  factory InviteContinuation.fromQuery(Map<String, String> query) {
    return InviteContinuation(
      token: query['invite'],
      inviterName: query['inviter'],
      learningLanguage: query['learn'],
    );
  }

  final String? token;
  final String? inviterName;
  final String? learningLanguage;

  bool get canResume =>
      token?.trim().isNotEmpty == true &&
      learningLanguage?.trim().isNotEmpty == true;

  String authLocation({String mode = 'signup'}) {
    return Uri(
      path: '/auth',
      queryParameters: {
        'mode': mode,
        if (token?.trim().isNotEmpty == true) 'invite': token!.trim(),
        if (inviterName?.trim().isNotEmpty == true)
          'inviter': inviterName!.trim(),
        if (learningLanguage?.trim().isNotEmpty == true)
          'learn': learningLanguage!.trim(),
      },
    ).toString();
  }

  String get resolverLocation => '/i/${Uri.encodeComponent(token!.trim())}';
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

bool isTerminalInviteClaimFailure(InviteClaimFailure failure) {
  return switch (failure) {
    InviteClaimFailure.expired ||
    InviteClaimFailure.alreadyClaimed ||
    InviteClaimFailure.notFound ||
    InviteClaimFailure.selfClaim => true,
    InviteClaimFailure.invalidLanguage || InviteClaimFailure.unknown => false,
  };
}

String inviteClaimMessage(InviteClaimFailure failure) {
  return switch (failure) {
    InviteClaimFailure.expired => 'This invite has expired.',
    InviteClaimFailure.alreadyClaimed => 'This invite has already been used.',
    InviteClaimFailure.notFound => "We couldn't find that invite.",
    InviteClaimFailure.selfClaim => "You can't accept your own invite.",
    InviteClaimFailure.invalidLanguage =>
      'Choose a supported language and try again.',
    InviteClaimFailure.unknown => "Couldn't accept the invite. Try again.",
  };
}

typedef InviteClaimAction =
    Future<String> Function(InviteContinuation continuation);

final inviteClaimActionProvider = Provider<InviteClaimAction>((ref) {
  final service = ref.watch(chatServiceProvider);
  return (continuation) async {
    if (!continuation.canResume) {
      throw ArgumentError('Incomplete invite continuation');
    }
    final chatId = await service.claimInvite(
      token: continuation.token!.trim(),
      myLearningLanguage: continuation.learningLanguage!.trim(),
    );
    await ref.read(chatListProvider.notifier).refresh();
    return chatId;
  };
});
