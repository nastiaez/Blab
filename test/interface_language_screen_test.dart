import 'package:blab/app/app_messenger.dart';
import 'package:blab/features/profile/interface_language_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpPicker(
  WidgetTester tester,
  String source, {
  bool saveFails = false,
}) async {
  SharedPreferences.setMockInitialValues({
    interfaceLanguageStorageKey('bob'): source,
  });
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue('bob'),
      fetchInterfaceLanguageProvider.overrideWithValue(() async => source),
      updateInterfaceLanguageProvider.overrideWithValue((code) async {
        if (saveFails) throw Exception('offline');
        return code;
      }),
    ],
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Text(context.l10n.profile, key: const Key('profile-title')),
        ),
      ),
      GoRoute(
        path: '/language',
        builder: (context, state) => const InterfaceLanguageScreen(),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) => MaterialApp.router(
          routerConfig: router,
          scaffoldMessengerKey: appMessengerKey,
          locale: Locale(ref.watch(interfaceLanguageProvider).code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/language');
  await tester.pumpAndSettle();
  return container;
}

Future<void> applyLanguage(
  WidgetTester tester,
  String source,
  String target,
) async {
  await tester.tap(find.text(interfaceLanguageForCode(target).nativeName));
  await tester.pumpAndSettle();
  final localizations = lookupAppLocalizations(Locale(source));
  await tester.tap(find.text(localizations.save));
  await tester.pumpAndSettle();
}

void main() {
  for (final source in ['en', 'de', 'es', 'uk']) {
    for (final target in ['en', 'de', 'es', 'uk']) {
      if (source == target) continue;
      testWidgets('$source → $target confirmation uses the saved locale', (
        tester,
      ) async {
        final container = await pumpPicker(tester, source);
        await applyLanguage(tester, source, target);

        final localized = lookupAppLocalizations(Locale(target));
        expect(container.read(interfaceLanguageProvider).code, target);
        expect(find.byType(InterfaceLanguageScreen), findsNothing);
        expect(find.text(localized.profile), findsOneWidget);
        expect(
          find.text(
            localized.switchedToLanguage(
              localizedInterfaceLanguageName(localized, target),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(localized.undo), findsOneWidget);
      });
    }
  }

  testWidgets('Undo restores the previous language after picker disposal', (
    tester,
  ) async {
    final container = await pumpPicker(tester, 'es');
    await applyLanguage(tester, 'es', 'uk');
    expect(find.byType(InterfaceLanguageScreen), findsNothing);
    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(interfaceLanguageProvider).code, 'es');
    expect(
      find.text(lookupAppLocalizations(const Locale('es')).profile),
      findsOneWidget,
    );
  });

  testWidgets('failed save keeps the original locale and shows its error', (
    tester,
  ) async {
    final container = await pumpPicker(tester, 'es', saveFails: true);
    await applyLanguage(tester, 'es', 'uk');
    expect(container.read(interfaceLanguageProvider).code, 'es');
    expect(find.byType(InterfaceLanguageScreen), findsOneWidget);
    expect(
      find.text(
        lookupAppLocalizations(const Locale('es')).couldNotSaveLanguage,
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBarAction), findsNothing);
  });
}
