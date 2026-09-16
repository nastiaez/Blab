# Partner Profile Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the partner-profile bottom sheet with a full page, add a Signal-style person-spam confirmation, and reserve the six-reason bottom sheet for message reports.

**Architecture:** `PartnerProfilePage` owns the full-page identity and Safety UI. A focused `partner_report_dialog.dart` owns the modal state and returns a truthful `PartnerReportResult`; the page calls the existing `ChatService` and presents success, partial failure, and retry feedback. The chat pushes the page with a `MaterialPageRoute`, preserving its current in-memory state without adding a deep link.

**Tech Stack:** Flutter Material 3, Riverpod, `ChatService`, Flutter gen-l10n, widget tests, local Supabase integration tests.

---

### Task 1: Localize the person-spam flow

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Modify (generated): `lib/l10n/generated/app_localizations.dart`
- Modify (generated): `lib/l10n/generated/app_localizations_en.dart`
- Modify (generated): `lib/l10n/generated/app_localizations_de.dart`
- Modify (generated): `lib/l10n/generated/app_localizations_es.dart`
- Modify (generated): `lib/l10n/generated/app_localizations_uk.dart`
- Test: `test/app_localization_test.dart`

- [ ] **Step 1: Write the failing localization contract**

Add assertions for every supported locale:

```dart
expect(l10n.reportPersonSpamQuestion('Alice'), isNotEmpty);
expect(l10n.reportPersonSpamBody('Alice'), isNotEmpty);
expect(l10n.submitSpamReport, isNotEmpty);
expect(l10n.reportAndBlock, isNotEmpty);
expect(l10n.reportSubmitted, isNotEmpty);
expect(l10n.couldNotReportOrBlock, isNotEmpty);
expect(l10n.reportSucceededBlockFailed, isNotEmpty);
expect(l10n.blockSucceededReportFailed('Alice'), isNotEmpty);
```

- [ ] **Step 2: Run the test and confirm the getters do not exist**

Run: `flutter test test/app_localization_test.dart`

Expected: compile failure mentioning `reportPersonSpamQuestion` and the other new getters.

- [ ] **Step 3: Add complete EN/DE/ES/UK strings**

Add the same keys to every ARB. The English source is:

```json
"reportPersonSpamQuestion": "Report {name} for spam?",
"reportPersonSpamBody": "Blab will be notified that {name} may be sending spam. Messages from this chat won't be included.",
"submitSpamReport": "Report spam",
"reportAndBlock": "Report and block",
"reportSubmitted": "Report submitted",
"couldNotReportOrBlock": "Couldn't report or block. Try again.",
"reportSucceededBlockFailed": "Report submitted. Couldn't block.",
"blockSucceededReportFailed": "{name} blocked. Couldn't submit report."
```

Add typed `name` placeholder metadata and these translations:

```text
DE: „{name} wegen Spam melden?“ / „Blab wird darüber informiert, dass {name} möglicherweise Spam sendet. Nachrichten aus diesem Chat werden nicht übermittelt.“ / „Spam melden“ / „Melden und blockieren“ / „Meldung gesendet“ / „Melden und Blockieren fehlgeschlagen. Versuche es erneut.“ / „Meldung gesendet. Blockieren fehlgeschlagen.“ / „{name} blockiert. Meldung konnte nicht gesendet werden.“
ES: „¿Denunciar a {name} por spam?“ / „Se informará a Blab de que {name} podría estar enviando spam. Los mensajes de este chat no se incluirán.“ / „Denunciar spam“ / „Denunciar y bloquear“ / „Denuncia enviada“ / „No se pudo denunciar ni bloquear. Inténtalo de nuevo.“ / „Denuncia enviada. No se pudo bloquear.“ / „{name} bloqueado. No se pudo enviar la denuncia.“
UK: „Поскаржитися на спам від {name}?“ / „Blab отримає сповіщення, що {name} може надсилати спам. Повідомлення з цього чату не буде додано.“ / „Поскаржитися на спам“ / „Поскаржитися й заблокувати“ / „Скаргу надіслано“ / „Не вдалося поскаржитися й заблокувати. Спробуйте ще раз.“ / „Скаргу надіслано. Не вдалося заблокувати.“ / „{name} заблоковано. Не вдалося надіслати скаргу.“
```

