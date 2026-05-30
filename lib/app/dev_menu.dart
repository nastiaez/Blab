import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/state/chat_state.dart';
import '../shared/state/connectivity_state.dart';
import 'theme.dart';

class DevMenu extends ConsumerWidget {
  const DevMenu({super.key});

  static const List<({String label, String path, String us})> _entries = [
    (label: 'Sign up / Log in', path: '/auth', us: 'US-001…US-005'),
    (label: 'Your chats', path: '/chats', us: 'US-006…US-012'),
    (label: 'Your chats — empty', path: '/chats?empty=1', us: 'US-007'),
    (label: 'Open a chat', path: '/chat', us: 'US-013…US-023'),
    (
      label: 'Invite landing — valid',
      path: '/invite?from=Nastia&learn=uk&teach=ta',
      us: 'US-024',
    ),
    (
      label: 'Invite landing — expired',
      path: '/invite?status=expired&from=Nastia',
      us: 'US-037',
    ),
    (
      label: 'Invite landing — used',
      path: '/invite?status=used&from=Nastia',
      us: 'US-037',
    ),
    (
      label: "Aswin's chats",
      path: '/chats?as=aswin',
      us: 'US-026',
    ),
    (label: 'Profile', path: '/profile', us: 'US-010…US-012, US-034, US-035'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forceOffline = ref.watch(forceOfflineProvider);
    final simulateFailure = ref.watch(simulateFailureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blab — dev menu'),
        backgroundColor: BlabColors.brand,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length + 2,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == _entries.length) {
            return _DevToggleRow(
              label: forceOffline
                  ? 'Toggle offline (on)'
                  : 'Toggle offline (off)',
              us: 'US-031',
              value: forceOffline,
              onTap: () =>
                  ref.read(forceOfflineProvider.notifier).toggle(),
            );
          }
          if (i == _entries.length + 1) {
            return _DevToggleRow(
              label: simulateFailure
                  ? 'Toggle failed-send (on)'
                  : 'Toggle failed-send (off)',
              us: 'US-030',
              value: simulateFailure,
              onTap: () =>
                  ref.read(simulateFailureProvider.notifier).toggle(),
            );
          }
          final e = _entries[i];
          return FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BlabColors.brand,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => context.push(e.path),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(e.us,
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DevToggleRow extends StatelessWidget {
  const _DevToggleRow({
    required this.label,
    required this.us,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String us;
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = value ? Colors.orange.shade700 : Colors.grey.shade700;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        us,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  activeThumbColor: Colors.white,
                  activeTrackColor: color,
                  onChanged: (_) => onTap(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
