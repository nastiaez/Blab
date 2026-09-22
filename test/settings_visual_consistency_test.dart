import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/notification_settings_screen.dart';
import 'package:blab/features/profile/privacy_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailablePushGateway implements PushNotificationGateway {
  const _UnavailablePushGateway();

  @override
  bool get isSupported => false;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.unavailable;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.unavailable;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Future<PushOpenEvent?> initialOpenEvent() async => null;

  @override
  Stream<PushOpenEvent> get onOpenEvent => const Stream.empty();

  @override
  Future<void> openSystemSettings() async {}
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  PushNotificationGateway? pushGateway,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (pushGateway != null)
          pushNotificationGatewayProvider.overrideWithValue(pushGateway),
      ],
      child: MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BoxDecoration _cardDecoration(WidgetTester tester, Key key) {
  final card = find.byKey(key);
  expect(card, findsOneWidget);
  final container = find.descendant(of: card, matching: find.byType(Container));
  return tester.widget<Container>(container.first).decoration! as BoxDecoration;
}

void _expectWarmCard(WidgetTester tester, Key key) {
  final decoration = _cardDecoration(tester, key);
  final border = decoration.border! as Border;
  expect(decoration.color, BlabColors.chatSurface);
  expect(border.top.color, BlabColors.chatDivider);

  final divider = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Divider),
  );
  if (divider.evaluate().isNotEmpty) {
    expect(tester.widget<Divider>(divider.first).color, BlabColors.chatDivider);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Privacy cards use the shared warm surface and divider', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const PrivacyScreen());

    _expectWarmCard(tester, const Key('privacy-settings-card'));
    _expectWarmCard(tester, const Key('privacy-links-card'));
  });

  testWidgets('Notification card uses the shared warm surface and divider', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(
      tester,
      const NotificationSettingsScreen(),
      pushGateway: const _UnavailablePushGateway(),
    );

    _expectWarmCard(tester, const Key('notification-settings-card'));
  });
}
