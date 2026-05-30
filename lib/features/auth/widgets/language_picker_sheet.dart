import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/data/languages.dart';

/// Apple-Settings-style bottom sheet language picker.
/// PRD US-005, FR-3: auto-saves on tap, no Done button needed.
Future<BlabLanguage?> showLanguagePickerSheet(
  BuildContext context, {
  required BlabLanguage current,
}) {
  return showModalBottomSheet<BlabLanguage>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Interface language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kBlabLanguages.length,
                itemBuilder: (ctx, i) {
                  final lang = kBlabLanguages[i];
                  final selected = lang.code == current.code;
                  return ListTile(
                    leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(lang.name, style: const TextStyle(fontSize: 16)),
                    trailing: selected
                        ? const Icon(Icons.check, color: BlabColors.brand)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(lang),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
