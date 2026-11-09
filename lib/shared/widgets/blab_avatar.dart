import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/profile_state.dart';
import '../../app/theme.dart';

/// One avatar renderer with named geometry supplied by the owning surface.
class BlabAvatar extends StatelessWidget {
  const BlabAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.userId,
    this.size = 48,
    this.fontSize = 16,
    this.initials,
    this.fill,
    this.fontWeight = FontWeight.w800,
    this.shadows = const [
      BoxShadow(color: Color(0x2B231208), offset: Offset(0, 2), blurRadius: 6),
    ],
  });
  final Color? fill;
  final String? imageUrl;
  final String? userId;
  final String name;
  final String? initials;
  final double size, fontSize;
  final FontWeight fontWeight;
  final List<BoxShadow>? shadows;
  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill ?? BlabColors.avatarColorFor(name),
        boxShadow: shadows,
      ),
      alignment: Alignment.center,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  initials ?? BlabColors.avatarInitialsFor(name),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: fontWeight,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (url != null)
                _Photo(url: url)
              else if (userId != null)
                _PersonPhoto(userId: userId!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

class _PersonPhoto extends ConsumerWidget {
  const _PersonPhoto({required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(profileAvatarUrlProvider(userId)).value;
    return url == null ? const SizedBox.shrink() : _Photo(url: url);
  }
}
