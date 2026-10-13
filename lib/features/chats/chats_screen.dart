import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../shared/widgets/actions/blab_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../shared/widgets/navigation/blab_navigation_bar.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import 'widgets/chat_list_tile.dart';

/// PRD US-006, US-007, US-026.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key, this.preview = false});

  /// When true, always renders the empty state (used by dev preview route).
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);
    final chats = chatsAsync.value;
    final hasConfirmedEmptyList = preview || (chats != null && chats.isEmpty);
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.chatCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: SvgPicture.asset('assets/blab-logo 2.svg', height: 22),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Builder(
              builder: (context) {
                if (preview) return const ChatsEmptyState();
                // Show last-known data even during transient errors
                // (offline, token refresh, etc.) instead of collapsing
                // to the skeleton.
                if (chats == null) {
                  if (chatsAsync.isLoading) return const ChatListSkeleton();
                  return ChatsErrorState(
                    onRetry: () =>
                        ref.read(chatListProvider.notifier).refresh(),
                  );
                }
                if (chats.isEmpty) return const ChatsEmptyState();
                return RefreshIndicator(
                  color: BlabColors.brand,
                  onRefresh: () =>
                      ref.read(chatListProvider.notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: chats.length,
                    separatorBuilder: (context, i) => Divider(
                      height: 1,
                      indent: 76,
                      color: BlabColors.chatDivider,
                    ),
                    itemBuilder: (context, i) {
                      final c = chats[i];
                      return ChatListTile(
                        chat: c,
                        onTap: () => context.push('/chat/${c.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: hasConfirmedEmptyList
          ? null
          : Theme(
              data: Theme.of(context).copyWith(
                floatingActionButtonTheme: Theme.of(context)
                    .floatingActionButtonTheme
                    .copyWith(
                      sizeConstraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                    ),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x21231208),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: () => context.push('/chats/new'),
                  shape: const CircleBorder(),
                  backgroundColor: BlabColors.brand,
                  foregroundColor: BlabColors.warmInk,
                  elevation: 0,
                  tooltip: context.l10n.newChat,
                  child: const BlabIcon(
                    name: 'plus - 20',
                    color: BlabColors.warmInk,
                    size: 20,
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BlabNavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index != 0) context.go(index == 0 ? '/chats' : '/profile');
        },
      ),
    );
  }
}

class ChatsEmptyState extends StatelessWidget {
  const ChatsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const verticalPadding = 24.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (verticalPadding * 2),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/empty-chats-friends.png',
                    width: 240,
                    height: 172,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10n.noChatsYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.inviteFriendStart,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: BlabColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 180,
                    child: BlabButton.account(
                      label: context.l10n.inviteFriend,
                      onPressed: () => context.push('/chats/new'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatsErrorState extends StatelessWidget {
  const ChatsErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.couldNotLoadChats,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: BlabColors.error),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const ValueKey('chat-list-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
