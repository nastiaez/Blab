import '../../app/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Frozen Paper typography, scoped to Deep Dive rather than the shared app.
/// Bundled OFL Roboto removes Android/iOS platform-font metric differences.
class DeepDiveTypography extends StatelessWidget {
  const DeepDiveTypography({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'BlabDeepDiveRoboto',
        bodyColor: const Color(0xFF46281C),
        displayColor: const Color(0xFF46281C),
      ),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'BlabDeepDiveRoboto'),
      child: child,
    ),
  );
}

/// Inline placeholders need a strut for row gaps. Trim only that artificial
/// first/last half-gap so paragraph geometry matches CSS wrap rows.
class DeepDiveTrimInlineLeading extends SingleChildRenderObjectWidget {
  const DeepDiveTrimInlineLeading({
    super.key,
    required this.trim,
    required this.bottomPadding,
    required super.child,
  });
  final double trim, bottomPadding;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TrimmedInlineRows(trim, bottomPadding);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderShiftedBox renderObject,
  ) {
    (renderObject as _TrimmedInlineRows).update(trim, bottomPadding);
  }
}

class _TrimmedInlineRows extends RenderShiftedBox {
  _TrimmedInlineRows(this.trim, this.bottomPadding) : super(null);
  double trim, bottomPadding;
  void update(double nextTrim, double nextBottom) {
    if (trim == nextTrim && bottomPadding == nextBottom) return;
    trim = nextTrim;
    bottomPadding = nextBottom;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(
        child!.size.width,
        (child!.size.height - trim * 2 + bottomPadding)
            .clamp(0, double.infinity)
            .toDouble(),
      ),
    );
    (child!.parentData! as BoxParentData).offset = Offset(0, -trim);
  }
}

/// Explicit round word dots: font underline metrics otherwise become tiny noise.
/// Painting only preserves the child's width, alphabetic baseline and hit area.
class DeepDiveWordDots extends SingleChildRenderObjectWidget {
  const DeepDiveWordDots({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;
  static const double diameter = 1.3;
  static const double pitch = 4;
  static const double baselineOffset = 6;
  static const Color color = Color(0xFF9D948A);

  @override
  RenderObject createRenderObject(BuildContext context) => _WordDots(enabled);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _WordDots).enabled = enabled;
  }
}

class _WordDots extends RenderProxyBox {
  _WordDots(this._enabled);
  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_enabled || child == null) return;
    const radius = DeepDiveWordDots.diameter / 2;
    final y =
        (child!.getDistanceToBaseline(TextBaseline.alphabetic) ?? size.height) +
        DeepDiveWordDots.baselineOffset;
    final paint = Paint()..color = DeepDiveWordDots.color;
    for (
      double x = radius;
      x <= size.width - radius;
      x += DeepDiveWordDots.pitch
    ) {
      context.canvas.drawCircle(offset + Offset(x, y), radius, paint);
    }
  }
}

/// Paper FSR GKP: 3px all-corner brown selection, 4px dot-row paint extent.
/// Paint only: selected/unselected words keep identical width and baseline.
class DeepDiveSelectedWordBackground extends SingleChildRenderObjectWidget {
  const DeepDiveSelectedWordBackground({
    super.key,
    required this.selected,
    required super.child,
  });
  final bool selected;
  static const double radius = 3;
  static const double bottomExtent = 4;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SelectedWordBackground(selected);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _SelectedWordBackground).selected = selected;
  }
}

class _SelectedWordBackground extends RenderProxyBox {
  _SelectedWordBackground(this._selected);
  bool _selected;
  set selected(bool value) {
    if (value == _selected) return;
    _selected = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_selected && child != null) {
      final rect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        size.width,
        size.height + DeepDiveSelectedWordBackground.bottomExtent,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(DeepDiveSelectedWordBackground.radius),
        ),
        Paint()..color = BlabColors.warmInk,
      );
    }
    super.paint(context, offset);
  }
}
