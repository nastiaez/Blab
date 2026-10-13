import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../blab_icon.dart';

/// The single Material navigation control for the app's top-level destinations.
class BlabNavigationBar extends StatelessWidget {
  const BlabNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  @override
  Widget build(BuildContext context) {
    // Supported Material styling, matching the original Chats geometry. The
    // SDK's own label scaling cap remains intact; no navigation is reimplemented.
    final labelHeight =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(11) *
        1.43;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A231208),
            offset: Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: BlabColors.chatDivider)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 8),
          child: NavigationBar(
            height: 40 + labelHeight,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _destination('chat-bubble-empty - 20', context.l10n.chats),
              _destination('profile-circle - 20', context.l10n.profile),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _destination(String name, String label) =>
      NavigationDestination(
        label: label,
        icon: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: BlabIcon(name: name, color: BlabColors.textMuted, size: 20),
        ),
        selectedIcon: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: BlabIcon(name: name, color: BlabColors.brand, size: 20),
        ),
      );
}
