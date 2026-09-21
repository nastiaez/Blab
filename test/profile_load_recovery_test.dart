import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecoveringProfileService extends ProfileService {
  _RecoveringProfileService()
    : super(
        SupabaseClient(
          'http://localhost',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int calls = 0;

  @override
  Future<UserProfile> fetchCurrentProfile() async {
    calls += 1;
    if (calls == 1) throw StateError('profile unavailable');
    return const UserProfile(displayName: 'Bob Local');
  }
}

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('${locale.languageCode} failed profile load is localized', (
      tester,
    ) async {
      final service = _RecoveringProfileService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith((_) => const Stream.empty()),
            profileServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            locale: locale,
            theme: blabTheme,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final localizations = lookupAppLocalizations(locale);
      expect(find.text(localizations.couldNotLoadProfile), findsOneWidget);
      expect(find.text(localizations.retry), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-load-retry')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('failed profile load settles into retry and can recover', (
    tester,
  ) async {
    final service = _RecoveringProfileService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith((_) => const Stream.empty()),
          profileServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const EditProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't load your profile."), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-load-retry')), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-load-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Bob Local'), findsOneWidget);
    expect(service.calls, 2);
  });
}
