import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real provider group results and original-only rejoin on Android', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const group = String.fromEnvironment('QA_GROUP_ID');
    const viewer = String.fromEnvironment('QA_VIEWER', defaultValue: 'alice');
    if (Uri.parse(url).host != '10.0.2.2' || group.isEmpty) {
      throw StateError('Local retained live-provider fixture required');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final client = Supabase.instance.client;
    await binding.convertFlutterSurfaceToImage();
    for (final scene in [
      (
        'alice',
        'uk',
        'en',
        'en',
        'Yesterday I went to the park.',
        '01-author-private-correction',
      ),
      (
        'carol',
        'uk',
        'es',
        'de',
        'Nos vemos mañana a las diez en la estación.',
        '02-member-spanish-result',
      ),
      (
        'bob',
        'en',
        'de',
        'es',
        'Yesterday I go to the park.',
        '03-rejoined-original-only',
      ),
    ]) {
      if (scene.$1 != viewer) continue;
      await client.auth.signInWithPassword(
        email: '${scene.$1}@blab.test',
        password: 'Blab-local-123!',
      );
      final uid = client.auth.currentUser!.id;
      final original = await client
          .from('profiles')
          .select('known_languages,primary_known_language')
          .eq('id', uid)
          .single();
      await client
          .from('profiles')
          .update({
            'known_languages': [scene.$2],
            'primary_known_language': scene.$2,
          })
          .eq('id', uid);
      try {
        final router = GoRouter(
          initialLocation: '/chat/$group',
          routes: [
            GoRoute(
              path: '/chat/:id',
              builder: (_, state) =>
                  ChatScreen(chatId: state.pathParameters['id']!),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(scene.$1),
            child: MaterialApp.router(
              theme: blabTheme,
              locale: Locale(scene.$4),
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        final expected = scene.$1 == 'alice'
            ? find.byWidgetPredicate(
                (w) => w is InlineCorrectionText && w.correctedText == scene.$5,
              )
            : find.byWidgetPredicate(
                (w) =>
                    (w is MessageText && w.text == scene.$5) ||
                    (w is Text && w.data == scene.$5),
              );
        for (var i = 0; i < 150 && expected.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        if (expected.evaluate().isEmpty) {
          await binding.takeScreenshot('diagnostic-${scene.$1}');
          debugPrint(
            'Rendered local fixture: ${tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText()).join(' | ')}',
          );
        }
        expect(
          expected,
          findsWidgets,
          reason: '${scene.$1}: real saved live output',
        );
        if (scene.$1 == 'bob') {
          final fresh = find.byWidgetPredicate(
            (w) =>
                w is MessageText &&
                w.text == 'Bitte bring morgen zwei Äpfel mit.',
          );
          for (var i = 0; i < 100 && fresh.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(
            fresh,
            findsWidgets,
            reason: 'New post-rejoin messages still translate',
          );
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is MessageText &&
                  w.text.startsWith('Wir treffen uns morgen'),
            ),
            findsNothing,
          );
          expect(
            find.byWidgetPredicate(
              (w) => w is MessageText && w.text.startsWith('Gestern bin ich'),
            ),
            findsNothing,
          );
        }
        await tester.pump(const Duration(seconds: 2));
        await binding.takeScreenshot(scene.$6);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        router.dispose();
      } finally {
        await client.from('profiles').update(original).eq('id', uid);
      }
    }
  });
}
