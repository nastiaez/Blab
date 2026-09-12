import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/state/grammatical_form_preferences_state.dart';
import 'package:blab/features/chat/translation_preferences_screen.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/services/grammatical_form_preferences_service.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saving tone invalidates preferences and requests fresh translations',
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
      expect(container.read(grammaticalFormPreferenceRevisionProvider), 0);

      await container.read(saveConversationToneProvider)(
        'chat-1',
        ConversationTone.respectful,
      );
      await container.read(grammaticalFormPreferencesProvider('chat-1').future);

      expect(saved, [('chat-1', ConversationTone.respectful)]);
      expect(builds, 2);
      expect(container.read(grammaticalFormPreferenceRevisionProvider), 1);
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
}
