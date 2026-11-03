import 'package:flutter/widgets.dart';

/// Presentation-only tombstones; original bodies and identity ranges stay exact.
class DeletedIdentityScope extends InheritedWidget {
  const DeletedIdentityScope({
    super.key,
    required this.userIds,
    required super.child,
  });
  final Set<String> userIds;
  static Set<String> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DeletedIdentityScope>()
          ?.userIds ??
      const {};
  @override
  bool updateShouldNotify(DeletedIdentityScope oldWidget) =>
      userIds != oldWidget.userIds;
}
