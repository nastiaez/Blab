import 'dart:async';
import 'dart:io';
import 'package:blab/app/theme.dart';
import 'package:blab/app/app_messenger.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blab/features/chat/widgets/translation_report_sheet.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'BLA22 native report sheet → normal auth → isolated real intake',
    (tester) async {
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      const url = String.fromEnvironment('REPORT_QA_URL');
      const key = String.fromEnvironment('REPORT_QA_ANON_KEY');
      expect(Uri.parse(url).host, isIn(['127.0.0.1', '10.0.2.2']));
      final client = SupabaseClient(url, key);
      addTearDown(client.dispose);
      final auth = await client.auth.signInWithPassword(
        email: 'alice@blab.test',
        password: 'Blab-local-123!',
      );
      expect(auth.user?.id, '00000000-0000-4000-8000-00000000000a');
      final service = ChatService(client);
      final pending = Completer<String>();
      String? submissionId;
      String? reportId;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: blabTheme,
          scaffoldMessengerKey: appMessengerKey,
          home: Scaffold(
            backgroundColor: const Color(0xFFFAF7F2),
            appBar: AppBar(title: const Text('Bob · QA fixture')),
            body: Builder(
              builder: (context) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Ist es distracting for you?'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final sent = await showTranslationReportSheet(
                        context,
                        submit: (id, reason, note) async {
                          calls++;
                          submissionId ??= id;
                          if (id != submissionId) {
                            throw StateError('submission_id_changed');
                          }
                          if (calls == 1) return pending.future;
                          reportId = await service.submitTranslationReport(
                            submissionId: id,
                            messageId: '22555555-5555-4555-8555-555555555555',
                            reason: reason.wire,
                            note: note,
                            displayedText: 'Ist es distracting for you?',
                            targetLanguage: 'de',
                            clientMetadata: {
                              'platform': Platform.isIOS ? 'ios' : 'android',
                              'app_version': 'BLA22-20300-QA',
                            },
                          );
                          return reportId!;
                        },
                      );
                      if (sent == true) {
                        showTranslationReportSuccess(
                          'Report sent',
                          bottomClearance: 94,
                        );
                      }
                    },
                    child: const Text('Report translation'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Report translation'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01-reasons-native-fixture');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.tap(find.text('Part wasn’t translated'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'The English phrase wasn’t translated.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-note-native-fixture');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.tap(find.text('Send report'));
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot('03-sending-native-fixture');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 1, reason: 'Duplicate taps cannot resubmit while pending');
      pending.completeError(
        StateError('deliberately injected offline failure'),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04-error-injected-native-fixture');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      expect(
        find.text('The English phrase wasn’t translated.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      for (var attempt = 0; reportId == null && attempt < 40; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(TranslationReportSheet), findsNothing);
      expect(calls, 2);
      expect(reportId, isNotEmpty);
      // Receipt is not a token; retained for private queue correlation.
      debugPrint('BLA22_LOCAL_REPORT_RECEIPT=$reportId');
      await binding.takeScreenshot(
        '05-success-real-local-receipt-native-fixture',
      );
    },
  );
}
