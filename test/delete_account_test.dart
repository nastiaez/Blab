import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/delete_account_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DeleteAuthService extends SupabaseAuthService {
  _DeleteAuthService({this.passwordIdentity = true})
    : super(
        SupabaseClient(
          'http://localhost',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final bool passwordIdentity;
  int deleteCalls = 0;

  @override
  bool get hasPasswordIdentity => passwordIdentity;

  @override
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function() clearLocalData,
  }) async {
    deleteCalls++;
  }
}

Future<_DeleteAuthService> _pumpDeleteAccount(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool passwordIdentity = true,
}) async {
  final auth = _DeleteAuthService(passwordIdentity: passwordIdentity);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [supabaseAuthServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: blabTheme,
        home: const DeleteAccountScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  for (final passwordIdentity in [true, false]) {
    testWidgets('delete page has no credential field for '
        '${passwordIdentity ? 'password' : 'Google-only'} accounts', (
      tester,
    ) async {
      await _pumpDeleteAccount(tester, passwordIdentity: passwordIdentity);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Confirm with password'), findsNothing);
      expect(find.textContaining('Type '), findsNothing);
    });
  }

  testWidgets('Delete forever opens a final confirmation before deleting', (
    tester,
  ) async {
    final auth = await _pumpDeleteAccount(tester);

    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 0);
    expect(find.text('Delete your account permanently?'), findsOneWidget);
    expect(find.text("This can't be undone."), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.deleteCalls, 0);

    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete forever'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(auth.deleteCalls, 1);
  });

  test('Ukrainian delete-account copy uses informal address', () {
    final localizations = lookupAppLocalizations(const Locale('uk'));

    expect(localizations.yourProfile, 'Твій профіль');
    expect(localizations.yourSettings, 'Твої налаштування');
    expect(
      localizations.couldNotDeleteAccount,
      'Не вдалося видалити обліковий запис. Спробуй ще раз.',
    );
  });
}
