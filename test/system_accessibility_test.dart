import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/forgot_password_sent_screen.dart';
import 'package:blab/features/auth/reset_password_screen.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:blab/shared/widgets/picker_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyChatList extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => const <Chat>[];
}

Future<void> _pumpChats(
  WidgetTester tester, {
  required Locale locale,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatListProvider.overrideWith(_EmptyChatList.new),
        onlineProvider.overrideWith((_) => Stream.value(true)),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: blabTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ChatsScreen(preview: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Widget home,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: blabTheme,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty Chats remains usable at 200% text in every locale', (
    tester,
  ) async {
    const expectations = {
      'en': ('Invite a friend', 'Chats'),
      'de': ('Freund einladen', 'Chats'),
      'es': ('Invitar a un amigo', 'Chats'),
      'uk': ('Запросити друга', 'Чати'),
    };

    for (final entry in expectations.entries) {
      await _pumpChats(tester, locale: Locale(entry.key), textScale: 2);

      final buttonRect = tester.getRect(find.byType(BrandButton));
      final labelRect = tester.getRect(find.text(entry.value.$1));
      expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
      expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
      expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
      expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
      expect(buttonRect.height, greaterThan(52));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('bottom navigation preserves icon-label spacing at 200%', (
    tester,
  ) async {
    await _pumpChats(tester, locale: const Locale('de'), textScale: 2);

    final chatIconRect = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is BlabIcon && widget.name == 'chat-bubble-empty - 20',
      ),
    );
    final chatLabelRect = tester.getRect(find.text('Chats'));
    expect(chatLabelRect.top - chatIconRect.bottom, greaterThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chats New Chat action meets Android touch-target minimum', (
    tester,
  ) async {
    await _pumpChats(tester, locale: const Locale('en'));

    final rect = tester.getRect(find.byType(FloatingActionButton));
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
  });

  testWidgets('transparent recovery AppBars request dark status content', (
    tester,
  ) async {
    for (final screen in <Widget>[
      const ResetPasswordScreen(),
      const ForgotPasswordSentScreen(email: 'bob@blab.test'),
    ]) {
      await _pumpLocalized(tester, home: screen);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(appBar.systemOverlayStyle?.statusBarBrightness, Brightness.light);
    }
  });

  testWidgets('offline live region exposes its localized label once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onlineProvider.overrideWith((_) => Stream.value(false))],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: OfflineBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('No connection')),
    );
    expect('No connection'.allMatches(node.label), hasLength(1));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
