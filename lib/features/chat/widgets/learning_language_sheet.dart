import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/data/languages.dart';

/// Bottom sheet for changing the *learning* language of a chat. PRD US-022.
///
/// Visual sibling of `auth/widgets/language_picker_sheet.dart` (the
/// interface-language picker). Two differences from that sheet:
///  - the heading is "Learning language" instead of "Interface language"
///  - a brand-purple "Done" button is pinned at the bottom
///
/// Returns the picked [BlabLanguage], or `null` if the sheet was dismissed
/// (Done / backdrop / drag).
Future<BlabLanguage?> showLearningLanguageSheet(
  BuildContext context, {
  required BlabLanguage current,
}) {
  return showModalBottomSheet<BlabLanguage>(
    context: context,
    backgroundColor: Colors.white,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag-handle pill.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Learning language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                  ),
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
                    leading: Text(
                      lang.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      lang.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: BlabColors.textPrimary,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check,
                            color: BlabColors.brand,
                            size: 24,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(lang),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
