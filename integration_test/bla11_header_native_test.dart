// ignore_for_file: deprecated_member_use
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/chat_mode_toggle.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:blab/shared/widgets/actions/blab_icon_button.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved native header states and whole-pill action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // Dispose before testWidgets performs its end-of-test verification.
    for (final locale in ['uk', 'es']) {
      for (final scale in [1.0, 2.0]) {
        var practice = false;
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: blabTheme,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                backgroundColor: BlabColors.chatCanvas,
                body: Column(
                  children: [
                    ChatHeaderFrame(
                      onBack: () {},
                      identity: ChatHeaderIdentity(
                        name: 'Bob',
                        typing: true,
                        onTap: () {},
                      ),
                      modeControl: BlabChatModeToggle.segmented(
                        practice: practice,
                        onChanged: (value) => setState(() => practice = value),
                      ),
                      menuButton: Builder(
                        builder: (context) => MenuAnchor(
                          alignmentOffset: const Offset(-8, 0),
                          style: MenuStyle(
                            backgroundColor: const WidgetStatePropertyAll(
                              BlabColors.chatSurface,
                            ),
                            surfaceTintColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: BlabColors.chatDivider,
                                ),
                              ),
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.zero,
                            ),
                          ),
                          menuChildren: buildChatMenuEntries(
                            context,
                            learningLanguage: kBlabLanguages.firstWhere(
                              (v) => v.code == 'pt',
                            ),
                            onLearningLanguageTap: () => selected++,
                            onTranslationPreferencesTap: () => selected += 10,
                          ),
                          builder: (context, controller, child) =>
                              BlabIconButton(
                                key: const ValueKey('native-overflow'),
                                tooltip: context.l10n.chatMenu,
                                onPressed: () => controller.isOpen
                                    ? controller.close()
                                    : controller.open(),
                                icon: const BlabIcon(
                                  name: 'more-vert - 20',
                                  color: BlabColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          MediaQuery.textScalerOf(tester.element(find.text('BO'))).scale(12),
          12,
        );
        final toggle = find.byType(BlabChatModeToggle);
        final label = find.descendant(of: toggle, matching: find.byType(Text));
        expect(
          MediaQuery.textScalerOf(tester.element(label)).scale(14),
          14 * scale,
        );
        final bounds = tester.getRect(toggle);
        expect(bounds.height, greaterThanOrEqualTo(48 - 0.000001));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(
          bounds.right,
          lessThanOrEqualTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
          ),
        );
        final menu = find.byKey(const ValueKey('native-overflow'));
        expect(tester.getSize(menu).width, greaterThanOrEqualTo(48 - 0.000001));
        expect(
          tester.getSize(menu).height,
          greaterThanOrEqualTo(48 - 0.000001),
        );
        expect(
          tester.getSemantics(toggle).hasFlag(SemanticsFlag.isButton),
          true,
        );
        expect(
          tester.getSemantics(toggle).hasFlag(SemanticsFlag.hasToggledState),
          true,
        );
        expect(
          tester.getSemantics(toggle).hasFlag(SemanticsFlag.isToggled),
          false,
        );
        final menuLabel = AppLocalizations.of(tester.element(menu)).chatMenu;
        final menuSemantics = tester.getSemantics(menu);
        expect(menuSemantics.tooltip, menuLabel);
        expect(menuSemantics.hasFlag(SemanticsFlag.isButton), true);
        expect(menuSemantics.rect.width, greaterThanOrEqualTo(48 - 0.000001));
        expect(menuSemantics.rect.height, greaterThanOrEqualTo(48 - 0.000001));
        debugPrint(
          'BLA11_GEOMETRY $locale $scale toggle=$bounds menu=${tester.getRect(menu)}',
        );
        debugPrint('BLA11_CAPTURE $locale $scale normal');
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.tap(find.byType(BlabChatModeToggle));
        await tester.pumpAndSettle();
        expect(practice, true);
        debugPrint('BLA11_CAPTURE $locale $scale practice');
        await Future<void>.delayed(const Duration(seconds: 5));
        expect(
          tester.getSemantics(toggle).hasFlag(SemanticsFlag.isToggled),
          true,
        );
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        debugPrint('BLA11_CAPTURE $locale $scale overflow');
        await Future<void>.delayed(const Duration(seconds: 4));
        await tester.tap(find.byType(MenuItemButton).first);
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(find.byType(MenuItemButton), findsNothing);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MenuItemButton).last);
        await tester.pumpAndSettle();
        expect(selected, 11);
        expect(find.byType(MenuItemButton), findsNothing);
        debugPrint(
          'BLA11_ACTIONS $locale $scale both callbacks and dismissal passed',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    semantics.dispose();
  });
}
