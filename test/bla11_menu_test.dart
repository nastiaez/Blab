import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/material_test_fonts.dart';

void main() {
  setUpAll(loadMaterialTestFonts);
  for (final locale in ['en', 'de', 'es', 'uk']) {
    for (final width in [320.0, 340.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('menu $locale $width $scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: blabTheme,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Align(
                    alignment: Alignment.topRight,
                    child: MenuAnchor(
                      menuChildren: buildChatMenuEntries(
                        context,
                        learningLanguage: kBlabLanguages.firstWhere(
                          (v) => v.code == 'pt',
                        ),
                        onLearningLanguageTap: () => selected++,
                        onTranslationPreferencesTap: () => selected += 10,
                      ),
                      builder: (context, controller, child) => IconButton(
                        key: const ValueKey('open'),
                        onPressed: controller.open,
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('open')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final row in find.byType(MenuItemButton).evaluate()) {
            final rect = tester.getRect(find.byWidget(row.widget));
            expect(rect.left, greaterThanOrEqualTo(8));
            expect(rect.right, lessThanOrEqualTo(width - 8));
            expect(rect.height, greaterThanOrEqualTo(48));
            for (final text
                in find
                    .descendant(
                      of: find.byWidget(row.widget),
                      matching: find.byType(Text),
                    )
                    .evaluate()) {
              final paragraph = text.findRenderObject()! as RenderParagraph;
              expect(paragraph.didExceedMaxLines, false);
              final painter = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textScaler: TextScaler.linear(scale),
              )..layout(maxWidth: paragraph.size.width);
              expect(
                painter.height,
                lessThanOrEqualTo(paragraph.size.height + .01),
              );
              expect(
                painter.width,
                lessThanOrEqualTo(paragraph.size.width + .01),
              );
              final textRect = tester.getRect(find.byWidget(text.widget));
              expect(textRect.left, greaterThanOrEqualTo(rect.left));
              expect(textRect.right, lessThanOrEqualTo(rect.right));
              painter.dispose();
            }
          }
          await tester.tap(find.byType(MenuItemButton).first);
          await tester.pumpAndSettle();
          expect(selected, 1);
          expect(find.byType(MenuItemButton), findsNothing);
        });
      }
    }
  }
}
