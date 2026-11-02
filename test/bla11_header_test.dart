import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/chat_mode_toggle.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/material_test_fonts.dart';

void main() {
  setUpAll(loadMaterialTestFonts);
  for (final locale in ['en', 'de', 'es', 'uk']) {
    for (final width in [320.0, 340.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final group in [false, true]) {
          testWidgets('$locale $width $scale group=$group', (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 800);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var changes = 0;
            for (final practice in [false, true]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: blabTheme,
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Column(
                      children: [
                        ChatHeaderFrame(
                          group: group,
                          onBack: () {},
                          identity: ChatHeaderIdentity(
                            name: 'Bob Alexandra Very Long Name',
                            group: group,
                            subtitle: group ? '100 members' : null,
                            typing: true,
                            onTap: () {},
                          ),
                          modeControl: BlabChatModeToggle.segmented(
                            practice: practice,
                            onChanged: (_) => changes++,
                          ),
                          menuButton: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.more_vert),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final capsule = find.byKey(const ValueKey('mode-toggle'));
              final rect = tester.getRect(capsule);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              final toggle = find.byType(BlabChatModeToggle);
              expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
              final label = tester
                  .widgetList<Text>(
                    find.descendant(of: toggle, matching: find.byType(Text)),
                  )
                  .single;
              expect(label.style!.fontSize, 14);
              final labelFinder = find.descendant(
                of: toggle,
                matching: find.byType(Text),
              );
              expect(
                MediaQuery.textScalerOf(tester.element(labelFinder)).scale(14),
                14 * scale,
              );
              expect(label.softWrap, false);
              expect(label.overflow, isNot(TextOverflow.ellipsis));
              await tester.tap(toggle);
              await tester.pump();
            }
            expect(changes, 2);
          });
        }
      }
    }
  }
}
