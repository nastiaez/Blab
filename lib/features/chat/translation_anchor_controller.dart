import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// Keeps a row's screen position through an explicit BLA-41 reveal/collapse.
/// The correction happens during viewport layout, before painting.
class TranslationAnchorController extends ScrollController {
  GlobalKey? _anchor;
  final Map<GlobalKey, double> _heights = {};
  double? _height;
  double? _pixels;

  void preserve(GlobalKey key) {
    if (!hasClients || !_heights.containsKey(key)) return;
    _anchor = key;
    _height = _heights[key];
    _pixels = position.pixels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchor = null;
      _height = null;
      _pixels = null;
    });
  }

  /// Preserve whitespace already visible above an underfilled conversation.
  double leadingWhitespace(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box == null || !hasClients) return 0;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderViewport) return 0;
    var extent = 0.0;
    viewport.visitChildren((child) {
      if (child is RenderSliver) extent += child.geometry?.scrollExtent ?? 0;
    });
    return (position.viewportDimension - extent).clamp(0.0, double.infinity);
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TranslationAnchorPosition(
    owner: this,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _TranslationAnchorPosition extends ScrollPositionWithSingleContext {
  _TranslationAnchorPosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.oldPosition,
  });
  final TranslationAnchorController owner;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final accepted = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    final height = owner._heights[owner._anchor];
    if (height != null && owner._height != null && owner._pixels != null) {
      final next = (owner._pixels! + height - owner._height!).clamp(
        minScrollExtent,
        maxScrollExtent,
      );
      if ((next - pixels).abs() > 0.1) {
        correctPixels(next);
        return false;
      }
    }
    return accepted;
  }
}

class TranslationAnchor extends SingleChildRenderObjectWidget {
  const TranslationAnchor({
    super.key,
    required this.anchorKey,
    required this.controller,
    required super.child,
  });
  final GlobalKey anchorKey;
  final TranslationAnchorController controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTranslationAnchor(controller, anchorKey);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    final anchor = renderObject as _RenderTranslationAnchor;
    anchor.controller = controller;
    anchor.anchorKey = anchorKey;
  }
}

class _RenderTranslationAnchor extends RenderProxyBox {
  _RenderTranslationAnchor(this.controller, this.anchorKey);
  TranslationAnchorController controller;
  GlobalKey anchorKey;
  @override
  void performLayout() {
    super.performLayout();
    controller._heights[anchorKey] = size.height;
  }

  @override
  void dispose() {
    controller._heights.remove(anchorKey);
    super.dispose();
  }
}
