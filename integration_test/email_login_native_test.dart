import 'package:blab/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'existing staging account authenticates through native email UI',
    (tester) async {
      const email = String.fromEnvironment('BLAB_QA_EMAIL');
      const password = String.fromEnvironment('BLAB_QA_PASSWORD');
      expect(const String.fromEnvironment('BLAB_ENV'), 'staging');
      expect(email.isNotEmpty && password.isNotEmpty, isTrue);
      await app.main();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.byType(Navigator).evaluate().isNotEmpty) break;
      }
      await Supabase.instance.client.auth.signOut();
      await tester.pump(const Duration(seconds: 2));
      final context = tester.element(find.byType(Navigator).first);
      GoRouter.of(context).go('/auth/login/email');
      for (
        var i = 0;
        i < 100 && find.byType(TextField).evaluate().length < 2;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.enterText(find.byType(TextField).at(0), email);
      await tester.enterText(find.byType(TextField).at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Log in').last);
      for (
        var i = 0;
        i < 150 && Supabase.instance.client.auth.currentSession == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(Supabase.instance.client.auth.currentUser?.email, email);
      for (var i = 0; i < 150 && find.text('Chats').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await binding.takeScreenshot('05-email-authenticated');
      expect(find.text('Chats'), findsWidgets);
      expect(find.byKey(const Key('email-auth-form-error')), findsNothing);
      await Supabase.instance.client.auth.signOut();
    },
  );
}
