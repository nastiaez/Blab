import 'dart:async';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/app_update_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_update_notice_test.dart' show releaseRow;

void main() {
  testWidgets(
    'live notice clears on disabled/read failure; refreshes on minute/resume/reconnect',
    (tester) async {
      final online = StreamController<bool>.broadcast();
      var row = releaseRow(channel: 'public');
      var failed = false;
      var requests = 0;
      final requestedScopes = <String>[];
      final container = ProviderContainer(
        overrides: [
          onlineProvider.overrideWith((_) => online.stream),
          installedPackageProvider.overrideWith(
            (_) async => PackageInfo(
              appName: 'Blab',
              packageName: 'blab.nastia.ez',
              version: '1.0.0',
              buildNumber: '30',
            ),
          ),
          updateNoticeLoaderProvider.overrideWithValue((
            channel,
            platform,
          ) async {
            requests++;
            requestedScopes.add('$channel/$platform');
            if (failed) throw StateError('unavailable');
            return row;
          }),
        ],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: OfflineBanner()),
          ),
        ),
      );
      online.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(requests, 1);
      row = {...row, 'enabled': false};
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      row = {...row, 'enabled': true};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(requests, 3, reason: 'resume must reload configuration');
      expect(container.read(appUpdateNoticeProvider).value, isNotNull);
      expect(find.text('Update available'), findsOneWidget);
      online.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      failed = true;
      online.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      failed = false;
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      row = {...row, 'latest_build': 30};
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(requestedScopes, everyElement('public/android'));
      container.dispose();
      await online.close();
    },
  );
}
