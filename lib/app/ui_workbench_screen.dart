import '../shared/widgets/navigation/blab_navigation_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/chat_screen.dart';
import '../features/chat/widgets/chat_mode_toggle.dart';
import '../features/chat/widgets/message_text.dart';
import '../features/chat/widgets/message_bubble_surface.dart';
import '../features/chats/widgets/chat_list_tile.dart';
import '../features/profile/widgets/profile_identity.dart';
import '../shared/widgets/settings/blab_settings_row.dart';
import '../shared/widgets/surfaces/blab_section_card.dart';
import '../shared/data/languages.dart';
import '../shared/models/chat.dart';
import '../shared/models/message.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import '../shared/widgets/blab_icon.dart';

/// Debug-only visual audit board for the current Blab direction.
///
/// This screen uses production components with isolated review fixtures instead of hosted state.
/// It is an additive reference surface: changing a status here never changes
/// a production widget or persisted preference.
class UiWorkbenchScreen extends StatefulWidget {
  const UiWorkbenchScreen({super.key});

  @override
  State<UiWorkbenchScreen> createState() => _UiWorkbenchScreenState();
}

enum _WorkbenchSection { previews, inventory, comparison }

enum _PreviewScreen { chats, profile, chat }

enum _ReviewStatus { keep, merge, replace, review }

class _UiWorkbenchScreenState extends State<UiWorkbenchScreen> {
  _WorkbenchSection _section = _WorkbenchSection.previews;
  _PreviewScreen _preview = _PreviewScreen.chat;
  bool _practice = true;
  final Map<String, _ReviewStatus> _statuses = {
    for (final item in _inventory) item.id: item.initialStatus,
    for (final item in _comparisons) item.id: item.initialStatus,
  };

  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: _buildWorkbench(context));

  Widget _buildWorkbench(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: AppBar(
        backgroundColor: BlabColors.chatSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blab UI workbench',
              style: TextStyle(
                color: BlabColors.bubbleInk,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Debug-only · current design audit',
              style: TextStyle(color: BlabColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _WorkbenchTabs(
            selected: _section,
            onSelected: (value) => setState(() => _section = value),
          ),
          Expanded(child: _buildSection()),
        ],
      ),
    );
  }

  Widget _buildSection() {
    return switch (_section) {
      _WorkbenchSection.previews => _PreviewBoard(
        selected: _preview,
        practice: _practice,
        onSelected: (value) => setState(() => _preview = value),
        onPracticeChanged: (value) => setState(() => _practice = value),
      ),
      _WorkbenchSection.inventory => _InventoryBoard(
        statuses: _statuses,
        onStatusChanged: (id, value) => setState(() => _statuses[id] = value),
      ),
      _WorkbenchSection.comparison => _ComparisonBoard(
        statuses: _statuses,
        onStatusChanged: (id, value) => setState(() => _statuses[id] = value),
      ),
    };
  }
}

class _WorkbenchTabs extends StatelessWidget {
  const _WorkbenchTabs({required this.selected, required this.onSelected});

  final _WorkbenchSection selected;
  final ValueChanged<_WorkbenchSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlabColors.chatSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _WorkbenchTab(
            label: 'Previews',
            selected: selected == _WorkbenchSection.previews,
            onTap: () => onSelected(_WorkbenchSection.previews),
          ),
          _WorkbenchTab(
            label: 'Inventory',
            selected: selected == _WorkbenchSection.inventory,
            onTap: () => onSelected(_WorkbenchSection.inventory),
          ),
          _WorkbenchTab(
            label: 'Compare',
            selected: selected == _WorkbenchSection.comparison,
            onTap: () => onSelected(_WorkbenchSection.comparison),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchTab extends StatelessWidget {
  const _WorkbenchTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? BlabColors.bubbleOutgoingPractice
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? BlabColors.bubbleInk : BlabColors.textMuted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBoard extends StatelessWidget {
  const _PreviewBoard({
    required this.selected,
    required this.practice,
    required this.onSelected,
    required this.onPracticeChanged,
  });

  final _PreviewScreen selected;
  final bool practice;
  final ValueChanged<_PreviewScreen> onSelected;
  final ValueChanged<bool> onPracticeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _IntroCard(
          eyebrow: 'REVIEW BOARD',
          title: 'Current Blab direction',
          body: 'Chat, learning history, settings. Review-only.',
        ),
        const SizedBox(height: 16),
        _PreviewSelector(selected: selected, onSelected: onSelected),
        const SizedBox(height: 12),
        if (selected == _PreviewScreen.chat)
          _ChatPreview(practice: practice, onPracticeChanged: onPracticeChanged)
        else if (selected == _PreviewScreen.chats)
          const _ChatsPreview()
        else
          const _ProfilePreview(),
        const SizedBox(height: 18),
        const _SectionHeading(
          eyebrow: 'INCLUDED STATES',
          title: 'Content · loading · recovery',
          body: 'Small states are in scope.',
        ),
        const SizedBox(height: 10),
        const _StatePreviewStrip(),
      ],
    );
  }
}

