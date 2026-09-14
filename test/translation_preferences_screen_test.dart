import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/state/grammatical_form_preferences_state.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/translation_preferences_screen.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/models/reading_script.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/grammatical_form_preferences_service.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/reading_script_state.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeChatService implements ChatService {
  _FakeChatService(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => rows;

  @override
  Future<List<String>> fetchPreparationMessageIds(
    String chatId, {
    int limit = 50,
  }) async => [];

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();

  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _chatRow(String id, String learningLanguage) => {
  'viewer_id': 'me',
  'chat_id': id,
  'partner_id': 'u2',
  'partner_name': 'Bob',
  'my_learning': learningLanguage,
  'partner_learning': 'en',
  'last_body': '',
  'last_at': '2026-09-14T09:00:00Z',
  'unread_count': 0,
  'my_mode': 'practice',
};

ProviderContainer _preferencesContainer({
  required List<Map<String, dynamic>> rows,
  ReadingScript initial = ReadingScript.native,
  Future<String> Function(String value)? update,
}) => ProviderContainer(
  overrides: [
    currentUserIdProvider.overrideWithValue('alice'),
    authSessionProvider.overrideWith((ref) => const Stream.empty()),
    chatServiceProvider.overrideWithValue(_FakeChatService(rows)),
    currentProfileProvider.overrideWith(
      (ref) async => const UserProfile(displayName: 'Alice'),
    ),
    fetchReadingScriptProvider.overrideWithValue(() async => initial.wire),
    updateReadingScriptProvider.overrideWithValue(
      update ?? (value) async => value,
    ),
  ],
);

Widget _preferencesHost(ProviderContainer container, {String? chatId}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: blabTheme,
        home: TranslationPreferencesScreen(
          chatId: chatId,
          partnerName: chatId == null ? null : 'Bob',
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saving tone invalidates preferences without refreshing completed translations',
    () async {
      var builds = 0;
      final saved = <(String, ConversationTone)>[];
      final container = ProviderContainer(
        overrides: [
          setConversationToneFnProvider.overrideWithValue((chatId, tone) async {
            saved.add((chatId, tone));
          }),
          grammaticalFormPreferencesProvider.overrideWith((ref, chatId) async {
            builds++;
            return const GrammaticalFormPreferences(
              ownForm: null,
              partnerForm: null,
              tone: ConversationTone.informal,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(grammaticalFormPreferencesProvider('chat-1').future);
      expect(builds, 1);

      await container.read(saveConversationToneProvider)(
        'chat-1',
        ConversationTone.respectful,
      );
      await container.read(grammaticalFormPreferencesProvider('chat-1').future);

      expect(saved, [('chat-1', ConversationTone.respectful)]);
      expect(builds, 2);
    },
  );

  testWidgets('renders the approved quiet preference hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const UserProfile(displayName: 'Alice'),
          ),
          grammaticalFormPreferencesProvider.overrideWith(
            (ref, chatId) async => const GrammaticalFormPreferences(
              ownForm: null,
              partnerForm: null,
              tone: ConversationTone.informal,
            ),
          ),
        ],
        child: MaterialApp(
          theme: blabTheme,
          home: const TranslationPreferencesScreen(
            chatId: 'chat-1',
            partnerName: 'Bob Local',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFFAF7F2),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFFFFCF8));
    expect(appBar.shape, isA<Border>());
    expect((appBar.shape! as Border).bottom.color, const Color(0xFFFFFCF8));

    final title = tester.widget<Text>(find.text('Translation preferences'));
    expect(title.style?.color, const Color(0xFF46281C));
    expect(title.style?.fontSize, 18);
    expect(title.style?.fontWeight, FontWeight.w400);

    final rowLabel = tester.widget<Text>(find.text('Your gender form'));
    expect(rowLabel.style?.color, const Color(0xFF46281C));
    expect(rowLabel.style?.fontSize, 15);
    expect(rowLabel.style?.fontWeight, FontWeight.w400);

    final value = tester.widgetList<Text>(find.text('Not set')).first;
    expect(value.style?.color, const Color(0xFF917869));
    expect(value.style?.fontSize, 14);
    expect(value.style?.fontWeight, FontWeight.w400);

    final cardDecorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    expect(
      cardDecorations.where(
        (decoration) =>
            decoration.color == const Color(0xFFFFFCF8) &&
            decoration.border?.top.color == const Color(0xFFE1DAD2),
      ),
      hasLength(1),
    );

    final icons = tester.widgetList<BlabIcon>(find.byType(BlabIcon)).toList();
    expect(
      icons.where((icon) => icon.name == 'nav-arrow-left - 20'),
      hasLength(1),
    );
    expect(
      icons.where((icon) => icon.name == 'nav-arrow-left - 20').single.color,
      const Color(0xFF46281C),
    );
    final backIcon = find.byWidgetPredicate(
      (widget) => widget is BlabIcon && widget.name == 'nav-arrow-left - 20',
    );
    expect(tester.getTopLeft(find.text('Translation preferences')).dx, 48);
    expect(
      tester.getTopLeft(find.text('Translation preferences')).dx -
          tester.getTopRight(backIcon).dx,
      10,
    );
    expect(
      icons.where((icon) => icon.name == 'nav-arrow-right - 20'),
      hasLength(3),
    );
    expect(
      icons
          .where((icon) => icon.name == 'nav-arrow-right - 20')
          .every((icon) => icon.color == const Color(0xFF917869)),
      isTrue,
    );
  });

  testWidgets('Hindi chat shows one Reading script row and saves selection', (
    tester,
  ) async {
    final saved = <String>[];
    final container = _preferencesContainer(
      rows: [_chatRow('chat-1', 'hi')],
      update: (value) async {
        saved.add(value);
        return value;
      },
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_preferencesHost(container, chatId: 'chat-1'));
    await tester.pumpAndSettle();

    expect(find.text('Reading script'), findsOneWidget);
    expect(find.text('Hindi script'), findsOneWidget);
    await tester.tap(find.text('Reading script'));
    await tester.pumpAndSettle();
    expect(find.text('Hindi script'), findsWidgets);
    expect(find.text('English letters'), findsOneWidget);

    await tester.tap(find.text('English letters'));
    await tester.pumpAndSettle();
    expect(saved, ['english_letters']);
    expect(find.text('English letters'), findsOneWidget);
  });

  testWidgets('Tamil chat uses Tamil copy and another language hides the row', (
    tester,
  ) async {
    final rows = [_chatRow('chat-1', 'ta')];
    final container = _preferencesContainer(rows: rows);
    addTearDown(container.dispose);

    await tester.pumpWidget(_preferencesHost(container, chatId: 'chat-1'));
    await tester.pumpAndSettle();
    expect(find.text('Reading script'), findsOneWidget);
    expect(find.text('Tamil script'), findsOneWidget);

    rows.single['my_learning'] = 'uk';
    await container.read(chatListProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('Reading script'), findsNothing);
  });

  testWidgets('Profile shows one shared row only for eligible conversations', (
    tester,
  ) async {
    final both = _preferencesContainer(
      rows: [_chatRow('hindi', 'hi'), _chatRow('tamil', 'ta')],
    );
    addTearDown(both.dispose);
    await tester.pumpWidget(_preferencesHost(both));
    await tester.pumpAndSettle();
    expect(find.text('Reading script'), findsOneWidget);
    expect(find.text('Native scripts'), findsOneWidget);

    final none = _preferencesContainer(rows: []);
    addTearDown(none.dispose);
    await tester.pumpWidget(_preferencesHost(none));
    await tester.pumpAndSettle();
    expect(find.text('Reading script'), findsNothing);
  });

  testWidgets('failed Reading script save keeps the prior choice', (
    tester,
  ) async {
    final container = _preferencesContainer(
      rows: [_chatRow('chat-1', 'hi')],
      update: (_) async => throw Exception('save failed'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_preferencesHost(container, chatId: 'chat-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reading script'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English letters'));
    await tester.pumpAndSettle();

    expect(find.text('Hindi script'), findsOneWidget);
    expect(find.text('Couldn’t save. Try again.'), findsOneWidget);
  });
}
