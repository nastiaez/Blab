import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Shared warm outlined surface. It does not own its children's actions.
class BlabSectionCard extends StatelessWidget {
  const BlabSectionCard({super.key, required this.children}) : contentInset = 1;
  const BlabSectionCard.flush({super.key, required this.children})
    : contentInset = 0;
  final double contentInset;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: BlabComponentTheme.of(context).surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        BlabComponentTheme.of(context).cardRadius,
      ),
      side: BorderSide(color: BlabComponentTheme.of(context).outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: EdgeInsets.all(contentInset),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
