import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/widgets/blab_icon.dart';

Future<void> expectVisibleAvatar(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    final decoded = find
        .byType(RawImage)
        .evaluate()
        .where((e) => (e.widget as RawImage).image != null);
    if (decoded.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail(
    'Avatar must contain decoded pixels, not merely an Image widget or server path',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  Future<void> capture(String name) async {
    if (Platform.isAndroid) {
      debugPrint('BLA39_CAPTURE:$name');
      await Future<void>.delayed(const Duration(seconds: 2));
    } else {
      await binding.takeScreenshot(name);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  testWidgets(
    'real native picker and isolated authenticated avatar Save Remove',
    (tester) async {
      final client = SupabaseClient(
        Platform.isAndroid ? 'http://10.0.2.2:65421' : 'http://127.0.0.1:65421',
        const String.fromEnvironment('QA_ANON'),
      );
      await client.auth.signInWithPassword(
        email: 'alice18816@bla39.local',
        password: const String.fromEnvironment('QA_PASSWORD'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [supabaseClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: blabTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      debugPrint(
        'BLA39_VIEWPORT:${tester.view.physicalSize} DPR:${tester.view.devicePixelRatio}',
      );
      await capture('01-entry-real');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await capture('02-empty-real');
      await tester.tap(find.text('Photo'));
      await tester.pump();
      debugPrint('BLA39_NATIVE_CANCEL');
      await Future<void>.delayed(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Crop photo'), findsNothing);
      expect(find.text('Edit photo'), findsOneWidget);
      await capture('02b-native-photo-cancel');
      await tester.tap(find.text('Camera'));
      await tester.pump();
      debugPrint('BLA39_NATIVE_CAMERA');
      await Future<void>.delayed(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Crop photo'), findsNothing);
      expect(find.text('Edit photo'), findsOneWidget);
      await capture('02c-native-camera-return');
      await tester.tap(find.text('Photo'));
      await tester.pump();
      debugPrint('BLA39_REAL18633_PICKER_OPEN');
      await Future<void>.delayed(const Duration(seconds: 45));
      await tester.pumpAndSettle();
      expect(find.text('Crop photo'), findsOneWidget);
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
      await tester.pumpAndSettle();
      await capture('03-crop-real');
      await tester.tap(find.byTooltip('Confirm crop'));
      await tester.pumpAndSettle();
      await capture('04-draft-real');
      debugPrint('BLA39_STORAGE_STOP');
      await Future<void>.delayed(const Duration(seconds: 4));
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        if (find
            .text('Could not update your profile. Try again.')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.text('Could not update your profile. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Edit photo'), findsOneWidget);
      await expectVisibleAvatar(tester);
      await capture('04b-real-storage-error-draft-preserved');
      debugPrint('BLA39_STORAGE_START');
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.tap(find.text('Save'));
      for (
        var i = 0;
        i < 30 && find.text('Edit photo').evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Edit profile'), findsOneWidget);
      final service = ProfileService(client);
      final saved = await service.fetchCurrentProfile();
      expect(saved.avatarPath, isNotNull);
      expect(saved.avatarUrl, isNotNull);
      for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      }
      expect(find.byType(Image), findsWidgets);
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
      await tester.pumpAndSettle();
      await expectVisibleAvatar(tester);
      await capture('05-saved-real');
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: 'alice18816@bla39.local',
        password: const String.fromEnvironment('QA_PASSWORD'),
      );
      expect(
        (await service.fetchCurrentProfile()).avatarPath,
        saved.avatarPath,
      );
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [supabaseClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: blabTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectVisibleAvatar(tester);
      await capture('05b-relogin-visible-real');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await capture('05c-saved-photo-editor');
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      await capture('05d-unsaved-removal');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is BlabIcon && w.name == 'nav-arrow-left - 20',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (await service.fetchCurrentProfile()).avatarPath,
        saved.avatarPath,
      );
      await expectVisibleAvatar(tester);
      await capture('05e-back-discards-removal');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      for (
        var i = 0;
        i < 30 && find.text('Edit photo').evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
      }
      expect((await service.fetchCurrentProfile()).avatarPath, isNull);
      await capture('06-removed-real');
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: 'alice18816@bla39.local',
        password: const String.fromEnvironment('QA_PASSWORD'),
      );
      expect((await service.fetchCurrentProfile()).avatarPath, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await client.auth.signOut();
      await client.dispose();
    },
  );
}
