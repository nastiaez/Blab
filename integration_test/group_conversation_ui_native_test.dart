import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved group conversation on retained real messages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const group = '9e148d3c-4240-486b-aac9-ccb73e3a7988';
    if (!['10.0.2.2', '127.0.0.1', 'localhost'].contains(Uri.parse(url).host)) {
      throw StateError('Local QA only');
    }
    await Supabase.initialize(url: url, anonKey: key);
    final client = Supabase.instance.client;
    await client.auth.signInWithPassword(
      email: 'bob@blab.test',
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
          'known_languages': ['en'],
          'primary_known_language': 'en',
        })
        .eq('id', uid);
    addTearDown(() async {
      await client.from('profiles').update(original).eq('id', uid);
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        child: MaterialApp.router(
          theme: blabTheme,
          locale: const Locale('es'),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 48, bottom: 30),
              viewPadding: const EdgeInsets.only(top: 48, bottom: 30),
            ),
            child: child!,
          ),
        ),
      ),
    );
    final fresh = find.byWidgetPredicate(
      (w) => w is MessageText && w.text == 'Bitte bring morgen zwei Äpfel mit.',
    );
    for (var i = 0; i < 160 && fresh.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(fresh, findsWidgets);
    expect(find.text('Alice Local'), findsNWidgets(2));
    expect(find.text('AL'), findsNWidgets(2));
    expect(find.text('Live group translation'), findsOneWidget);
    expect(find.text('Practicando alemán'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            (w is MessageText && w.text == 'Yesterday I go to the park.') ||
            (w is Text && w.data == 'Yesterday I go to the park.'),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('01-approved-group-conversation');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('composer-message-text-field')));
    await tester.enterText(
      find.byKey(const ValueKey('composer-message-text-field')),
      'Draft retained',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Draft retained'), findsOneWidget);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Draft retained'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
