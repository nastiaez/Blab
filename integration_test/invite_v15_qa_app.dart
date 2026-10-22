import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/shared/state/chat_list_state.dart';
// Task-owned QA entry. Real widgets and isolated local backend; never hosted.
import 'package:blab/app/theme.dart';
import 'package:blab/app/telegram_route.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/groups/create_group_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/features/invite/new_chat_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late GoRouter qaRouter;
late String qaGroupId;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  if (!['127.0.0.1', '10.0.2.2'].contains(Uri.parse(url).host) ||
      !url.endsWith(':59521')) {
    throw StateError('Isolated invitation QA backend only');
  }
  await Supabase.initialize(
    url: url,
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  final client = Supabase.instance.client;
  await client.auth.signInWithPassword(
    email: 'alice@blab.test',
    password: 'Blab-local-123!',
  );
  qaGroupId = await ChatService(client).createGroup('German learners');
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  qaRouter = GoRouter(
    initialLocation: '/chats',
    routes: [
      GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
      GoRoute(
        path: '/chats/new',
        pageBuilder: (_, s) =>
            TelegramPage(key: s.pageKey, child: const NewChatScreen()),
      ),
      GoRoute(
        path: '/groups/new',
        pageBuilder: (_, s) =>
            TelegramPage(key: s.pageKey, child: const CreateGroupScreen()),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (_, s) => TelegramPage(
          key: s.pageKey,
          child: ChatScreen(chatId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/group/:id/invite',
        pageBuilder: (_, s) => TelegramPage(
          key: s.pageKey,
          child: GroupInviteScreen(
            chatId: s.pathParameters['id']!,
            initialToken: null,
            groupName: 'German learners',
          ),
        ),
      ),
      GoRoute(
        path: '/qa/group-details',
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => ref
              .watch(chatListProvider)
              .when(
                data: (chats) => GroupInfoScreen(
                  chat: chats.firstWhere((c) => c.id == qaGroupId),
                ),
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Scaffold(body: Text('$e')),
              ),
        ),
      ),
      GoRoute(
        path: '/qa/group-link',
        pageBuilder: (_, s) => TelegramPage(
          key: s.pageKey,
          child: GroupInviteLinkScreen(
            chatId: qaGroupId,
            initialToken: null,
            groupName: 'German learners',
          ),
        ),
      ),
    ],
  );
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        theme: blabTheme,
        routerConfig: qaRouter,
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 48, bottom: 0),
            viewPadding: const EdgeInsets.only(top: 48, bottom: 0),
          ),
          child: child!,
        ),
      ),
    ),
  );
}
