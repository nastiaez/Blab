import 'dart:async';

import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/partner_profile_page.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BlabLanguage _language(String code) =>
    kBlabLanguages.firstWhere((language) => language.code == code);

Chat _chat() => Chat(
  id: 'chat-1',
  partnerId: 'alice-id',
  partnerName: 'Alice',
  partnerInitial: 'A',
  learningLanguage: _language('de'),
  mode: ChatMode.practice,
  partnerNativeLanguage: _language('en'),
  partnerLearningLanguage: _language('uk'),
  lastMessage: 'Hello',
  lastMessageTranslation: 'Hallo',
  timestamp: DateTime(2026, 9, 1),
  startedAt: DateTime(2026, 8, 1),
  unreadCount: 0,
);

class _FakeChatService implements ChatService {
  final reportCalls =
      <({String reason, String? userId, String? chatId, String? messageId})>[];
  final blockCalls = <String>[];
  final unblockCalls = <String>[];
  final blocked = <String>{};
  final changes = StreamController<Set<String>>.broadcast();
  Object? reportError;
  Object? blockError;

  @override
  Stream<Set<String>> watchBlockedIds() async* {
    yield Set<String>.of(blocked);
    yield* changes.stream;
  }

  @override
  Future<String> reportContent({
    required String reason,
    String? reportedUserId,
    String? chatId,
    String? messageId,
    String? details,
  }) async {
    reportCalls.add((
      reason: reason,
      userId: reportedUserId,
      chatId: chatId,
      messageId: messageId,
    ));
    final error = reportError;
    if (error != null) throw error;
    return 'report-${reportCalls.length}';
  }

  @override
  Future<void> blockUser(String userId) async {
    blockCalls.add(userId);
    final error = blockError;
    if (error != null) throw error;
    blocked.add(userId);
    changes.add(Set<String>.of(blocked));
  }

  @override
  Future<void> unblockUser(String userId) async {
    unblockCalls.add(userId);
    blocked.remove(userId);
    changes.add(Set<String>.of(blocked));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeChatService service, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        blockedUserIdsProvider.overrideWith((_) => service.watchBlockedIds()),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        locale: locale,
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: PartnerProfilePage(chat: _chat()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openReport(WidgetTester tester, Locale locale) async {
  final l10n = lookupAppLocalizations(locale);
  await tester.ensureVisible(find.text(l10n.reportPerson('Alice')));
  await tester.tap(find.text(l10n.reportPerson('Alice')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile opens as a page and returns to chat', (tester) async {
    final service = _FakeChatService();
    addTearDown(service.changes.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatServiceProvider.overrideWithValue(service),
          blockedUserIdsProvider.overrideWith((_) => service.watchBlockedIds()),
        ],
        child: MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPartnerProfilePage(context, chat: _chat()),
                child: const Text('Open profile'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerProfilePage), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open profile'), findsOneWidget);
    expect(find.byType(PartnerProfilePage), findsNothing);
  });

  testWidgets('renders one full profile page in every launch locale', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final service = _FakeChatService();
      addTearDown(service.changes.close);
      final l10n = lookupAppLocalizations(locale);
      await _pumpPage(tester, service, locale: locale);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text(l10n.reportPerson('Alice')), findsOneWidget);
      expect(find.text(l10n.blockPerson('Alice')), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('short screen keeps both Safety actions reachable', (
    tester,
  ) async {
    final service = _FakeChatService();
    addTearDown(service.changes.close);
    await _pumpPage(tester, service, size: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.text('Report Alice'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Report Alice'), findsOneWidget);
    expect(find.text('Block Alice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('person Report opens spam dialog without message reasons', (
    tester,
  ) async {
    final service = _FakeChatService();
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);

    await _openReport(tester, const Locale('en'));

    expect(find.text('Report spam?'), findsOneWidget);
    expect(find.text('Report Alice for spam?'), findsNothing);
    expect(find.text('Harassment or bullying'), findsNothing);
    expect(find.text('Hate speech'), findsNothing);

    final title = tester.widget<Text>(find.text('Report spam?'));
    final body = tester.widget<Text>(
      find.text(
        "Blab will be notified that Alice may be sending spam. "
        "Messages from this chat won't be included.",
      ),
    );
    expect(title.textAlign, TextAlign.start);
    expect(body.textAlign, TextAlign.start);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.widgetWithText(TextButton, 'Report spam'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Report and block'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('Report spam stores a user report without a message id', (
    tester,
  ) async {
    final service = _FakeChatService();
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);
    await _openReport(tester, const Locale('en'));

    await tester.tap(find.text('Report spam'));
    await tester.pumpAndSettle();

    expect(service.reportCalls, [
      (reason: 'spam', userId: 'alice-id', chatId: 'chat-1', messageId: null),
    ]);
    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.text('Report Alice'), findsOneWidget);
  });

  testWidgets('Report and block performs both and exposes Unblock', (
    tester,
  ) async {
    final service = _FakeChatService();
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);
    await _openReport(tester, const Locale('en'));

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();

    expect(service.reportCalls, hasLength(1));
    expect(service.blockCalls, ['alice-id']);
    expect(find.text('Unblock Alice'), findsOneWidget);
    expect(find.text('Report submitted'), findsOneWidget);
  });

  testWidgets('report success with block failure retries only Block', (
    tester,
  ) async {
    final service = _FakeChatService()..blockError = StateError('offline');
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);
    await _openReport(tester, const Locale('en'));

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();
    expect(find.text("Report submitted. Couldn't block."), findsOneWidget);

    service.blockError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.reportCalls, hasLength(1));
    expect(service.blockCalls, ['alice-id', 'alice-id']);
    expect(find.text('Unblock Alice'), findsOneWidget);
  });

  testWidgets('block success with report failure retries only Report', (
    tester,
  ) async {
    final service = _FakeChatService()..reportError = StateError('offline');
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);
    await _openReport(tester, const Locale('en'));

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();
    expect(find.text("Alice blocked. Couldn't submit report."), findsOneWidget);

    service.reportError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(service.blockCalls, ['alice-id']);
    expect(service.reportCalls, hasLength(2));
    expect(find.text('Unblock Alice'), findsOneWidget);
  });

  testWidgets('both failures stay in the dialog', (tester) async {
    final service = _FakeChatService()
      ..reportError = StateError('offline')
      ..blockError = StateError('offline');
    addTearDown(service.changes.close);
    await _pumpPage(tester, service);
    await _openReport(tester, const Locale('en'));

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();

    expect(find.text('Report spam?'), findsOneWidget);
    expect(find.text("Couldn't report or block. Try again."), findsOneWidget);
  });
}
