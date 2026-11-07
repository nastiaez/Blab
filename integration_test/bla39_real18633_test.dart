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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real native picker and isolated authenticated avatar Save Remove',
    (tester) async {
      final client = SupabaseClient(
        Platform.isAndroid ? 'http://10.0.2.2:64321' : 'http://127.0.0.1:64321',
        const String.fromEnvironment('QA_ANON'),
      );
      await client.auth.signInWithPassword(
        email: '00000000-0000-4000-8000-00000000000a@bla39.test',
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
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await binding.takeScreenshot('01-entry-real');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-empty-real');
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
      await binding.takeScreenshot('03-crop-real');
      await tester.tap(find.byTooltip('Confirm crop'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04-draft-real');
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
      await binding.takeScreenshot('05-saved-real');
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: '00000000-0000-4000-8000-00000000000a@bla39.test',
        password: const String.fromEnvironment('QA_PASSWORD'),
      );
      expect(
        (await service.fetchCurrentProfile()).avatarPath,
        saved.avatarPath,
      );
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
      await binding.takeScreenshot('06-removed-real');
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: '00000000-0000-4000-8000-00000000000a@bla39.test',
        password: const String.fromEnvironment('QA_PASSWORD'),
      );
      expect((await service.fetchCurrentProfile()).avatarPath, isNull);
      await client.auth.signOut();
      await client.dispose();
    },
  );
}
