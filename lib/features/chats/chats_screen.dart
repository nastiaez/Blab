import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/mock_chats.dart';
import '../../shared/models/chat.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import 'widgets/chat_list_tile.dart';

/// PRD US-006, US-007, US-026.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    super.key,
    this.empty = false,
    this.asAswin = false,
  });

  final bool empty;

  /// When true, render Aswin's POV — a single chat with Nastia in
  /// invite-state styling. PRD US-026.
  final bool asAswin;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  /// Synthetic cold-open delay so the skeleton actually appears on first
  /// paint. Cached so rebuilds don't re-trigger the delay. PRD US-032.
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _refresh() async {
    // Mock — Step 2.2 will fetch from Supabase. PRD US-032.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final List<Chat> chats = widget.empty
        ? const []
        : (widget.asAswin ? kAswinMockChats : kMockChats);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => context.push('/chats/new'),
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BlabColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add,
                  color: BlabColors.brand, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: FutureBuilder<void>(
              future: _ready,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const ChatListSkeleton();
                }
                if (chats.isEmpty) return const _EmptyState();
                return RefreshIndicator(
                  color: BlabColors.brand,
                  onRefresh: _refresh,
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
      bottomNavigationBar: const _BottomTabs(active: _Tab.chats),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
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
              'Invite someone to start swapping languages.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: BlabColors.textMuted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.push('/chats/new'),
              child: const Text(
                'Invite someone',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
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
                icon: Icons.chat_bubble_outline,
                iconActive: Icons.chat_bubble,
                label: 'Chats',
                selected: active == _Tab.chats,
                onTap: () {},
              ),
              _TabItem(
                icon: Icons.person_outline,
                iconActive: Icons.person,
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
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconActive;
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
            Icon(selected ? iconActive : icon, color: color, size: 22),
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
