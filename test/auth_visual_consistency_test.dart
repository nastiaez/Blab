import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/auth/widgets/blab_text_field.dart';
import 'package:blab/features/auth/widgets/sso_buttons.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localized(Widget child) => MaterialApp(
  theme: blabTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('auth fields use the shared warm surface and control radius', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _localized(
        Padding(
          padding: const EdgeInsets.all(20),
          child: BlabTextField(
            controller: controller,
            label: 'Email',
            hint: 'you@example.com',
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    final border = decoration.enabledBorder! as OutlineInputBorder;

    expect(decoration.fillColor, BlabColors.chatSurface);
    expect(border.borderRadius, BorderRadius.circular(14));
    expect(border.borderSide.color, BlabColors.chatDivider);
  });

  testWidgets('auth fields expose a clear disabled state while submitting', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _localized(
        BlabTextField(controller: controller, label: 'Email', enabled: false),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(field.decoration!.fillColor, BlabColors.selectedTint);
  });

  testWidgets('SSO control becomes visually and functionally disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(SsoButtons(enabled: false, onPressed: (_) {})),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);

    final style = button.style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.disabled}),
      BlabColors.selectedTint,
    );
  });

  testWidgets('authentication failures use compact inline error text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailAuthActionProvider.overrideWithValue(
            (_) async => throw Exception('Invalid login credentials'),
          ),
        ],
        child: _localized(const AuthScreen(initialMode: AuthMode.logIn)),
      ),
    );
    await tester.pumpAndSettle();

    final forgotPasswordFinder = find.text('Forgot password?');
    final helperLeft = tester.getTopLeft(forgotPasswordFinder).dx;

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'alice@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    final errorText = tester.widget<Text>(
      find.byKey(const ValueKey('auth-form-error')),
    );
    expect(forgotPasswordFinder, findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth-form-error'))).dx,
      closeTo(helperLeft, 0.1),
    );
    expect(errorText.style!.color, BlabColors.error);
    expect(errorText.style!.fontWeight, FontWeight.w400);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('auth navigation links use regular-weight brand text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: AuthScreen(initialMode: AuthMode.logIn)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('Forgot password?')).style!.fontWeight,
      FontWeight.w400,
    );
    expect(
      tester.widget<Text>(find.text('New to Blab? Sign up')).style!.fontWeight,
      FontWeight.w400,
    );
  });

  testWidgets('authentication submission disables the complete form', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailAuthActionProvider.overrideWithValue((_) => pending.future),
        ],
        child: _localized(const AuthScreen(initialMode: AuthMode.logIn)),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'alice@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.text('Log in'));
    await tester.pump();

    for (final field in tester.widgetList<TextField>(fields)) {
      expect(field.enabled, isFalse);
    }
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();
  });
}
