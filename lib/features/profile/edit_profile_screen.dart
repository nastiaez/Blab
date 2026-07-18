import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/services/profile_service.dart';
import '../../shared/state/profile_state.dart';
import '../auth/widgets/blab_text_field.dart';

String? validateDisplayName(String input) {
  final value = input.trim();
  if (value.isEmpty) return 'Enter your display name';
  if (value.runes.length > 50) {
    return 'Display name must be 50 characters or fewer';
  }
  if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
    return 'Display name contains unsupported characters';
  }
  return null;
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  String? _initialName;
  String? _error;
  bool _busy = false;

  bool get _canSubmit =>
      !_busy && _initialName != null && _name.text.trim() != _initialName;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    final error = validateDisplayName(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final next = _name.text.trim();
    if (next == _initialName) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref.read(updateDisplayNameActionProvider)(next);
      if (!mounted) return;
      _initialName = saved;
      showAppSnack('Profile updated ✓');
      context.go('/profile');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not update your profile. Try again.';
      });
    }
  }

  void _initialize(UserProfile profile) {
    if (_initialName != null) return;
    _initialName = profile.displayName;
    _name.text = profile.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: BlabColors.appBackground,
        appBar: AppBar(
          backgroundColor: BlabColors.appBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: BlabColors.textPrimary,
            onPressed: _busy ? null : () => context.pop(),
          ),
          title: const Text(
            'Edit profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: BlabColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _canSubmit ? _save : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _canSubmit
                            ? BlabColors.brand
                            : BlabColors.textMuted,
                      ),
                    ),
            ),
          ],
        ),
        body: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ProfileLoadError(
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (value) {
            _initialize(value);
            final initial = _name.text.trim().isEmpty
                ? '?'
                : _name.text.trim().characters.first.toUpperCase();
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BlabColors.avatarColorFor(_name.text.trim()),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  BlabTextField(
                    controller: _name,
                    label: 'Display name',
                    hint: 'Your name',
                    errorText: _error,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _canSubmit ? _save : null,
                    onChanged: (_) {
                      setState(() => _error = null);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Couldn't load your profile.",
              style: TextStyle(color: BlabColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
