import 'dart:async';

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
  bool failNextDelete = false;
  Completer<void>? pendingDelete;
  String? suppliedPassword;

  @override
  bool get hasPasswordIdentity => passwordIdentity;

  @override
  Future<void> deleteAccount({
    String? password,
    required Future<void> Function(String owner) clearLocalData,
  }) async {
    deleteCalls++;
    suppliedPassword = password;
    if (pendingDelete != null) await pendingDelete!.future;
    if (failNextDelete) {
      failNextDelete = false;
      throw Exception('injected interrupted deletion');
    }
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
    expect(find.text("This can't be undone."), findsNothing);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).content,
      isNull,
    );

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

  testWidgets(
    'interrupted deletion shows retryable error and requires confirmation again',
    (tester) async {
      final auth = await _pumpDeleteAccount(tester);
      auth.failNextDelete = true;
      Future<void> confirm() async {
        await tester.tap(find.text('Delete forever'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Delete forever'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await confirm();
      expect(auth.deleteCalls, 1);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(DeleteAccountScreen)),
          ).couldNotDeleteAccount,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();
      expect(auth.deleteCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete forever'),
        ),
      );
      // The fake does not emit sign-out/router navigation on success.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.deleteCalls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rapid and stale taps cannot stack confirmations or duplicate an in-flight deletion',
    (tester) async {
      final auth = await _pumpDeleteAccount(tester);
      final submit = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      submit();
      submit();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(auth.deleteCalls, 0);
      auth.pendingDelete = Completer<void>();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete forever'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.deleteCalls, 1);
      expect(auth.suppliedPassword, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      submit();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.deleteCalls, 1);
      auth.pendingDelete!.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'confirmation omits body and keeps actions in ${locale.languageCode}',
      (tester) async {
        final auth = await _pumpDeleteAccount(tester, locale: locale);
        final l10n = lookupAppLocalizations(locale);
        expect(find.text(l10n.deleteAccountPermanent), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, l10n.deleteForever));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(tester.widget<AlertDialog>(dialog).content, isNull);
        expect(find.text(l10n.deleteAccountConfirmationBody), findsNothing);
        expect(find.text(l10n.deleteAccountConfirmationTitle), findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, l10n.deleteForever),
          ),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(TextButton, l10n.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(auth.deleteCalls, 0);
        expect(find.text(l10n.deleteAccountPermanent), findsOneWidget);
      },
    );
  }

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