- [ ] **Step 4: Generate localizations and run the contract**

Run: `flutter gen-l10n && flutter test test/app_localization_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the localization contract**

```bash
git add lib/l10n test/app_localization_test.dart
git commit -m "feat: localize partner spam reporting"
```

### Task 2: Build the Signal-style person-report dialog

**Files:**
- Create: `lib/features/chat/widgets/partner_report_dialog.dart`
- Create: `test/partner_report_dialog_test.dart`

- [ ] **Step 1: Write failing dialog behavior and four-locale tests**

Cover the title/body, three actions, Cancel returning `null`, report returning a result whose `reportSucceeded` is true, report-and-block returning a result whose report and block fields are true, disabled actions while awaiting, and an error that remains in the dialog when both operations fail.

Use this public contract:

```dart
class PartnerReportResult {
  const PartnerReportResult({
    required this.reportSucceeded,
    required this.blockRequested,
    required this.blockSucceeded,
  });

  final bool reportSucceeded;
  final bool blockRequested;
  final bool blockSucceeded;
  bool get anySucceeded => reportSucceeded || blockSucceeded;
}

Future<PartnerReportResult?> showPartnerReportDialog(
  BuildContext context, {
  required String personName,
  required Future<PartnerReportResult> Function({required bool block})
  onSubmit,
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run: `flutter test test/partner_report_dialog_test.dart`

Expected: compile failure because `partner_report_dialog.dart` does not exist.

- [ ] **Step 3: Implement the dialog**

Create a private stateful dialog body that:

```dart
Future<void> _submit({required bool block}) async {
  if (_submitting) return;
  setState(() {
    _submitting = true;
    _error = null;
  });
  final result = await widget.onSubmit(block: block);
  if (!mounted) return;
  if (result.anySucceeded) {
    Navigator.of(context).pop(result);
    return;
  }
  setState(() {
    _submitting = false;
    _error = block
        ? context.l10n.couldNotReportOrBlock
        : context.l10n.couldNotReport;
  });
}
```

Use the existing Blab dialog palette (`chatSurface`, `chatDivider`, `warmInk`, `warmMuted`, `errorSoft`, `errorWarm`), a maximum width of 360, scrollable content for large text, and three full-width 48 px pill buttons ordered Report spam, Report and block, Cancel.

- [ ] **Step 4: Run and pass the dialog tests**

Run: `flutter test test/partner_report_dialog_test.dart`

Expected: PASS in EN/DE/ES/UK with no overflow exceptions.

- [ ] **Step 5: Commit the dialog**

```bash
git add lib/features/chat/widgets/partner_report_dialog.dart test/partner_report_dialog_test.dart
git commit -m "feat: add partner spam report dialog"
```

### Task 3: Replace the profile sheet with a full page

**Files:**
- Create: `lib/features/chat/partner_profile_page.dart`
- Modify: `lib/features/chat/chat_screen.dart:1050-1080`
- Delete: `lib/features/chat/widgets/partner_profile_sheet.dart`
- Create: `test/partner_profile_page_test.dart`

- [ ] **Step 1: Write failing full-page profile tests**

Pump `PartnerProfilePage(chat: chat)` and prove:

```dart
expect(find.byType(Scaffold), findsOneWidget);
expect(find.byType(AppBar), findsOneWidget);
expect(find.text('Alice'), findsOneWidget);
expect(find.text(l10n.reportPerson('Alice')), findsOneWidget);
expect(find.text(l10n.blockPerson('Alice')), findsOneWidget);
expect(find.byType(DraggableScrollableSheet), findsNothing);
```

Repeat the render check for EN/DE/ES/UK and a 320 x 568 viewport; scroll until both Safety rows are tappable and assert `tester.takeException()` is null.

- [ ] **Step 2: Run the focused test and confirm it fails**

Run: `flutter test test/partner_profile_page_test.dart`

Expected: compile failure because `PartnerProfilePage` does not exist.

- [ ] **Step 3: Implement the page with focused private widgets**

Move the existing avatar, language, chat-age, `_Section`, `_LangRow`, and `_SafetyRow` presentation into `partner_profile_page.dart`. The root is:

```dart
class PartnerProfilePage extends ConsumerWidget {
  const PartnerProfilePage({super.key, required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: AppBar(
        backgroundColor: BlabColors.chatSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _IdentityHeader(chat: chat),
            const SizedBox(height: 20),
            _LanguagesCard(chat: chat),
            const SizedBox(height: 16),
            _ChatCard(chat: chat),
            if (chat.partnerId != null) ...[
              const SizedBox(height: 16),
              _SafetyCard(chat: chat),
            ],
          ],
        ),
      ),
    );
  }
}
```

Use warm cards with `#FFFCF8` surfaces and `#E1DAD2` outlines. Preserve all current profile data and live `blockedUserIdsProvider` state.

- [ ] **Step 4: Push the page from the chat header**

Replace `showPartnerProfileSheet` with:

```dart
await Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => PartnerProfilePage(chat: chat),
  ),
);
```

After the route returns, preserve the existing focus restoration behavior. Remove `PartnerProfileResult` and delete the old sheet file.

- [ ] **Step 5: Run and pass the page tests**

Run: `flutter test test/partner_profile_page_test.dart test/chat_screen_primary_known_language_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit the page migration**

```bash
git add lib/features/chat/partner_profile_page.dart lib/features/chat/chat_screen.dart test/partner_profile_page_test.dart
git rm lib/features/chat/widgets/partner_profile_sheet.dart
git commit -m "feat: move partner profile to full page"
```

### Task 4: Connect truthful report, report-and-block, and retries

**Files:**
- Modify: `lib/features/chat/partner_profile_page.dart`
- Modify: `test/partner_profile_page_test.dart`
- Modify: `test/report_block_test.dart`

- [ ] **Step 1: Extend the fake service and write failing action tests**

Use an `implements ChatService` fake that records:

```dart
final reportCalls = <({String reason, String? userId, String? chatId, String? messageId})>[];
final blockCalls = <String>[];
final unblockCalls = <String>[];
Object? reportError;
Object? blockError;
```

Test these exact outcomes:

- Report opens the centered dialog, not `showReportReasonSheet`.
- Report spam calls `reportContent(reason: 'spam', reportedUserId: 'alice-id', chatId: 'chat-1')` with no message ID.
- Report and block calls both operations once and renders Unblock from updated fake stream state.
- Report succeeds/block fails: actionable feedback says `reportSucceededBlockFailed`; Retry calls only `blockUser`.
- Block succeeds/report fails: actionable feedback says `blockSucceededReportFailed`; Retry calls only `reportContent`.
- Both fail: the dialog stays visible with `couldNotReportOrBlock`.
- Rapid repeated taps create one submission.

- [ ] **Step 2: Run the tests and confirm the behavior is absent**

Run: `flutter test test/partner_profile_page_test.dart test/report_block_test.dart`

Expected: FAIL on missing report-dialog wiring and retry behavior.

- [ ] **Step 3: Implement the independent operations**

Add a helper on the page state:

```dart
Future<PartnerReportResult> _submitPartnerReport({required bool block}) async {
  var reportSucceeded = false;
  var blockSucceeded = false;

  await Future.wait([
    _reportSpam().then((_) => reportSucceeded = true).catchError((_) {}),
    if (block)
      _blockPartner().then((_) => blockSucceeded = true).catchError((_) {}),
  ]);

  return PartnerReportResult(
    reportSucceeded: reportSucceeded,
    blockRequested: block,
    blockSucceeded: blockSucceeded,
  );
}
```

`_reportSpam` passes `reason: ReportReason.spam.wire`, the partner ID, and chat ID, with no message ID. `_blockPartner` calls the existing service and refreshes/invalidate the blocked-state provider so the row changes immediately.

- [ ] **Step 4: Present exact success, partial failure, and retry feedback**

After the dialog returns:

```dart
if (result.reportSucceeded && (!result.blockRequested || result.blockSucceeded)) {
  showAppSuccessSnack(context.l10n.reportSubmitted);
} else if (result.reportSucceeded) {
  showAppSnack(
    context.l10n.reportSucceededBlockFailed,
    action: SnackBarAction(label: context.l10n.retry, onPressed: _retryBlock),
  );
} else if (result.blockSucceeded) {
  showAppSnack(
    context.l10n.blockSucceededReportFailed(chat.partnerName),
    action: SnackBarAction(label: context.l10n.retry, onPressed: _retryReport),
  );
}
```

Keep the profile page open after every outcome. Block and Unblock rows continue to use the existing confirmation and feedback rules.

- [ ] **Step 5: Run and pass the action tests**

Run: `flutter test test/partner_profile_page_test.dart test/partner_report_dialog_test.dart test/report_block_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit behavior**

```bash
git add lib/features/chat/partner_profile_page.dart test/partner_profile_page_test.dart test/report_block_test.dart
git commit -m "feat: connect partner report and block actions"
```

### Task 5: Prove message reporting remains separate

**Files:**
- Modify: `lib/features/chat/widgets/report_sheet.dart`
- Modify: `test/report_block_test.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`

- [ ] **Step 1: Rename the report-sheet documentation and tests to message-only**

Update the enum comment to `Reasons a user can pick when reporting a message` and replace the former person-sheet locale test with a message-sheet locale test using `localizations.reportMessage`.

- [ ] **Step 2: Add a regression proving profile Report never shows reasons**

From `PartnerProfilePage`, tap `reportPerson('Alice')` and assert:

```dart
expect(find.text(l10n.reportPersonSpamQuestion('Alice')), findsOneWidget);
expect(find.text(l10n.reportHarassment), findsNothing);
expect(find.text(l10n.reportHate), findsNothing);
```

Then exercise the chat message Report action and assert all six localized reasons are present.

- [ ] **Step 3: Run the separation regressions**

Run: `flutter test test/report_block_test.dart test/chat_screen_primary_known_language_test.dart test/partner_profile_page_test.dart`

Expected: PASS.

- [ ] **Step 4: Commit the regression boundary**

```bash
git add lib/features/chat/widgets/report_sheet.dart test/report_block_test.dart test/chat_screen_primary_known_language_test.dart test/partner_profile_page_test.dart
git commit -m "test: separate person and message reporting"
```

### Task 6: Run quality gates and Android QA

**Files:**
- Modify: `docs/qa/2026-09-16-partner-profile-reporting/README.md`
- Add: `docs/qa/2026-09-16-partner-profile-reporting/*.png`

- [ ] **Step 1: Format and run focused static checks**

Run:

```bash
dart format lib test
flutter analyze
git diff --check
```

Expected: clean.

- [ ] **Step 2: Run the complete Flutter and database suites**

Run:

```bash
flutter test
./scripts/local_test.sh
```

Expected: all non-environment-gated Flutter tests and all 155 database tests pass.

- [ ] **Step 3: Run the Impeccable detector and UI/UX review**

Run the configured Impeccable detector against the changed page/dialog targets. Resolve all applicable high-confidence findings in one batch, then run the UI/UX reviewer once against the Android captures.

- [ ] **Step 4: Verify real Android behavior in all four locales**

For EN/DE/ES/UK, verify:

- chat header opens a page, not a sheet;
- profile content and both Safety actions fit;
- person Report shows only the centered spam dialog;
- Cancel changes nothing;
- Report spam stores a person report with reason `spam` and no message ID;
- Report and block stores the report, blocks the partner, and changes the row to Unblock;
- message long-press still opens the six-reason bottom sheet;
- short-height viewport and enlarged text do not clip actions.

- [ ] **Step 5: Clean QA state and document evidence**

Delete created QA reports and blocks, restore the test account locale/state, and record exact test totals plus screenshot paths in the QA README.

- [ ] **Step 6: Commit verified implementation**

```bash
git add docs/qa/2026-09-16-partner-profile-reporting lib test
git commit -m "test: verify partner profile reporting"
```
