import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/picker_card.dart';
import '../../shared/widgets/skeletons.dart';
import 'widgets/chat_list_tile.dart';

/// PRD US-006, US-007, US-026.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key, this.preview = false});

  /// When true, always renders the empty state (used by dev preview route).
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(visibleChatsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: SvgPicture.asset('assets/blab-logo.svg', height: 22),
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
                final chats = chatsAsync.value;
                if (chats == null) {
                  if (chatsAsync.isLoading) return const ChatListSkeleton();
                  return _ErrorState(detail: chatsAsync.error?.toString());
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
                      color: Colors.grey.shade100,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chats/new'),
        backgroundColor: BlabColors.brand,
        foregroundColor: Colors.white,
        elevation: 3,
        tooltip: 'New chat',
        child: const Icon(Icons.add, size: 26),
      ),
      bottomNavigationBar: const _BottomTabs(active: _Tab.chats),
    );
  }
}

class ChatsEmptyState extends StatelessWidget {
  const ChatsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Invite a friend and start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: BlabColors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 180,
              child: BrandButton(
                label: 'Invite a friend',
                onPressed: () => context.push('/chats/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.detail});
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load chats",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: BlabColors.textMuted),
            ),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detail!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Tab { chats, profile }

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.active});
  final _Tab active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                iconName: 'chat',
                label: 'Chats',
                selected: active == _Tab.chats,
                onTap: () {},
              ),
              _TabItem(
                iconName: 'profile',
                label: 'Profile',
                selected: active == _Tab.profile,
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.iconName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String iconName;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BlabColors.brand : BlabColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlabIcon(name: iconName, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
