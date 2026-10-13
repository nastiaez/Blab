part of '../chat_screen.dart';

class ChatNotificationReminder extends StatelessWidget {
  const ChatNotificationReminder({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BlabColors.selectedTint,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 19,
                color: BlabColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.enableNotificationsReminder,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ),
              BlabIconButton(
                tooltip: context.l10n.dismiss,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 19),
                color: BlabColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatHeader extends ConsumerWidget {
  const ChatHeader({
    super.key,
    required this.chat,
    required this.onBeforeModeToggle,
    required this.onModeChanged,
    required this.practiceSetupRequired,
    required this.onBack,
    required this.onMenu,
    required this.menuController,
    required this.modeControlKey,
    required this.onMenuStateChanged,
    required this.onLearningLanguageTap,
    required this.onTranslationPreferencesTap,
    required this.onTapPartner,
    required this.selectionActive,
    required this.onDismissSelection,
  });

  final Chat chat;
  final VoidCallback onBeforeModeToggle;
  final ValueChanged<ChatMode> onModeChanged;
  final bool practiceSetupRequired;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final MenuController menuController;
  final GlobalKey modeControlKey;
  final VoidCallback onMenuStateChanged;
  final VoidCallback onLearningLanguageTap;
  final VoidCallback onTranslationPreferencesTap;
  final VoidCallback onTapPartner;
  final bool selectionActive;
  final VoidCallback onDismissSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerTyping =
        ref.watch(partnerTypingProvider(chat.id)).value ?? false;
    return ChatHeaderFrame(
      onBack: onBack,
      identity: ChatHeaderIdentity(
        name: chat.partnerName,
        typing: partnerTyping,
        onTap: onTapPartner,
      ),
      modeControl: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selectionActive ? onDismissSelection : null,
        child: AbsorbPointer(
          absorbing: selectionActive || practiceSetupRequired,
          child: ModeToggle(
            key: modeControlKey,
            enabled: !selectionActive && !practiceSetupRequired,
            chatId: chat.id,
            onBeforeToggle: onBeforeModeToggle,
            onModeChanged: onModeChanged,
          ),
        ),
      ),
      menuButton: MenuAnchor(
        controller: menuController,
        onOpen: onMenuStateChanged,
        onClose: onMenuStateChanged,
        alignmentOffset: const Offset(-8, 0),
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(BlabColors.chatSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: BlabColors.chatDivider),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        menuChildren: buildChatMenuEntries(
          context,
          learningLanguage: ref.watch(learningLanguageProvider(chat.id)),
          onLearningLanguageTap: onLearningLanguageTap,
          onTranslationPreferencesTap: onTranslationPreferencesTap,
        ),
        builder: (context, controller, child) => BlabIconButton(
          tooltip: context.l10n.chatMenu,
          icon: const BlabIcon(
            name: 'more-vert - 20',
            color: BlabColors.textPrimary,
            size: 20,
          ),
          onPressed: practiceSetupRequired ? null : onMenu,
          splashRadius: 22,
        ),
      ),
    );
  }
}

