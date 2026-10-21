import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';

/// BLA-14 slice 1: native Material form for creating a group before sharing.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_submitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.invalidGroupName);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final service = ref.read(chatServiceProvider);
      final chatId = await service.createGroup(name);
      ref.invalidate(chatListProvider);
      if (!mounted) return;
      context.push('/group/$chatId/invite');
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.couldNotCreateGroup);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlabColors.chatCanvas,
    appBar: BlabAppBar(
      backgroundColor: BlabColors.chatSurface,
      title: Text(
        context.l10n.newGroup,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BlabColors.warmInk,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.groupName.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BlabColors.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('group-name-field'),
              controller: _name,
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: BlabColors.chatSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                errorText: _error,
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
                key: const ValueKey('create-group-button'),
                onPressed: _submitting ? null : _create,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.createGroup),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
