import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../app/telegram_route.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/selection/blab_selection_row.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'group_invite_screen.dart' show GroupInviteLinkScreen;

final groupInviteFriendsProvider = FutureProvider.autoDispose
    .family<List<GroupInviteFriend>, String>(
      (ref, chatId) =>
          ref.watch(chatServiceProvider).fetchGroupInviteFriends(chatId),
    );

class GroupInviteScreen extends ConsumerStatefulWidget {
  const GroupInviteScreen({
    super.key,
    required this.chatId,
    required this.initialToken,
    this.groupName,
  });
  final String chatId;
  final String? initialToken, groupName;
  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  final _selected = <String>{};
  String _query = '';
  bool _searching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  Widget _searchHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Material(
      key: const ValueKey('group-search-container'),
      color: const Color(0xFFEEE8DF),
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: context.l10n.back,
              onPressed: _closeSearch,
              icon: const Icon(Icons.arrow_back, size: 22),
              color: const Color(0xFF1F3340),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextField(
                  key: const ValueKey('group-friend-search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 24 / 17,
                    color: BlabColors.warmInk,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: context.l10n.groupSearchFriends,
                    hintStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: BlabColors.textMuted,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                key: const ValueKey('group-clear-search'),
                tooltip: context.l10n.groupClearSearch,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                  _searchFocus.requestFocus();
                },
                icon: const Icon(Icons.close, size: 22),
                color: BlabColors.textMuted,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(chatServiceProvider)
          .sendGroupInvitations(widget.chatId, _selected.toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      ref.invalidate(groupInviteFriendsProvider(widget.chatId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.groupInvitationsSent)),
      );
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.groupInvitationsFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(groupInviteFriendsProvider(widget.chatId));
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _searching) _closeSearch();
      },
      child: Scaffold(
        backgroundColor: BlabColors.chatCanvas,
        appBar: BlabAppBar(
          automaticallyImplyLeading: !_searching,
          leadingWidth: 64,
          titleSpacing: 0,
          centerTitle: false,
          title: _searching
              ? _searchHeader()
              : Text(
                  context.l10n.inviteFriends,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.warmInk,
                  ),
                ),
          actions: _searching
              ? null
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      key: const ValueKey('group-open-search'),
                      tooltip: context.l10n.groupSearchFriends,
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search, size: 22),
                      color: BlabColors.textMuted,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ],
          backgroundColor: BlabColors.chatCanvas,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(_searching),
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: ListTile(
                          key: const ValueKey('group-external-invite'),
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: 72,
                          horizontalTitleGap: 12,
                          visualDensity: VisualDensity.standard,
                          leading: const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFFEEE8DF),
                            child: Icon(
                              Icons.link,
                              size: 22,
                              color: BlabColors.warmInk,
                            ),
                          ),
                          title: Text(
                            context.l10n.groupInviteOutsideTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 22 / 15,
                              color: BlabColors.warmInk,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.groupShareLinkSubtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 20 / 14,
                              color: BlabColors.textMuted,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: BlabColors.textMuted,
                          ),
                          onTap: _sending
                              ? null
                              : () => Navigator.of(context).push(
                                  telegramRoute<void>(
                                    GroupInviteLinkScreen(
                                      chatId: widget.chatId,
                                      initialToken: widget.initialToken,
                                      groupName: widget.groupName,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      friends.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: TextButton.icon(
                            onPressed: () => ref.invalidate(
                              groupInviteFriendsProvider(widget.chatId),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.retry),
                          ),
                        ),
                        data: (all) {
                          final visible = all
                              .where(
                                (f) => f.name.toLowerCase().contains(_query),
                              )
                              .toList();
                          if (visible.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  all.isEmpty
                                      ? context.l10n.groupNoFriends
                                      : context.l10n.groupNoMatchingFriends,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: BlabColors.warmMuted,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            key: const ValueKey('group-friends-list'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final friend = visible[i];
                              final selected = _selected.contains(
                                friend.userId,
                              );
                              return BlabSelectionRow(
                                key: ValueKey('invite-friend-${friend.userId}'),
                                label: friend.name,
                                selected: selected,
                                leading: BlabAvatar(
                                  name: friend.name,
                                  size: 40,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  shadows: const [],
                                ),
                                subtitle: friend.invited
                                    ? Text(
                                        context.l10n.groupFriendInvited,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: BlabColors.textMuted,
                                        ),
                                      )
                                    : null,
                                trailing: friend.invited
                                    ? const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: BlabColors.textMuted,
                                      )
                                    : null,
                                onTap: _sending || friend.invited
                                    ? null
                                    : () => setState(() {
                                        if (selected) {
                                          _selected.remove(friend.userId);
                                        } else {
                                          _selected.add(friend.userId);
                                        }
                                      }),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      key: const ValueKey('group-send-individual-invites'),
                      style: FilledButton.styleFrom(
                        backgroundColor: BlabColors.brand,
                        foregroundColor: BlabColors.warmInk,
                        disabledBackgroundColor: BlabColors.disabledSurface,
                        disabledForegroundColor: BlabColors.disabledOnSurface,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _sending || _selected.isEmpty ? null : _send,
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _selected.isEmpty
                                  ? context.l10n.sendInvite
                                  : context.l10n.groupSendInvites(
                                      _selected.length,
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
