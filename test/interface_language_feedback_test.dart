import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/interface_language_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:blab/shared/widgets/picker_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalizedTestApp extends ConsumerWidget {
  const _LocalizedTestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interfaceLanguage = ref.watch(interfaceLanguageProvider);
    return MaterialApp.router(
      theme: blabTheme,
      locale: Locale(interfaceLanguage.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      scaffoldMessengerKey: appMessengerKey,
      routerConfig: router,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scenarios = <({String initialCode, String targetCode})>[
    (initialCode: 'de', targetCode: 'en'),
    (initialCode: 'en', targetCode: 'de'),
    (initialCode: 'en', targetCode: 'es'),
    (initialCode: 'en', targetCode: 'uk'),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      'language change feedback uses the ${scenario.targetCode} target locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          kGuestInterfaceLanguageKey: scenario.initialCode,
        });
        final router = GoRouter(
          initialLocation: '/profile',
          observers: [appSnackRouteObserver],
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const Scaffold(body: Text('Profile')),
            ),
            GoRoute(
              path: '/profile/language',
              builder: (_, _) => const InterfaceLanguageScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [currentUserIdProvider.overrideWithValue(null)],
            child: _LocalizedTestApp(router: router),
          ),
        );
        await tester.pumpAndSettle();
        router.push('/profile/language');
        await tester.pumpAndSettle();

        final target = interfaceLanguageForCode(scenario.targetCode);
        await tester.tap(find.text(target.nativeName));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BrandButton));
        await tester.pumpAndSettle();

        final targetLocalizations = lookupAppLocalizations(
          Locale(scenario.targetCode),
        );
        final expectedMessage = targetLocalizations.switchedToLanguage(
          localizedInterfaceLanguageName(
            targetLocalizations,
            scenario.targetCode,
          ),
        );
        expect(find.text(expectedMessage), findsOneWidget);
        expect(find.text(targetLocalizations.undo), findsOneWidget);
      },
    );
  }
}
