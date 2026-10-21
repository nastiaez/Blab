import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_messenger.dart';
import '../../app/telegram_route.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/services/local_chat_history_cache.dart';
import '../chat/chat_screen.dart';
import '../chat/widgets/chat_lifecycle_dialog.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../shared/widgets/surfaces/blab_dialog.dart';
import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import 'group_invite_screen.dart';

const _groupReadTimeout = Duration(seconds: 8);

Stream<T> _watchRetainedGroupData<T>({
  required Ref ref,
  required Future<T> Function() fetch,
  required Stream<void> changes,
  Future<T?> Function()? load,
  Future<void> Function(T)? save,
  Future<void> Function()? clear,
  T? deniedValue,
}) async* {
  T? last;
  try {
    last = await load?.call();
  } catch (_) {
    /* Cache is best-effort. */
  }
  if (last != null) yield last;
  final triggers = StreamController<void>();
  void refresh() {
    if (!triggers.isClosed) triggers.add(null);
  }

  var needsRecovery = true;
  final subscription = changes.listen(
    (_) => refresh(),
    onError: (Object _) => needsRecovery = true,
  );
  final recovery = Timer.periodic(const Duration(seconds: 10), (_) {
    if (needsRecovery) refresh();
  });
  ref.onDispose(() {
    recovery.cancel();
    unawaited(subscription.cancel());
    unawaited(triggers.close());
  });
  refresh();
  try {
    await for (final _ in triggers.stream) {
      try {
        final value = await fetch().timeout(_groupReadTimeout);
        if (!ref.mounted) return;
        last = value;
        needsRecovery = false;
        if (save != null) unawaited(save(value).catchError((Object _) {}));
        yield value;
      } catch (error, stack) {
        needsRecovery = true;
        if (error is PostgrestException && error.code == '42501') {
          await clear?.call();
          if (deniedValue != null) yield deniedValue;
          yield* Stream<T>.error(error, stack);
          return;
        }
        if (last == null) yield* Stream<T>.error(error, stack);
      }
    }
  } finally {
    recovery.cancel();
    await subscription.cancel();
    await triggers.close();
  }
}

final groupMembersProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) {
      ref.watch(currentUserIdProvider);
      final service = ref.watch(chatServiceProvider);
      final cache = ref.watch(localChatHistoryCacheProvider);
      return _watchRetainedGroupData<List<Map<String, dynamic>>>(
        ref: ref,
        fetch: () => service.fetchGroupMembers(id),
        changes: service.watchGroupMemberChanges(id),
        load: cache == null ? null : () => cache.loadGroupMembers(id),
        save: cache == null ? null : (rows) => cache.saveGroupMembers(id, rows),
        clear: cache == null ? null : () => cache.clearGroupMembers(id),
        deniedValue: const [],
      );
    }, retry: (_, _) => null);

final groupPhotosProvider = StreamProvider.autoDispose
    .family<List<MessageAttachment>, String>((ref, id) {
      ref.watch(currentUserIdProvider);
      final service = ref.watch(chatServiceProvider);
      final cache = ref.watch(localChatHistoryCacheProvider);
      return _watchRetainedGroupData<List<MessageAttachment>>(
        ref: ref,
        fetch: () => service.fetchGroupPhotos(id),
        changes: service.watchMessageChanges(id).map((_) {}),
        load: cache == null ? null : () => cache.loadGroupPhotos(id),
        save: cache == null
            ? null
            : (photos) => cache.saveGroupPhotos(id, photos),
        clear: cache == null ? null : () => cache.clearGroupMembers(id),
        deniedValue: const [],
      );
    }, retry: (_, _) => null);

final groupNotificationsProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, id) {
      ref.watch(currentUserIdProvider);
      final service = ref.watch(chatServiceProvider);
      final cache = ref.watch(localChatHistoryCacheProvider);
      return _watchRetainedGroupData<bool>(
        ref: ref,
        fetch: () => service.fetchGroupNotifications(id),
        changes: service.watchGroupMemberChanges(id),
        load: cache == null ? null : () => cache.loadGroupNotifications(id),
        save: cache == null
            ? null
            : (enabled) => cache.saveGroupNotifications(id, enabled),
        clear: cache == null ? null : () => cache.clearGroupMembers(id),
      );
    }, retry: (_, _) => null);

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({
    super.key,
    required this.chat,
    this.allMembers = false,
  });
  final Chat chat;
  final bool allMembers;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final current =
        ref
            .read(chatListProvider)
            .asData
            ?.value
            .where((entry) => entry.id == chat.id)
            .firstOrNull ??
        chat;
    if (current.ownerId == ref.read(currentUserIdProvider) &&
        current.memberCount > 1) {
      await showGroupOwnerLeaveNotice(context);
      return;
    }
    final close = current.ownerId == ref.read(currentUserIdProvider);
    final confirmed = await showChatLifecycleConfirmation(
      context,
      title: close
          ? context.l10n.closeGroupQuestion
          : context.l10n.leaveGroupQuestion,
      message: close
          ? context.l10n.closeGroupBody
          : context.l10n.leaveGroupBody,
      confirmLabel: close ? context.l10n.closeGroup : context.l10n.leaveGroup,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(chatServiceProvider).leaveGroup(chat.id);
      await ref.read(chatListProvider.notifier).refresh();
      if (context.mounted) context.go('/chats');
    } catch (error) {
      if (!context.mounted) return;
      if (error.toString().contains('owner_transfer_required')) {
        await showGroupOwnerLeaveNotice(context);
      } else {
        showAppSnack(context.l10n.couldNotUpdateGroup);
      }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      telegramRoute<void>(
        EditGroupScreen(
          chat:
              ref
                  .read(chatListProvider)
                  .value
                  ?.where((c) => c.id == chat.id)
                  .firstOrNull ??
              chat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final knownChats = ref.watch(chatListProvider).asData?.value;
    if (knownChats != null && !knownChats.any((entry) => entry.id == chat.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/chats');
      });
      return const Scaffold(backgroundColor: BlabColors.chatCanvas);
    }
    final current =
        ref
            .watch(chatListProvider)
            .value
            ?.where((c) => c.id == chat.id)
            .firstOrNull ??
        chat;
    final uid = ref.watch(currentUserIdProvider);
    final owner = current.ownerId == uid;
    final members = ref.watch(groupMembersProvider(chat.id));
    final rows = members.asData?.value ?? const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        title: Text(
          allMembers ? context.l10n.groupMembersTitle : context.l10n.groupInfo,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.warmInk,
          ),
        ),
        backgroundColor: BlabColors.chatCanvas,
        actions: [
          if (owner && !allMembers)
            PopupMenuButton<String>(
              onSelected: (_) => _edit(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.l10n.editGroupName),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (!allMembers) ...[
            Center(
              child: BlabAvatar(
                name: current.partnerName,
                size: 56,
                fontSize: 20,
                shadows: null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              current.partnerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: BlabColors.warmInk,
              ),
            ),
            const SizedBox(height: 18),
            _GroupMedia(chatId: chat.id),
          ],
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.l10n.groupMembersTitle.toUpperCase()} · ${members.hasValue ? rows.length : current.memberCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.warmMuted,
                    ),
                  ),
                ),
                if (!allMembers && rows.length > 5)
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      telegramRoute<void>(
                        GroupInfoScreen(chat: current, allMembers: true),
                      ),
                    ),
                    child: Text(context.l10n.seeAll),
                  ),
              ],
            ),
          ),
          if (!members.hasValue)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: members.hasError
                  ? Text(context.l10n.somethingWentWrong)
                  : const LinearProgressIndicator(),
            ),
          BlabSectionCard.flush(
            children: [
              if (!allMembers)
                SizedBox(
                  height: 48,
                  child: ListTile(
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEEE8DF),
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: BlabColors.warmInk,
                      ),
                    ),
                    title: Text(
                      context.l10n.inviteFriends,
                      style: const TextStyle(fontSize: 15),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.of(context).push<void>(
                      telegramRoute<void>(
                        GroupInviteScreen(
                          chatId: chat.id,
                          initialToken: null,
                          groupName: current.partnerName,
                        ),
                      ),
                    ),
                  ),
                ),
              for (final member in allMembers ? rows : rows.take(5))
                _GroupMemberRow(
                  member: member,
                  currentUserId: uid,
                  onTap: member['user_id'] == uid
                      ? null
                      : (rowContext) async {
                          final blocked =
                              ref
                                  .read(blockedUserIdsProvider)
                                  .value
                                  ?.contains(member['user_id']) ??
                              false;
                          final rowBox =
                              rowContext.findRenderObject()! as RenderBox;
                          final overlay =
                              Navigator.of(
                                    context,
                                  ).overlay!.context.findRenderObject()!
                                  as RenderBox;
                          final origin = rowBox.localToGlobal(
                            Offset.zero,
                            ancestor: overlay,
                          );
                          final selected = await showMenu<String>(
                            context: context,
                            color: BlabColors.chatSurface,
                            constraints: const BoxConstraints.tightFor(
                              width: 266,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: BlabColors.chatDivider,
                              ),
                            ),
                            position: RelativeRect.fromRect(
                              Rect.fromLTWH(
                                origin.dx,
                                origin.dy + rowBox.size.height,
                                rowBox.size.width,
                                0,
                              ),
                              Offset.zero & overlay.size,
                            ),
                            items: [
                              PopupMenuItem(
                                value: 'message',
                                height: 52,
                                child: _MemberMenuLabel(
                                  icon: 'chat-bubble-empty - 20',
                                  label: blocked
                                      ? context.l10n.unblockAndMessage
                                      : context.l10n.messageMember,
                                ),
                              ),
                              if (owner)
                                PopupMenuItem(
                                  value: 'owner',
                                  height: 52,
                                  child: _MemberMenuLabel(
                                    icon: 'profile-circle - 20',
                                    label: context.l10n.makeGroupOwner,
                                  ),
                                ),
                              if (owner)
                                PopupMenuItem(
                                  value: 'remove',
                                  height: 52,
                                  child: _MemberMenuLabel(
                                    icon: 'log-out - 20',
                                    label: context.l10n.removeGroupMember,
                                  ),
                                ),
                            ],
                          );
                          if (selected == null || !context.mounted) return;
                          try {
                            final service = ref.read(chatServiceProvider);
                            if (selected == 'message') {
                              final id = await service.contactGroupMember(
                                chat.id,
                                member['user_id'] as String,
                                unblock: blocked,
                              );
                              ref.invalidate(blockedUserIdsProvider);
                              await ref
                                  .read(chatListProvider.notifier)
                                  .refresh();
                              if (context.mounted) context.go('/chat/$id');
                            } else if (selected == 'remove') {
                              final confirmed =
                                  await showChatLifecycleConfirmation(
                                    context,
                                    title:
                                        context.l10n.removeGroupMemberQuestion,
                                    message: context.l10n.removeGroupMemberBody(
                                      member['display_name'] as String,
                                    ),
                                    confirmLabel:
                                        context.l10n.removeGroupMember,
                                  );
                              if (!confirmed || !context.mounted) return;
                              await service.removeGroupMember(
                                chat.id,
                                member['user_id'] as String,
                              );
                              ref.invalidate(groupMembersProvider(chat.id));
                              await ref
                                  .read(chatListProvider.notifier)
                                  .refresh();
                            } else {
                              await service.transferGroupOwner(
                                chat.id,
                                member['user_id'] as String,
                              );
                              ref.invalidate(groupMembersProvider(chat.id));
                              ref.invalidate(chatListProvider);
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showAppSnack(context.l10n.couldNotUpdateGroup);
                            }
                          }
                        },
                ),
            ],
          ),
          if (!allMembers) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.settings.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.warmMuted,
                  ),
                ),
              ),
            ),
            BlabSectionCard.flush(
              children: [
                _GroupNotificationRow(chatId: chat.id),
                ListTile(
                  key: const ValueKey('group-delete'),
                  minTileHeight: 52,
                  leading: const BlabIcon(
                    name: 'trash - 20',
                    size: 20,
                    color: Color(0xFFC62828),
                  ),
                  title: Text(
                    context.l10n.deleteGroup,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    final confirmed = await showChatLifecycleConfirmation(
                      context,
                      title: context.l10n.deleteGroupQuestion,
                      message: context.l10n.deleteGroupConfirmation,
                      confirmLabel: context.l10n.deleteGroup,
                    );
                    if (!confirmed || !context.mounted) return;
                    try {
                      await ref
                          .read(chatListProvider.notifier)
                          .deleteChat(chat.id);
                      if (context.mounted) context.go('/chats');
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnack(context.l10n.couldNotDeleteChat);
                      }
                    }
                  },
                ),
                SizedBox(
                  height: 52,
                  child: ListTile(
                    key: const ValueKey('group-owner-leave'),
                    minTileHeight: 52,
                    leading: const BlabIcon(
                      name: 'log-out - 20',
                      size: 20,
                      color: Color(0xFFC62828),
                    ),
                    title: Text(
                      context.l10n.leaveGroup,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFFC62828),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _leave(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupNotificationRow extends ConsumerStatefulWidget {
  const _GroupNotificationRow({required this.chatId});
  final String chatId;
  @override
  ConsumerState<_GroupNotificationRow> createState() =>
      _GroupNotificationRowState();
}

class _GroupNotificationRowState extends ConsumerState<_GroupNotificationRow> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(groupNotificationsProvider(widget.chatId));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: ListTile(
        key: const ValueKey('group-notifications'),
        minTileHeight: 52,
        leading: const BlabIcon(
          name: 'bell - 20',
          color: BlabColors.warmMuted,
          size: 20,
        ),
        title: Text(
          context.l10n.notifications,
          style: const TextStyle(fontSize: 15, color: BlabColors.warmInk),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_saving || enabled.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                enabled.hasError
                    ? context.l10n.retry
                    : enabled.value == true
                    ? context.l10n.groupNotificationsOn
                    : context.l10n.groupNotificationsOff,
                style: const TextStyle(
                  fontSize: 14,
                  color: BlabColors.warmMuted,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: _saving || enabled.isLoading
            ? null
            : () async {
                if (enabled.hasError) {
                  ref.invalidate(groupNotificationsProvider(widget.chatId));
                  return;
                }
                final box = context.findRenderObject()! as RenderBox;
                final overlay =
                    Navigator.of(context).overlay!.context.findRenderObject()!
                        as RenderBox;
                final origin = box.localToGlobal(
                  Offset.zero,
                  ancestor: overlay,
                );
                final next = await showMenu<bool>(
                  context: context,
                  color: BlabColors.chatSurface,
                  position: RelativeRect.fromRect(
                    Rect.fromLTWH(
                      origin.dx,
                      origin.dy + box.size.height,
                      box.size.width,
                      0,
                    ),
                    Offset.zero & overlay.size,
                  ),
                  items: [
                    CheckedPopupMenuItem(
                      value: true,
                      checked: enabled.value == true,
                      child: Text(context.l10n.groupNotificationsOn),
                    ),
                    CheckedPopupMenuItem(
                      value: false,
                      checked: enabled.value == false,
                      child: Text(context.l10n.groupNotificationsOff),
                    ),
                  ],
                );
                if (next == null || next == enabled.value || !mounted) return;
                setState(() => _saving = true);
                try {
                  await ref
                      .read(chatServiceProvider)
                      .setGroupNotifications(widget.chatId, next);
                  final cache = ref.read(localChatHistoryCacheProvider);
                  if (cache != null) {
                    await cache
                        .saveGroupNotifications(widget.chatId, next)
                        .catchError((Object _) {});
                  }
                  ref.invalidate(groupNotificationsProvider(widget.chatId));
                } catch (_) {
                  if (context.mounted) {
                    showAppSnack(context.l10n.couldNotSaveNotifications);
                  }
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
      ),
    );
  }
}

Future<void> showGroupOwnerLeaveNotice(BuildContext context) =>
    showBlabDialog<void>(
      context: context,
      barrierColor: const Color(0x80000000),
      builder: (dialogContext) => BlabConfirmationDialog(
        backgroundColor: BlabColors.chatSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: BlabColors.chatDivider),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Text(
          context.l10n.groupOwnerLeaveTitle,
          style: const TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: BlabColors.warmInk,
          ),
        ),
        content: Text(
          context.l10n.groupOwnerLeaveBody,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            letterSpacing: 0,
            color: BlabColors.warmMuted,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: BlabColors.warmInk,
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.gotIt),
          ),
        ],
      ),
    );

class _GroupMemberRow extends StatelessWidget {
  const _GroupMemberRow({
    required this.member,
    required this.currentUserId,
    this.onTap,
  });
  final Map<String, dynamic> member;
  final String? currentUserId;
  final void Function(BuildContext)? onTap;
  @override
  Widget build(BuildContext context) {
    final name = (member['display_name'] as String?)?.trim();
    final label = name == null || name.isEmpty ? '?' : name;
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              BlabAvatar(name: label, size: 36, fontSize: 14, shadows: null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member['user_id'] == currentUserId
                      ? context.l10n.groupMemberYou(label)
                      : label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: BlabColors.warmInk,
                  ),
                ),
              ),
              if (member['is_owner'] == true)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEADFE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.l10n.groupOwner,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5F3C4B),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberMenuLabel extends StatelessWidget {
  const _MemberMenuLabel({required this.icon, required this.label});
  final String icon, label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      BlabIcon(name: icon, color: BlabColors.warmMuted, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, color: BlabColors.warmInk),
        ),
      ),
      const SizedBox(width: 12),
      const BlabIcon(
        name: 'nav-arrow-right - 20',
        color: BlabColors.warmMuted,
        size: 20,
      ),
    ],
  );
}

