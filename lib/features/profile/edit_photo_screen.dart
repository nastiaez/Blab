import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../app/theme.dart';
import '../../app/telegram_route.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'crop_profile_photo_screen.dart';

String photoText(BuildContext context, String key) => switch (key) {
  'editPhoto' => context.l10n.profilePhotoEditPhoto,
  'cropPhoto' => context.l10n.profilePhotoCropPhoto,
  'camera' => context.l10n.profilePhotoCamera,
  'photo' => context.l10n.profilePhotoPhoto,
  'removePhoto' => context.l10n.profilePhotoRemovePhoto,
  'confirmCrop' => context.l10n.profilePhotoConfirmCrop,
  'photoError' => context.l10n.profilePhotoPhotoError,
  _ => throw ArgumentError.value(key),
};

typedef ProfilePhotoPicker = Future<XFile?> Function(ImageSource source);
final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) =>
      (source) =>
          ImagePicker().pickImage(source: source, requestFullMetadata: false),
);

class EditPhotoScreen extends ConsumerStatefulWidget {
  const EditPhotoScreen({super.key});
  @override
  ConsumerState<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends ConsumerState<EditPhotoScreen> {
  Uint8List? _draft;
  bool _removed = false, _changed = false, _busy = false;
  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref.read(profilePhotoPickerProvider)(source);
      if (file == null) return;
      if (await file.length() > 20 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      final bytes = await file.readAsBytes();
      final normalized = await prepareProfilePhoto(bytes);
      if (!mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        telegramRoute<Uint8List>(CropProfilePhotoScreen(bytes: normalized)),
      );
      if (cropped != null && mounted) {
        setState(() {
          _draft = cropped;
          _removed = false;
          _changed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(photoText(context, 'photoError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_changed) return;
    setState(() => _busy = true);
    try {
      await ref.read(updateAvatarActionProvider)(_draft);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotUpdateProfile)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: BlabColors.appBackground,
        appBar: BlabAppBar(
          foregroundColor: Colors.black,
          centerTitle: true,
          title: Text(
            photoText(context, 'editPhoto'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const BlabIcon(
              name: 'nav-arrow-left - 20',
              color: Colors.black,
              size: 20,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                ),
                onPressed: _changed && !_busy ? _save : null,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.l10n.save,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _changed
                              ? const Color(0xfff88c5a)
                              : BlabColors.textMuted,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(currentProfileProvider),
              child: Text(context.l10n.retry),
            ),
          ),
          data: (p) {
            final hasPhoto =
                _draft != null ||
                (!_removed && (p.avatarUrl != null || p.avatarPath != null));
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: SizedBox.square(
                      dimension: 160,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (_draft != null)
                            ClipOval(
                              child: Image.memory(
                                _draft!,
                                width: 160,
                                height: 160,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            BlabAvatar(
                              name: p.displayName,
                              initials: p.displayName.trim().isEmpty
                                  ? '?'
                                  : p.displayName
                                        .trim()
                                        .characters
                                        .first
                                        .toUpperCase(),
                              fill: const Color(0xff917869),
                              imageUrl: _removed ? null : p.avatarUrl,
                              size: 160,
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                              shadows: null,
                            ),
                          if (hasPhoto)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: PhotoCircleButton(
                                label: photoText(context, 'removePhoto'),
                                icon: Icons.close,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _draft = null;
                                        _removed = true;
                                        _changed =
                                            p.avatarUrl != null ||
                                            p.avatarPath != null;
                                      }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PhotoSettingsCard(
                      children: [
                        PhotoSettingsRow(
                          icon: Icons.photo_camera_outlined,
                          label: photoText(context, 'camera'),
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.camera),
                        ),
                        PhotoSettingsRow(
                          icon: Icons.image_outlined,
                          label: photoText(context, 'photo'),
                          onPressed: _busy
                              ? null
                              : () => _pick(ImageSource.gallery),
                        ),
                      ],
                    ),
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

class PhotoCircleButton extends StatelessWidget {
  const PhotoCircleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Center(
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.square(48),
          maximumSize: const Size.square(48),
          padding: EdgeInsets.zero,
        ),
        icon: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xff46281c),
            shape: BoxShape.circle,
          ),
          child: FrozenPhotoIcon(icon: icon, color: Colors.white),
        ),
      ),
    ),
  );
}

class PhotoSettingsCard extends StatelessWidget {
  const PhotoSettingsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xfffffcf8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe1dad2)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++)
          DecoratedBox(
            decoration: BoxDecoration(
              border: i < children.length - 1
                  ? const Border(bottom: BorderSide(color: Color(0xffe1dad2)))
                  : null,
            ),
            child: children[i],
          ),
      ],
    ),
  );
}

class PhotoSettingsRow extends StatelessWidget {
  const PhotoSettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.chevron = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool chevron;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              FrozenPhotoIcon(icon: icon, color: BlabColors.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.43,
                    letterSpacing: .25,
                    color: Color(0xff46281c),
                  ),
                ),
              ),
              if (chevron)
                const BlabIcon(
                  name: 'nav-arrow-right - 20',
                  size: 20,
                  color: BlabColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Maps photo controls to the canonical asset family (no inline SVG).
class FrozenPhotoIcon extends StatelessWidget {
  const FrozenPhotoIcon({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final name = icon == Icons.edit_outlined
        ? 'edit-pencil'
        : icon == Icons.close
        ? 'close'
        : icon == Icons.check
        ? 'check'
        : icon == Icons.photo_camera_outlined
        ? 'camera'
        : icon == Icons.person_outline
        ? 'profile-circle'
        : 'media-image';
    return BlabIcon(name: '$name - 20', color: color, size: 20);
  }
}
