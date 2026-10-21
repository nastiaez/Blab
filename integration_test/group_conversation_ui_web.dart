// QA-only entry: real retained local messages, no injected translation response.
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  if (Uri.parse(url).host != '127.0.0.1') {
    throw StateError('Local QA only');
  }
  await Supabase.initialize(
    url: url,
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  final client = Supabase.instance.client;
  await client.auth.signInWithPassword(
    email: 'bob@blab.test',
    password: 'Blab-local-123!',
  );
  await client
      .from('profiles')
      .update({
        'known_languages': ['en'],
        'primary_known_language': 'en',
      })
      .eq('id', client.auth.currentUser!.id);
  final router = GoRouter(
    initialLocation: '/chat/9e148d3c-4240-486b-aac9-ccb73e3a7988',
    routes: [
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatScreen(chatId: state.pathParameters['id']!),
      ),
    ],
  );
  runApp(
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
}
