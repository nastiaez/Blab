import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared base color for skeleton blocks. PRD US-032.
const Color _skeletonBase = Color(0xFFE0E0E0); // grey.shade300
const Color _skeletonHighlight = Color(0xFFF5F5F5); // grey.shade100

/// 3-row skeleton mirroring [ChatListTile]: gradient-shaped avatar circle
/// (gray), name bar, last-message bar. PRD US-032.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (context, i) => const Divider(
          height: 1,
          indent: 76,
          color: Color(0xFFF5F5F5),
        ),
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _SkeletonBlock(
                  width: 48,
                  height: 48,
                  shape: BoxShape.circle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkeletonBlock(
                        width: 120,
                        height: 14,
                        radius: 4,
                      ),
                      const SizedBox(height: 8),
                      _SkeletonBlock(
                        // Vary the second row width for visual interest.
                        width: i.isEven ? 220.0 : 180.0,
                        height: 12,
                        radius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton bubbles for the chat view's initial load. 3 incoming, 2 outgoing,
/// varying widths. PRD US-032.
class ChatViewSkeleton extends StatelessWidget {
  const ChatViewSkeleton({super.key});

  static const List<({bool isOutgoing, double width, double height})> _bubbles =
      [
    (isOutgoing: false, width: 220, height: 42),
    (isOutgoing: true, width: 160, height: 36),
    (isOutgoing: false, width: 260, height: 56),
    (isOutgoing: false, width: 180, height: 36),
    (isOutgoing: true, width: 200, height: 42),
  ];

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        itemCount: _bubbles.length,
        itemBuilder: (context, i) {
          final b = _bubbles[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Align(
              alignment:
                  b.isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
              child: _SkeletonBlock(
                width: b.width,
                height: b.height,
                radius: 18,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 0,
    this.shape = BoxShape.rectangle,
  });

  final double width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _skeletonBase,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
