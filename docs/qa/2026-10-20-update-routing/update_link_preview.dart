// Controlled notice/version fixture; the production URL launcher is NOT mocked.
import 'package:blab/app/theme.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/app_update_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

var fixtureChannel = 'public';
late ProviderContainer fixture;
const links = {
  'public': 'https://appdistribution.firebase.google.com/testerapps/1:363935775546:android:c3a351249463d5f9356e03',
  'test': 'https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b',
};
class EmptyChats extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => [];
}
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fixture = ProviderContainer(overrides: [
    onlineProvider.overrideWith((_) => Stream.value(true)),
    chatListProvider.overrideWith(EmptyChats.new),
    appUpdateNoticeProvider.overrideWith((_) async => AppUpdateNotice.resolve({
      'channel': fixtureChannel, 'platform': 'android', 'enabled': true,
      'latest_build': 30, 'destination': links[fixtureChannel],
    }, installedBuild: 29, channel: fixtureChannel, platform: 'android')),
  ]);
  runApp(UncontrolledProviderScope(container: fixture, child: MaterialApp(
    theme: blabTheme,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const Preview(),
  )));
}
class Preview extends StatefulWidget {
  const Preview({super.key});
  @override
  State<Preview> createState() => _PreviewState();
}
class _PreviewState extends State<Preview> {
  void select(String value) {
    setState(() => fixtureChannel = value);
    fixture.invalidate(appUpdateNoticeProvider);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Expanded(child: ChatsScreen(preview: true)),
    Material(child: SafeArea(top: false, child: Column(children: [
      Text('QA fixture · version 29 → available 30 · $fixtureChannel',
          style: const TextStyle(fontSize: 12)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(onPressed: () => select('public'), child: const Text('Public app')),
        TextButton(onPressed: () => select('test'), child: const Text('Test app')),
      ]),
    ]))),
  ]);
}
