import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:blab/shared/services/blab_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Review-only entrypoint. Uses production local rendering; no backend/AI/auth fixture.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Review()));
}

class Review extends StatelessWidget {
  const Review({super.key});
  Future<void> show(String scenario) async {
    await BlabLocalNotifications.initialize();
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!
        .requestPermissions(alert: true, sound: true, badge: true);
    await BlabLocalNotifications.cancelAll();
    await const MethodChannel('blab/communication-review').invokeMethod('show', {
      'id': scenario.hashCode,
      'title': scenario == 'Private' ? 'Blab' : scenario == 'Group' ? 'Weekend plans' : 'Alice',
      'body': scenario == 'Private' ? 'You have a new message' : scenario == 'Group' ? 'Alice: Shall we meet at the café?' : 'See you at six!',
      'payload': jsonEncode({
        'previewsEnabled': scenario != 'Private',
        if (scenario != 'Private') 'senderName': 'Alice',
        if (scenario == 'Group') 'groupTitle': 'Weekend plans',
        'blabPreviewBody': scenario == 'Private' ? 'You have a new message' : scenario == 'Group' ? 'Shall we meet at the café?' : 'See you at six!',
        'chatId': 'review-$scenario', 'receiverId': 'review-only',
      }),
    });

  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text('iOS local notification review'),
          const Text('Production renderer. Local fixture, not APNs/live push.'),
          for (final scenario in ['Direct', 'Group', 'Private'])
            ElevatedButton(
              onPressed: () => show(scenario),
              child: Text(scenario),
            ),
        ],
      ),
    ),
  );
}
