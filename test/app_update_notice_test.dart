import 'package:blab/app/theme.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/app_update_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const destinations = {
  'test/android':
      'https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b',
  'test/ios': 'https://testflight.apple.com/v1/app/6823316052',
  'public/android':
      'https://play.google.com/store/apps/details?id=blab.nastia.ez',
  'public/ios': 'https://apps.apple.com/app/id6823314008',
};
const privateDestinations = {
  'test/android':
      'https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b',
  'test/ios': 'https://testflight.apple.com/v1/app/6823316052',
  'public/android':
      'https://appdistribution.firebase.google.com/testerapps/1:363935775546:android:c3a351249463d5f9356e03',
  'public/ios': 'https://testflight.apple.com/v1/app/6823314008',
};
Map<String, dynamic> releaseRow({
  String channel = 'test',
  String platform = 'android',
}) => {
  'channel': channel,
  'platform': platform,
  'enabled': true,
  'latest_build': 31,
  'destination': destinations['$channel/$platform'],
};

class _EmptyChats extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => [];
}

Future<void> runUpdateBannerJourney(
  WidgetTester tester, {
  Future<void> Function(String)? capture,
  bool native = false,
}) async {
  var notice = AppUpdateNotice(Uri.parse(destinations['test/android']!));
  var available = true;
  var online = true;
  var connecting = false;
  var fail = false;
  final opened = <Uri>[];
  final container = ProviderContainer(
    overrides: [
      appUpdateNoticeProvider.overrideWith(
        (_) async => available ? notice : null,
      ),
      onlineProvider.overrideWith((_) => Stream.value(online)),
      chatListProvider.overrideWith(_EmptyChats.new),
      updateLinkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return !fail;
      }),
    ],
  );
  Future<void> render({String locale = 'en', double scale = 1}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: blabTheme,
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ConnectionStatusScope(
            connecting: connecting,
            child: const ChatsScreen(preview: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  await render();
  expect(find.text('Update available'), findsOneWidget);
  final buttonBounds = tester.getRect(
    find.byKey(const ValueKey('update-download-button')),
  );
  final screenBounds = tester.getRect(find.byType(Scaffold).first);
  expect(screenBounds.right - buttonBounds.right, closeTo(16, 1));
  // Native device pixel conversion can round 48 to 47.999999999999986.
  expect(buttonBounds.height, greaterThanOrEqualTo(48 - 1e-6));
  final face = find.descendant(
    of: find.byKey(const ValueKey('update-download-button')),
    matching: find.byType(Material),
  );
  expect(tester.getSize(face.first).height, closeTo(32, 1e-6));
  // The invisible top/bottom target must activate the compact button too.
  await tester.tapAt(Offset(buttonBounds.center.dx, buttonBounds.top + 2));
  await tester.pumpAndSettle();
  expect(opened.length, 1);
  opened.clear();
  if (capture != null) await capture('01-update-available');
  await tester.tap(find.text('Update available'));
  await tester.pumpAndSettle();
  expect(opened, isEmpty, reason: 'Status text must not be clickable');
  // Route each configured platform/channel without navigating away from chat.
  for (final destination in {
    ...destinations.values,
    ...privateDestinations.values,
  }) {
    notice = AppUpdateNotice(Uri.parse(destination));
    container.invalidate(appUpdateNoticeProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-download-button')));
    await tester.pumpAndSettle();
    expect(opened.last.toString(), destination);
  }
  fail = true;
  await tester.tap(find.byKey(const ValueKey('update-download-button')));
  await tester.pumpAndSettle();
  expect(
    find.text('Couldn’t open the update. Please try again.'),
    findsOneWidget,
  );
  if (capture != null) await capture('02-update-link-retry');
  // Clear the Snackbar before subsequent state captures.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  final attempts = opened.length;
  connecting = true;
  await render();
  expect(find.text('Connecting…'), findsNothing);
  expect(find.text('Update available'), findsNothing);
  // Capture before the tap to exclude Flutter's test-pointer overlay.
  if (capture != null) await capture('03-connecting-not-clickable');
  // Connection checking remains silent; no replacement banner.
  expect(opened.length, attempts);
  connecting = false;
  online = false;
  container.invalidate(onlineProvider);
  await render();
  expect(find.text('No connection'), findsNothing);
  expect(find.text('Update available'), findsNothing);
  // Offline state remains silent.
  expect(opened.length, attempts);
  if (capture != null) await capture('04-offline-not-clickable');
  online = true;
  available = false;
  container.invalidate(onlineProvider);
  container.invalidate(appUpdateNoticeProvider);
  await render();
  expect(find.text('Update available'), findsNothing);
  expect(find.text('No connection'), findsNothing);
  if (capture != null) await capture('05-update-disabled');
  available = true;
  container.invalidate(appUpdateNoticeProvider);
  for (final entry in const {
    'en': 'Update available',
    'de': 'Update verfügbar',
    'es': 'Actualización disponible',
    'uk': 'Доступне оновлення',
  }.entries) {
    await render(locale: entry.key, scale: 2);
    expect(find.text(entry.value), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (capture != null && entry.key == 'uk') {
      await capture('06-ukrainian-large-text');
    }
  }
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
}

void main() {
  test('private update destinations belong to the exact installed app', () {
    for (final entry in privateDestinations.entries) {
      final scope = entry.key.split('/');
      final row = {
        ...releaseRow(channel: scope[0], platform: scope[1]),
        'destination': entry.value,
      };
      expect(
        AppUpdateNotice.resolve(
          row,
          installedBuild: 30,
          channel: scope[0],
          platform: scope[1],
        )?.destination.toString(),
        entry.value,
      );
      for (final other in privateDestinations.entries) {
        if (other.key == entry.key) continue;
        expect(
          AppUpdateNotice.validDestination(
            Uri.parse(other.value),
            channel: scope[0],
            platform: scope[1],
          ),
          isFalse,
          reason: '${entry.key} must not open ${other.key}',
        );
      }
      for (final invalid in [
        '${entry.value}/other',
        '${entry.value}?redirect=https://evil.com',
        entry.value.replaceFirst('https:', 'http:'),
        entry.value.replaceFirst('https://', 'https://user@'),
      ]) {
        expect(
          AppUpdateNotice.validDestination(
            Uri.parse(invalid),
            channel: scope[0],
            platform: scope[1],
          ),
          isFalse,
        );
      }
    }
  });
  test('older clients only, explicit toggle and valid scoped destinations', () {
    for (final entry in destinations.entries) {
      final parts = entry.key.split('/');
      AppUpdateNotice? resolve(Map<String, dynamic>? row, [int build = 30]) =>
          AppUpdateNotice.resolve(
            row,
            installedBuild: build,
            channel: parts[0],
            platform: parts[1],
          );
      final row = releaseRow(channel: parts[0], platform: parts[1]);
      expect(resolve(row)?.destination.toString(), entry.value);
      for (final build in [0, -1, 31, 32]) {
        expect(resolve(row, build), isNull);
      }
      expect(resolve(null), isNull);
      expect(resolve({...row, 'enabled': false}), isNull);
      expect(resolve({...row, 'latest_build': '31'}), isNull);
      expect(resolve({...row, 'channel': 'unknown'}), isNull);
      expect(resolve({...row, 'platform': 'unknown'}), isNull);
      for (final bad in [
        'javascript:alert(1)',
        'https://evil.com',
        '${entry.value}#x',
        'https://user@apps.apple.com/app/id6823314008',
      ]) {
        expect(resolve({...row, 'destination': bad}), isNull);
      }
    }
    expect(
      AppUpdateNotice.validDestination(
        Uri.parse(destinations['test/android']!),
        channel: 'public',
        platform: 'android',
      ),
      isFalse,
    );
    expect(
      AppUpdateNotice.validDestination(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=blab.nastia.ez.test',
        ),
        channel: 'public',
        platform: 'android',
      ),
      isFalse,
    );
  });
  testWidgets('compact update banner at 320 width and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await runUpdateBannerJourney(tester);
  });
  testWidgets('update/toggle/connection priority/launch failure/locales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await runUpdateBannerJourney(tester);
  });
}
