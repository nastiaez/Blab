import '../../shared/widgets/blab_icon.dart';
export 'edit_display_name_screen.dart' show validateDisplayName;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../app/telegram_route.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'edit_display_name_screen.dart';
import 'edit_photo_screen.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: BlabColors.appBackground,
    appBar: BlabAppBar(
      foregroundColor: Colors.black,
      centerTitle: true,
      title: Text(
        context.l10n.editProfile,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const BlabIcon(
          name: 'nav-arrow-left - 20',
          color: Colors.black,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: ref
        .watch(currentProfileProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.couldNotLoadProfile,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlabColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  key: const ValueKey('profile-load-retry'),
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
          data: (profile) => SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BlabAvatar(
                          name: profile.displayName,
                          initials: profile.displayName.trim().isEmpty
                              ? '?'
                              : profile.displayName
                                    .trim()
                                    .characters
                                    .first
                                    .toUpperCase(),
                          fill: const Color(0xff917869),
                          imageUrl: profile.avatarUrl,
                          size: 112,
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          shadows: null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: PhotoCircleButton(
                            label: photoText(context, 'editPhoto'),
                            icon: Icons.edit_outlined,
                            onPressed: () => Navigator.of(context).push(
                              telegramRoute<void>(const EditPhotoScreen()),
                            ),
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
                        icon: Icons.person_outline,
                        label: profile.displayName,
                        chevron: false,
                        onPressed: () => Navigator.of(context).push(
                          telegramRoute<void>(const EditDisplayNameScreen()),
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