/// Pure native toolbar composition shared by actual chat and review fixtures.
class ChatHeaderFrame extends StatelessWidget {
  const ChatHeaderFrame({
    super.key,
    required this.identity,
    required this.modeControl,
    required this.menuButton,
    required this.onBack,
  });
  final Widget identity, modeControl, menuButton;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final stacked = chatHeaderIsStacked(context);
    final back = SizedBox(
      width: 44,
      height: 56,
      child: BlabIconButton(
        tooltip: context.l10n.back,
        padding: const EdgeInsets.only(left: 4),
        icon: const BlabIcon(
          name: 'nav-arrow-left - 20',
          color: BlabColors.textPrimary,
          size: 20,
        ),
        onPressed: onBack,
        splashRadius: 22,
      ),
    );
    final menu = SizedBox(width: 44, height: 56, child: menuButton);
    final title = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: chatHeaderIdentityHeightFor(context),
                child: Row(
                  children: [
                    back,
                    Expanded(
                      child: SizedBox(
                        height: chatHeaderIdentityHeightFor(context),
                        child: identity,
                      ),
                    ),
                    menu,
                  ],
                ),
              ),
              Align(alignment: Alignment.centerRight, child: modeControl),
            ],
          )
        : Row(
            children: [
              back,
              Expanded(
                child: SizedBox(
                  height: chatHeaderIdentityHeightFor(context),
                  child: identity,
                ),
              ),
              const SizedBox(width: 10),
              modeControl,
              menu,
            ],
          );
    return SizedBox(
      height:
          MediaQuery.paddingOf(context).top + chatHeaderHeightFor(context) + 1,
      child: BlabAppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 4,
        toolbarHeight: chatHeaderHeightFor(context),
        backgroundColor: BlabColors.chatSurface,
        shape: const Border(bottom: BorderSide(color: BlabColors.chatDivider)),
        title: title,
      ),
    );
  }
}

class ChatHeaderIdentity extends StatelessWidget {
  const ChatHeaderIdentity({
    super.key,
    required this.name,
    required this.onTap,
    this.typing = false,
  });
  final String name;
  final VoidCallback onTap;
  final bool typing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Row(
      children: [
        BlabAvatar(
          name: name,
          size: 36,
          fontSize: 12,
          shadows: const [
            BoxShadow(
              color: Color(0x21231208),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _capitaliseName(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  letterSpacing: 0.25,
                  fontWeight: FontWeight.w800,
                  color: BlabColors.sendButton,
                ),
              ),
              if (typing)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    context.l10n.typing,
                    key: const ValueKey(true),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.43,
                      letterSpacing: 0.25,
                      color: BlabColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ChatModeTipCard extends StatelessWidget {
  const ChatModeTipCard({
    super.key,
    required this.tip,
    required this.modeControlKey,
    required this.practiceLanguage,
    required this.primaryKnownLanguage,
    required this.onDismiss,
    required this.onEditKnownLanguages,
  });

  final ChatModeTip tip;
  final GlobalKey modeControlKey;
  final String practiceLanguage;
  final String primaryKnownLanguage;
  final VoidCallback onDismiss;
  final VoidCallback onEditKnownLanguages;

  @override
  Widget build(BuildContext context) {
    final practice = tip == ChatModeTip.practice;
    final modeBox = modeControlKey.currentContext?.findRenderObject();
    final modeCenterX = modeBox is RenderBox && modeBox.hasSize
        ? modeBox.localToGlobal(Offset(modeBox.size.width / 2, 0)).dx
        : null;

    final title = practice
        ? context.l10n.practiceModeTipTitle
        : context.l10n.normalModeTipTitle;
    final body = practice
        ? context.l10n.practiceModeTipBody(
            practiceLanguage,
            primaryKnownLanguage,
          )
        : context.l10n.normalModeTipBody;
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BlabColors.brand,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33231208),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF46281C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkResponse(
                      onTap: onDismiss,
                      radius: 20,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF46281C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF46281C),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                if (!practice) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onEditKnownLanguages,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF46281C),
                    ),
                    child: Text(
                      context.l10n.editKnownLanguages,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: modeCenterX == null
                ? (practice
                              ? kPracticeModeToggleWidth
                              : kNormalModeToggleWidth) /
                          2 +
                      26
                : MediaQuery.sizeOf(context).width - 16 - modeCenterX - 6,
            child: const IgnorePointer(
              child: CustomPaint(
                key: ValueKey('mode-tip-pointer'),
                size: Size(12, 6),
                painter: _ModeTipPointerPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTipPointerPainter extends CustomPainter {
  const _ModeTipPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pointer = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(pointer, Paint()..color = BlabColors.brand);
  }

  @override
  bool shouldRepaint(_ModeTipPointerPainter oldDelegate) => false;
}

// ─────────────────────────── menu ────────────────────────────────────────────