class _PreviewSelector extends StatelessWidget {
  const _PreviewSelector({required this.selected, required this.onSelected});

  final _PreviewScreen selected;
  final ValueChanged<_PreviewScreen> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SelectorChip(
          label: 'Chats',
          selected: selected == _PreviewScreen.chats,
          onTap: () => onSelected(_PreviewScreen.chats),
        ),
        const SizedBox(width: 8),
        _SelectorChip(
          label: 'Profile',
          selected: selected == _PreviewScreen.profile,
          onTap: () => onSelected(_PreviewScreen.profile),
        ),
        const SizedBox(width: 8),
        _SelectorChip(
          label: 'Chat',
          selected: selected == _PreviewScreen.chat,
          onTap: () => onSelected(_PreviewScreen.chat),
        ),
      ],
    );
  }
}

class _SelectorChip extends StatelessWidget {
  const _SelectorChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? BlabColors.bubbleInk
              : BlabColors.textMuted,
          backgroundColor: selected ? const Color(0xFFF3E3D9) : null,
          side: BorderSide(
            color: selected
                ? BlabColors.bubbleOutgoingPractice
                : BlabColors.chatDivider,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ChatsPreview extends StatelessWidget {
  const _ChatsPreview();

  @override
  Widget build(BuildContext context) {
    return _PhonePreview(
      label: 'Flow 2 · Chats + profile entry',
      child: Column(
        children: [
          const _PreviewHeader(title: 'Chats', trailing: '＋'),
          const _ChatTileFixture(
            initials: 'AS',
            name: 'Aswin',
            message: 'I can help you with Tamil.',
            time: '10:42',
            unread: 2,
          ),
          const _ChatTileFixture(
            initials: 'BO',
            name: 'Bob Local',
            message: 'New connection · Say hi',
            time: 'New',
            invite: true,
          ),
          const Divider(height: 1, color: BlabColors.chatDivider),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MiniIconCircle(
                  icon: 'chat-bubble-empty - 20',
                  color: BlabColors.bubbleOutgoingPractice,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'List item variants: unread, new invite, and regular conversation.',
                    style: TextStyle(
                      color: BlabColors.textMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BlabNavigationBar(selectedIndex: 0, onDestinationSelected: (_) {}),
        ],
      ),
    );
  }
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview();

  @override
  Widget build(BuildContext context) {
    return _PhonePreview(
      label: 'Flow 2 · Profile + settings',
      child: Column(
        children: [
          const _PreviewHeader(title: 'Profile'),
          const SizedBox(height: 14),
          const ProfileIdentity(name: 'Bob Local'),
          const SizedBox(height: 14),
          _SettingsPreviewCard(
            title: 'Account',
            rows: const [
              ('language - 20', 'Interface language', 'English'),
              ('wrench - 20', 'Translation preferences', '›'),
              ('edit-pencil - 20', 'Edit profile', '›'),
              ('at-sign - 20', 'Change email', '›'),
              ('lock - 20', 'Change password', '›'),
            ],
          ),
          const SizedBox(height: 10),
          _SettingsPreviewCard(
            title: 'Safety',
            rows: const [
              ('historic-shield - 20', 'Privacy', '›'),
              ('bell - 20', 'Notifications', '›'),
            ],
          ),
          const SizedBox(height: 10),
          _SettingsPreviewCard(
            title: 'Account actions',
            rows: const [('log-out - 20', 'Log out', '›')],
            destructiveRows: const {'Delete account'},
          ),
          BlabNavigationBar(selectedIndex: 1, onDestinationSelected: (_) {}),
        ],
      ),
    );
  }
}

class _ChatPreview extends StatelessWidget {
  const _ChatPreview({required this.practice, required this.onPracticeChanged});

  final bool practice;
  final ValueChanged<bool> onPracticeChanged;

  @override
  Widget build(BuildContext context) {
    return _PhonePreview(
      label: 'Flow 3 · person-to-person chat',
      child: Column(
        children: [
          _HeaderFixture(
            practice: practice,
            onPracticeChanged: onPracticeChanged,
          ),
          Container(
            color: BlabColors.chatCanvas,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
            child: Column(
              children: [
                ChatDateDivider(
                  when: DateTime.now().subtract(const Duration(days: 1)),
                ),
                const ChatLanguageMarker(
                  languageCode: 'es',
                  topPadding: 10,
                  bottomPadding: 10,
                ),
                const _MessageFixture(
                  text: '¿Vienes hoy en autobús?',
                  outgoing: false,
                ),
                const SizedBox(height: 10),
                _MessageFixture(
                  text: practice
                      ? 'Sí, voy en autobús.'
                      : 'Yes, I’m going by bus.',
                  outgoing: true,
                  practice: practice,
                ),
                const SizedBox(height: 10),
                ChatDateDivider(when: DateTime.now()),
                const _MessageFixture(
                  text: '¡Perfecto, hasta luego!',
                  outgoing: false,
                ),
                const SizedBox(height: 10),
                _MessageFixture(
                  text: practice ? 'Hasta luego 👋' : 'See you later 👋',
                  outgoing: true,
                  practice: practice,
                ),
                const SizedBox(height: 16),
                const _ChatMenuFixture(),
              ],
            ),
          ),
          _ComposerFixture(practice: practice),
        ],
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BlabColors.bubbleInk,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: BlabColors.chatSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: BlabColors.chatDivider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14231208),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(bottom: BorderSide(color: BlabColors.chatDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: BlabColors.bubbleInk,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: BlabColors.bubbleInk,
                fontSize: 24,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTileFixture extends StatelessWidget {
  const _ChatTileFixture({
    required this.initials,
    required this.name,
    required this.message,
    required this.time,
    this.unread = 0,
    this.invite = false,
  });
  final String initials, name, message, time;
  final int unread;
  final bool invite;
  @override
  Widget build(BuildContext context) => ChatListTile(
    chat: Chat(
      id: 'workbench-$name',
      partnerName: name,
      partnerInitial: initials,
      learningLanguage: kBlabLanguages.firstWhere((l) => l.code == 'es'),
      mode: ChatMode.practice,
      partnerNativeLanguage: kBlabLanguages.firstWhere((l) => l.code == 'en'),
      partnerLearningLanguage: kBlabLanguages.firstWhere((l) => l.code == 'es'),
      lastMessage: message,
      lastMessageTranslation: message,
      timestamp: DateTime.now(),
      unreadCount: unread,
      lastMessageId: invite ? null : 'fixture',
      isNewInvite: true,
    ),
    onTap: () {},
  );
}

class _SettingsPreviewCard extends StatelessWidget {
  const _SettingsPreviewCard({
    required this.title,
    required this.rows,
    this.destructiveRows = const <String>{},
  });
  final String title;
  final List<(String, String, String)> rows;
  final Set<String> destructiveRows;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: BlabColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 5),
        BlabSectionCard(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              BlabSettingsRow(
                iconName: rows[i].$1,
                label: rows[i].$2,
                trailingLabel: rows[i].$3.isEmpty ? null : rows[i].$3,
                destructive: destructiveRows.contains(rows[i].$2),
                onTap: () {},
              ),
              if (i < rows.length - 1)
                const Divider(
                  height: 1,
                  indent: 48,
                  color: BlabColors.chatDivider,
                ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _HeaderFixture extends StatelessWidget {
  const _HeaderFixture({
    required this.practice,
    required this.onPracticeChanged,
  });
  final bool practice;
  final ValueChanged<bool> onPracticeChanged;
  @override
  Widget build(BuildContext context) => ChatHeaderFrame(
    onBack: () {},
    identity: ChatHeaderIdentity(name: 'Bob Local', onTap: () {}),
    modeControl: BlabChatModeToggle.segmented(
      practice: practice,
      onChanged: onPracticeChanged,
    ),
    menuButton: MenuAnchor(
      menuChildren: buildChatMenuEntries(
        context,
        learningLanguage: kBlabLanguages.firstWhere((l) => l.code == 'es'),
        onLearningLanguageTap: () {},
        onTranslationPreferencesTap: () {},
      ),
      builder: (context, controller, child) => IconButton(
        icon: const BlabIcon(
          name: 'more-vert - 20',
          size: 20,
          color: BlabColors.textPrimary,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    ),
  );
}

class _MessageFixture extends StatelessWidget {
  const _MessageFixture({
    required this.text,
    required this.outgoing,
    this.practice = false,
  });
  final String text;
  final bool outgoing, practice;
  @override
  Widget build(BuildContext context) => Align(
    alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: MessageBubbleSurface(
        outgoing: outgoing,
        practice: practice,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MessageText(
              text: text,
              tokens: const [],
              languageCode: 'es',
              style: TextStyle(
                color: outgoing ? BlabColors.bubbleInk : BlabColors.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: MessageMeta(
                chatId: 'workbench',
                message: Message(
                  id: 'fixture',
                  chatId: 'workbench',
                  isOutgoing: outgoing,
                  originalText: text,
                  translation: '',
                  sentAt: DateTime(2026, 10, 13, 10, 42),
                  status: MessageStatus.read,
                ),
                isOutgoing: outgoing,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChatMenuFixture extends StatelessWidget {
  const _ChatMenuFixture();
  @override
  Widget build(BuildContext context) => BlabSectionCard(
    children: [
      const Padding(padding: EdgeInsets.all(12), child: Text('··· Chat menu')),
      ...buildChatMenuEntries(
        context,
        learningLanguage: kBlabLanguages.firstWhere((l) => l.code == 'es'),
        onLearningLanguageTap: () {},
        onTranslationPreferencesTap: () {},
      ),
    ],
  );
}

class _ComposerFixture extends StatefulWidget {
  const _ComposerFixture({required this.practice});
  final bool practice;
  @override
  State<_ComposerFixture> createState() => _ComposerFixtureState();
}

class _ComposerFixtureState extends State<_ComposerFixture> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatComposer(
    controller: _controller,
    focusNode: _focus,
    hasText: _controller.text.isNotEmpty,
    hintText: widget.practice ? 'Type in Spanish or English' : 'Message',
    textLength: _controller.text.length,
    maxLength: 1000,
    counterShowAt: 900,
    isPractice: widget.practice,
    enabled: true,
    showTopBorder: true,
    onAttach: () {},
    onSend: () {},
  );
}

class _StatePreviewStrip extends StatelessWidget {
  const _StatePreviewStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _StatePreview(
          title: 'Empty',
          source: 'ChatsScreen · no chats',
          iconName: 'chat-bubble-empty - 20',
          body: 'No chats yet · Invite someone',
        ),
        SizedBox(height: 8),
        _StatePreview(
          title: 'Loading',
          source: 'ChatListSkeleton · 3 rows',
          iconName: 'refresh - 16',
          body: 'Gradient avatar, name, and message bars',
          loading: true,
        ),
        SizedBox(height: 8),
        _StatePreview(
          title: 'Error / retry',
          source: 'ChatsErrorState · inline recovery',
          iconName: 'refresh - 16',
          body: 'Couldn’t load chats · Retry',
          error: true,
        ),
      ],
    );
  }
}

class _StatePreview extends StatelessWidget {
  const _StatePreview({
    required this.title,
    required this.source,
    required this.iconName,
    required this.body,
    this.loading = false,
    this.error = false,
  });

  final String title;
  final String source;
  final String iconName;
  final String body;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final accent = error
        ? BlabColors.error
        : loading
        ? BlabColors.textMuted
        : BlabColors.bubbleOutgoingPractice;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? const Color(0xFFE4C5BD) : BlabColors.chatDivider,
        ),
      ),
      child: Row(
        children: [
          _MiniIconCircle(icon: iconName, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: const TextStyle(
                    color: BlabColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: BlabColors.bubbleInk,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryBoard extends StatelessWidget {
  const _InventoryBoard({
    required this.statuses,
    required this.onStatusChanged,
  });

  final Map<String, _ReviewStatus> statuses;
  final void Function(String, _ReviewStatus) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _IntroCard(
          eyebrow: 'COMPONENT INVENTORY',
          title: 'What exists today',
          body: 'Context · tokens · variants · review status.',
        ),
        const SizedBox(height: 16),
        const _TokenSwatches(),
        const SizedBox(height: 16),
        for (final item in _inventory) ...[
          _InventoryCard(
            item: item,
            status: statuses[item.id] ?? item.initialStatus,
            onStatusChanged: (value) => onStatusChanged(item.id, value),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.status,
    required this.onStatusChanged,
  });

  final _InventoryItem item;
  final _ReviewStatus status;
  final ValueChanged<_ReviewStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BlabColors.chatDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: BlabColors.bubbleInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPicker(value: status, onChanged: onStatusChanged),
            ],
          ),
          const SizedBox(height: 7),
          _MetaLine(label: 'Source', value: item.source),
          _MetaLine(label: 'Context', value: item.context),
          const SizedBox(height: 8),
          Text(
            item.parameters,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final variant in item.variants) _VariantChip(label: variant),
            ],
          ),
          if (item.swatches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Swatches',
                  style: TextStyle(color: BlabColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 8),
                for (final color in item.swatches) _Swatch(color: color),
              ],
            ),
          ],
          if (item.note != null) ...[
            const SizedBox(height: 9),
            Text(
              item.note!,
              style: const TextStyle(
                color: BlabColors.textMuted,
                fontSize: 11,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                color: BlabColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: BlabColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0EB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: BlabColors.bubbleInk, fontSize: 11),
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({required this.value, required this.onChanged});

  final _ReviewStatus value;
  final ValueChanged<_ReviewStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(value);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .40)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ReviewStatus>(
          value: value,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 17, color: color),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          items: [
            for (final option in _ReviewStatus.values)
              DropdownMenuItem(
                value: option,
                child: Text(_statusLabel(option)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TokenSwatches extends StatelessWidget {
  const _TokenSwatches();

  @override
  Widget build(BuildContext context) {
    const tokens = [
      ('Practice', BlabColors.bubbleOutgoingPractice, '#F88C5A'),
      ('Practice outline', BlabColors.bubbleOutgoingPracticeOutline, '#F07D4B'),
      ('Normal bubble', BlabColors.bubbleOutgoingNormal, '#D7C8BE'),
      ('Incoming surface', BlabColors.bubbleIncomingSurface, '#FFFCF8'),
      ('Chat canvas', BlabColors.chatCanvas, '#FAF7F2'),
      ('Divider', BlabColors.chatDivider, '#E1DAD2'),
      ('Send / ink', BlabColors.sendButton, '#46281C'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BlabColors.chatDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VALUES + SWATCHES',
            style: TextStyle(
              color: BlabColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 8),
          for (final token in tokens) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  _Swatch(color: token.$2, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      token.$1,
                      style: const TextStyle(
                        color: BlabColors.bubbleInk,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    token.$3,
                    style: const TextStyle(
                      color: BlabColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Text(
            'Accent rule: use the shared brand token for Practice surfaces, active controls, and selected states.',
            style: TextStyle(
              color: BlabColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBoard extends StatelessWidget {
  const _ComparisonBoard({
    required this.statuses,
    required this.onStatusChanged,
  });

  final Map<String, _ReviewStatus> statuses;
  final void Function(String, _ReviewStatus) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _IntroCard(
          eyebrow: 'SAME BEHAVIOR · DIFFERENT APPEARANCE',
          title: 'Consolidation decisions',
          body:
              'These pairs do similar jobs but currently look different. Keep the distinction, merge the treatment, replace one, or review later—without changing production automatically.',
        ),
        const SizedBox(height: 16),
        for (final item in _comparisons) ...[
          _ComparisonCard(
            item: item,
            status: statuses[item.id] ?? item.initialStatus,
            onStatusChanged: (value) => onStatusChanged(item.id, value),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.item,
    required this.status,
    required this.onStatusChanged,
  });

  final _ComparisonItem item;
  final _ReviewStatus status;
  final ValueChanged<_ReviewStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BlabColors.chatDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: BlabColors.bubbleInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPicker(value: status, onChanged: onStatusChanged),
            ],
          ),
          const SizedBox(height: 8),
          _ComparisonSide(
            title: item.leftTitle,
            source: item.leftSource,
            body: item.leftBody,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                '↔',
                style: TextStyle(color: BlabColors.textMuted, fontSize: 18),
              ),
            ),
          ),
          _ComparisonSide(
            title: item.rightTitle,
            source: item.rightSource,
            body: item.rightBody,
          ),
          if (item.note != null) ...[
            const SizedBox(height: 10),
            Text(
              item.note!,
              style: const TextStyle(
                color: BlabColors.textMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonSide extends StatelessWidget {
  const _ComparisonSide({
    required this.title,
    required this.source,
    required this.body,
  });

  final String title;
  final String source;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            source,
            style: const TextStyle(color: BlabColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BlabColors.bubbleOutgoingPractice,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A231208),
            offset: Offset(0, 2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: BlabColors.bubbleInk,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: BlabColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: BlabColors.bubbleInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(
            color: BlabColors.textMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _MiniIconCircle extends StatelessWidget {
  const _MiniIconCircle({required this.icon, required this.color});

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        shape: BoxShape.circle,
      ),
      child: BlabIcon(name: icon, color: color, size: 18),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x40332219)),
      ),
    );
  }
}

String _statusLabel(_ReviewStatus status) => switch (status) {
  _ReviewStatus.keep => 'Keep',
  _ReviewStatus.merge => 'Merge',
  _ReviewStatus.replace => 'Replace',
  _ReviewStatus.review => 'Review',
};

Color _statusColor(_ReviewStatus status) => switch (status) {
  _ReviewStatus.keep => const Color(0xFF35765D),
  _ReviewStatus.merge => const Color(0xFF9A6619),
  _ReviewStatus.replace => BlabColors.error,
  _ReviewStatus.review => const Color(0xFF5E6D8A),
};

class _InventoryItem {
  const _InventoryItem({
    required this.id,
    required this.title,
    required this.source,
    required this.context,
    required this.parameters,
    required this.variants,
    required this.initialStatus,
    this.swatches = const [],
    this.note,
  });

  final String id;
  final String title;
  final String source;
  final String context;
  final String parameters;
  final List<String> variants;
  final _ReviewStatus initialStatus;
  final List<Color> swatches;
  final String? note;
}

const _inventory = <_InventoryItem>[
  _InventoryItem(
    id: 'chat-list-tile',
    title: 'Chat list tile',
    source: 'lib/features/chats/widgets/chat_list_tile.dart',
    context: 'Flow 2 · Chats',
    parameters:
        '48 px avatar · name · preview · timestamp · unread count · invite state',
    variants: ['regular', 'unread', 'typing', 'new connection'],
    initialStatus: _ReviewStatus.keep,
    swatches: [BlabColors.sendButton, BlabColors.bubbleOutgoingPractice],
  ),
  _InventoryItem(
    id: 'empty-state',
    title: 'Empty state',
    source: 'lib/features/chats/chats_screen.dart · ChatsEmptyState',
    context: 'Flow 2 · no chats',
    parameters:
        'Centered prompt · chat icon · “No chats yet” · Invite someone CTA',
    variants: ['first use', 'no chats after deletion'],
    initialStatus: _ReviewStatus.review,
    swatches: [BlabColors.chatCanvas, BlabColors.bubbleOutgoingPractice],
  ),
  _InventoryItem(
    id: 'loading-state',
    title: 'Loading state',
    source:
        'lib/shared/widgets/skeletons.dart · ChatListSkeleton / ChatViewSkeleton',
    context: 'Cold launch · chats and chat view',
    parameters:
        '3 chat rows · avatar/name/message bars · ordered message bubbles',
    variants: ['list skeleton', 'chat skeleton', 'translating group row'],
    initialStatus: _ReviewStatus.keep,
    swatches: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
  ),
  _InventoryItem(
    id: 'error-state',
    title: 'Error and retry states',
    source:
        'lib/features/chats/chats_screen.dart · ChatsErrorState; chat failure rows',
    context: 'Recovery · no full-screen blocker',
    parameters:
        'Inline retry · text-only language-aid failure · red delivery failure copy',
    variants: [
      'chat-list retry',
      'message not sent',
      'couldn’t translate · retry',
    ],
    initialStatus: _ReviewStatus.replace,
    swatches: [BlabColors.error, BlabColors.chatSurface],
    note: 'Same recovery job; different owner.',
  ),
  _InventoryItem(
    id: 'date-separator',
    title: 'Date separator',
    source: 'lib/features/chat/chat_screen.dart · message timeline',
    context: 'Chat canvas · Today / Yesterday / weekday',
    parameters:
        'Plain text directly on #FAF7F2 · no pill fill · no background container',
    variants: ['Today', 'Yesterday', 'weekday name'],
    initialStatus: _ReviewStatus.review,
    swatches: [BlabColors.chatCanvas, BlabColors.textMuted],
  ),
  _InventoryItem(
    id: 'learning-history',
    title: 'Learning-history boundary',
    source: 'lib/features/chat/language_timeline.dart + chat_screen.dart',
    context: 'Chat history · private per participant',
    parameters:
        '“Now learning [language]” boundary · historical results retain assigned language',
    variants: [
      'Now learning Spanish',
      'Now learning English',
      'pending retarget',
    ],
    initialStatus: _ReviewStatus.merge,
    swatches: [Color(0xFF917869), BlabColors.chatCanvas],
  ),
  _InventoryItem(
    id: 'profile-settings-row',
    title: 'Profile/settings rows',
    source:
        'lib/shared/widgets/settings/blab_settings_row.dart · BlabSettingsRow',
    context: 'Flow 2 · Profile',
    parameters:
        '20 px icon · label · optional value or chevron · dividers · destructive treatment',
    variants: ['navigation row', 'value row', 'log out', 'delete account'],
    initialStatus: _ReviewStatus.merge,
    swatches: [
      BlabColors.chatSurface,
      BlabColors.chatDivider,
      BlabColors.error,
    ],
  ),
  _InventoryItem(
    id: 'chat-menu',
    title: 'Three-dots chat menu',
    source: 'lib/features/chat/chat_screen.dart · menu sheet',
    context: 'Flow 3 / 4 · chat header',
    parameters:
        'Show translations/corrections toggle · Learning language row · Translation preferences entry',
    variants: [
      'translations on',
      'translations off',
      'learning language',
      'preferences',
    ],
    initialStatus: _ReviewStatus.review,
    swatches: [BlabColors.chatSurface, BlabColors.bubbleOutgoingPractice],
  ),
  _InventoryItem(
    id: 'translation-preferences',
    title: 'Translation preferences rows',
    source: 'lib/features/chat/translation_preferences_screen.dart',
    context: 'Chat menu / Profile settings',
    parameters:
        'Direct rows · self form · partner form · conversation tone · value + chevron',
    variants: [
      'chat-scoped',
      'profile-scoped',
      'not set',
      'feminine / masculine',
    ],
    initialStatus: _ReviewStatus.review,
    swatches: [BlabColors.chatSurface, BlabColors.chatDivider],
  ),
  _InventoryItem(
    id: 'mode-toggle',
    title: 'Normal / Practice mode switch',
    source: 'lib/features/chat/widgets/mode_toggle.dart',
    context: 'Chat header · private per person/per chat',
    parameters:
        '129 × 34 Normal · 135 × 34 Practice · icon-only inactive segment · 44 px tap target',
    variants: ['Normal active', 'Practice active', '200% text scaling'],
    initialStatus: _ReviewStatus.keep,
    swatches: [
      Color(0xFFCDC0B6),
      BlabColors.bubbleOutgoingPractice,
      BlabColors.chatDivider,
    ],
  ),
  _InventoryItem(
    id: 'message-bubbles',
    title: 'Message bubbles',
    source: 'lib/features/chat/chat_screen.dart + message_presentation.dart',
    context: 'Person-to-person chat',
    parameters:
        '18 px main corners · 4 px directional corner · grouped spacing · receipt metadata',
    variants: ['incoming', 'outgoing Normal', 'outgoing Practice', 'corrected'],
    initialStatus: _ReviewStatus.keep,
    swatches: [
      BlabColors.bubbleIncomingSurface,
      BlabColors.bubbleOutgoingNormal,
      BlabColors.bubbleOutgoingPractice,
    ],
  ),
  _InventoryItem(
    id: 'composer',
    title: 'Composer and send control',
    source: 'lib/features/chat/widgets/chat_composer_input.dart',
    context: 'Chat footer · Normal / Practice',
    parameters:
        '44 px send button · auto-growing input · empty circle dims, arrow stays white',
    variants: [
      'Normal placeholder',
      'Practice guidance',
      'empty',
      'filled',
      'reply / edit bar',
    ],
    initialStatus: _ReviewStatus.keep,
    swatches: [
      BlabColors.chatSurface,
      BlabColors.sendButton,
      BlabColors.chatDivider,
    ],
  ),
];

class _ComparisonItem {
  const _ComparisonItem({
    required this.id,
    required this.title,
    required this.leftTitle,
    required this.leftSource,
    required this.leftBody,
    required this.rightTitle,
    required this.rightSource,
    required this.rightBody,
    required this.initialStatus,
    this.note,
  });

  final String id;
  final String title;
  final String leftTitle;
  final String leftSource;
  final String leftBody;
  final String rightTitle;
  final String rightSource;
  final String rightBody;
  final _ReviewStatus initialStatus;
  final String? note;
}

const _comparisons = <_ComparisonItem>[
  _ComparisonItem(
    id: 'compare-recovery',
    title: 'Recovery intent',
    leftTitle: 'Chat-list error',
    leftSource: 'ChatsErrorState',
    leftBody: 'Centered message with a Retry text button.',
    rightTitle: 'Message failure',
    rightSource: 'Chat bubble metadata',
    rightBody:
        'Red text below the bubble with a refresh action; no standalone icon.',
    initialStatus: _ReviewStatus.review,
    note:
        'Both recover from a failed request, but one is page-level and one is message-owned.',
  ),
  _ComparisonItem(
    id: 'compare-timeline',
    title: 'Timeline anchors',
    leftTitle: 'Today / Yesterday',
    leftSource: 'Chat message timeline',
    leftBody: 'Date context shown as plain muted text on the canvas.',
    rightTitle: 'Now learning Spanish',
    rightSource: 'Private language timeline',
    rightBody:
        'Language-change boundary shown as warm muted text between messages.',
    initialStatus: _ReviewStatus.merge,
    note: 'Same timeline role; different context.',
  ),
  _ComparisonItem(
    id: 'compare-navigation',
    title: 'Navigate or choose a setting',
    leftTitle: 'Profile settings row',
    leftSource: 'ProfileScreen · card row',
    leftBody: 'Icon + label + value/chevron inside a grouped settings card.',
    rightTitle: 'Chat menu row',
    rightSource: 'ChatScreen · three-dots menu',
    rightBody: 'Icon + label + switch or chevron inside a contextual menu.',
    initialStatus: _ReviewStatus.keep,
    note: 'Same affordance; persistent vs contextual.',
  ),
  _ComparisonItem(
    id: 'compare-selection',
    title: 'Binary mode selection',
    leftTitle: 'Normal / Practice switch',
    leftSource: 'ModeToggle',
    leftBody:
        'Custom capsule with an icon-only inactive state and a labeled active state.',
    rightTitle: 'Settings Switch',
    rightSource: 'Profile / Privacy controls',
    rightBody: 'System-style thumb-and-track toggle for an on/off preference.',
    initialStatus: _ReviewStatus.keep,
    note: 'Named modes vs boolean preference.',
  ),
  _ComparisonItem(
    id: 'compare-primary-action',
    title: 'Primary commit action',
    leftTitle: 'Brand CTA',
    leftSource: 'BlabButton · auth/invite/profile',
    leftBody: 'Full-width labeled action using the broader brand token.',
    rightTitle: 'Send button',
    rightSource: 'ChatComposerInput',
    rightBody:
        '44 px circular arrow using #46281C, with a Practice-only shadow.',
    initialStatus: _ReviewStatus.review,
    note: 'Same commit job; compact chat control.',
  ),
];
