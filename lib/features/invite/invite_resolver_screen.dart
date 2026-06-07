import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/state/chat_list_state.dart';
import 'invite_landing_screen.dart';

/// Entry point for incoming `blab://i/<token>` deep links. Fetches the
/// invite metadata via the `get_invite` RPC, then renders the existing
/// [InviteLandingScreen] with the matching status. Token is passed
/// through to the Accept → pick-language step.
class InviteResolverScreen extends ConsumerWidget {
  const InviteResolverScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(_inviteMetadataProvider(token));
    return metaAsync.when(
      data: (meta) {
        if (meta == null) {
          return const _InviteNotFoundScreen();
        }
        final status = switch (meta.status) {
          'valid' => InviteStatus.valid,
          'expired' => InviteStatus.expired,
          'used' => InviteStatus.used,
          _ => InviteStatus.expired,
        };
        return InviteLandingScreen(
          status: status,
          inviterName: meta.inviterName.isEmpty
              ? 'A friend'
              : meta.inviterName,
          inviterLearningCode: meta.inviterLearningLanguage,
          token: status == InviteStatus.valid ? token : null,
        );
      },
      loading: () => const Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _InviteNotFoundScreen(),
    );
  }
}

final _inviteMetadataProvider =
    FutureProvider.family<InviteMetadata?, String>((ref, token) {
  return ref.watch(chatServiceProvider).getInvite(token);
});

class _InviteNotFoundScreen extends StatelessWidget {
  const _InviteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.link_off,
                  size: 56, color: BlabColors.textMuted),
              SizedBox(height: 18),
              Text(
                "We couldn't find that invite.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Check the link is correct, or ask for a new one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: BlabColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