class EditGroupScreen extends ConsumerStatefulWidget {
  const EditGroupScreen({super.key, required this.chat});
  final Chat chat;
  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  late final _name = TextEditingController(text: widget.chat.partnerName);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await ref
          .read(chatServiceProvider)
          .renameGroup(widget.chat.id, _name.text);
      ref.invalidate(chatListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.couldNotUpdateGroup);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlabColors.chatCanvas,
    appBar: BlabAppBar(
      backgroundColor: BlabColors.chatCanvas,
      title: Text(
        context.l10n.editGroupName,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BlabColors.warmInk,
        ),
      ),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.groupName.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: BlabColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                errorText: _error,
                counterText: '',
                filled: true,
                fillColor: BlabColors.chatSurface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BlabColors.chatDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BlabColors.chatDivider),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed:
                    _saving ||
                        _name.text.trim().isEmpty ||
                        _name.text.trim() == widget.chat.partnerName
                    ? null
                    : _save,
                child: Text(context.l10n.save),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupMedia extends ConsumerWidget {
  const _GroupMedia({required this.chatId, this.all = false});
  final String chatId;
  final bool all;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(groupPhotosProvider(chatId));
    final content = photos.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(groupPhotosProvider(chatId)),
        child: Text(context.l10n.retry),
      ),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.l10n.groupSharedMedia.toUpperCase()} · ${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.warmMuted,
                  ),
                ),
              ),
              if (!all && items.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: BlabColors.warmInk,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push<void>(
                    telegramRoute<void>(_GroupMedia(chatId: chatId, all: true)),
                  ),
                  child: Text(context.l10n.seeAll),
                ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                context.l10n.groupNoPhotos,
                style: const TextStyle(
                  color: BlabColors.warmMuted,
                  fontSize: 14,
                ),
              ),
            ),
          if (all)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final item in items)
                  PhotoMessageView(attachment: item, cornerRadius: 10),
              ],
            )
          else if (items.isNotEmpty)
            SizedBox(
              height: 78,
              child: Row(
                children: [
                  for (var i = 0; i < items.length && i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    SizedBox(
                      width: ((MediaQuery.sizeOf(context).width - 64) / 4)
                          .clamp(0, 78),
                      height: 78,
                      child: PhotoMessageView(
                        attachment: items[i],
                        cornerRadius: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!all) return content;
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        title: Text(
          context.l10n.groupSharedMedia,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.warmInk,
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [content]),
    );
  }
}
