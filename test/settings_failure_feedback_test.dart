import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/privacy_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:blab/shared/widgets/blab_switch.dart';
import 'package:blab/shared/widgets/inline_setting_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RetryableTypingIndicatorsNotifier extends TypingIndicatorsNotifier {
  final attempts = <bool>[];

  @override
  PrivacySettingState build() => const PrivacySettingState.ready(true);

  @override
  Future<void> set(bool value) async {
    attempts.add(value);
    if (attempts.length == 1) {
      throw StateError('storage unavailable');
    }
    state = PrivacySettingState.ready(value);
  }
}

class _BlockingRetryTypingIndicatorsNotifier extends TypingIndicatorsNotifier {
  final attempts = <bool>[];
  final retryCompleter = Completer<void>();

  @override
  PrivacySettingState build() => const PrivacySettingState.ready(true);

  @override
  Future<void> set(bool value) async {
    attempts.add(value);
    if (attempts.length == 1) {
      throw StateError('storage unavailable');
    }
    await retryCompleter.future;
    state = PrivacySettingState.ready(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'Privacy failure is inline and localized in ${locale.languageCode}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        late _RetryableTypingIndicatorsNotifier notifier;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              typingIndicatorsProvider.overrideWith(
                () => notifier = _RetryableTypingIndicatorsNotifier(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: blabTheme,
              home: const PrivacyScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final before = tester.widget<BlabSwitch>(find.byType(BlabSwitch).first);
        expect(before.value, isTrue);

        await tester.tap(find.byType(BlabSwitch).first);
        await tester.pumpAndSettle();

        final copy = lookupAppLocalizations(locale).couldNotSavePreference;
        expect(find.text(copy), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        final card = find.byKey(const Key('privacy-settings-card'));
        final error = find.text(copy);
        expect(card, findsOneWidget);
        expect(find.ancestor(of: error, matching: card), findsNothing);
        expect(
          tester.getTopLeft(error).dy,
          greaterThan(tester.getBottomLeft(card).dy),
        );
        expect(tester.getTopLeft(error).dx, tester.getTopLeft(card).dx);
        expect(
          tester.getTopLeft(find.byKey(const Key('privacy-links-card'))).dy -
              tester.getBottomLeft(error).dy,
          lessThanOrEqualTo(32),
        );
        expect(
          tester.getSize(find.byType(InlineSettingError)).height,
          greaterThanOrEqualTo(48),
        );

        final semantics = tester
            .widgetList<Semantics>(
              find.descendant(
                of: find.byType(InlineSettingError),
                matching: find.byType(Semantics),
              ),
            )
            .singleWhere((widget) => widget.properties.label == copy);
        expect(semantics.properties.button, isTrue);
        expect(semantics.properties.enabled, isTrue);
        expect(semantics.properties.label, copy);
        expect(semantics.properties.onTap, isNotNull);

        expect(
          tester.widget<BlabSwitch>(find.byType(BlabSwitch).first).value,
          isTrue,
        );

        await tester.tap(find.text(copy));
        await tester.pumpAndSettle();

        expect(notifier.attempts, [false, false]);
        expect(
          tester.widget<BlabSwitch>(find.byType(BlabSwitch).first).value,
          isFalse,
        );
        expect(find.text(copy), findsNothing);
      },
    );
  }

  testWidgets('Privacy retry cannot submit the failed value twice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late _BlockingRetryTypingIndicatorsNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          typingIndicatorsProvider.overrideWith(
            () => notifier = _BlockingRetryTypingIndicatorsNotifier(),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: blabTheme,
          home: const PrivacyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BlabSwitch).first);
    await tester.pumpAndSettle();

    final retry = find.text('Couldn’t save. Try again.');
    await tester.tap(retry);
    await tester.tap(retry);
    expect(notifier.attempts, [false, false]);

    notifier.retryCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t save. Try again.'), findsNothing);
  });
}
