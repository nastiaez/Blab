import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_channel.dart';
import 'connectivity_state.dart';

/// BLA-15. Release numbers are monotonically increasing per platform/channel.
class AppUpdateNotice {
  const AppUpdateNotice(this.destination);
  final Uri destination;

  static AppUpdateNotice? resolve(
    Map<String, dynamic>? row, {
    required int installedBuild,
    required String channel,
    required String platform,
  }) {
    if (row == null ||
        row['enabled'] != true ||
        installedBuild <= 0 ||
        row['channel'] != channel ||
        row['platform'] != platform) {
      return null;
    }
    final latest = row['latest_build'];
    if (latest is! int || latest <= installedBuild) return null;
    final uri = Uri.tryParse(
      row['destination'] is String ? row['destination'] : '',
    );
    if (uri == null ||
        !validDestination(uri, channel: channel, platform: platform)) {
      return null;
    }
    return AppUpdateNotice(uri);
  }

  static bool validDestination(
    Uri uri, {
    required String channel,
    required String platform,
  }) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    // Public-backend builds also use private distribution before store launch.
    const privateDestinations = {
      (
        'test',
        'android',
      ): 'https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b',
      (
        'public',
        'android',
      ): 'https://appdistribution.firebase.google.com/testerapps/1:363935775546:android:c3a351249463d5f9356e03',
      ('test', 'ios'): 'https://testflight.apple.com/v1/app/6823316052',
      ('public', 'ios'): 'https://testflight.apple.com/v1/app/6823314008',
    };
    if (uri.toString() == privateDestinations[(channel, platform)]) return true;
    if (channel == 'test' && platform == 'ios') {
      return uri.host == 'testflight.apple.com' &&
          RegExp(r'^/join/[A-Za-z0-9]+$').hasMatch(uri.path) &&
          !uri.hasQuery;
    }
    return switch ((channel, platform)) {
      ('public', 'android') =>
        uri.host == 'play.google.com' &&
            uri.path == '/store/apps/details' &&
            uri.queryParameters['id'] == 'blab.nastia.ez',
      ('public', 'ios') =>
        uri.host == 'apps.apple.com' &&
            RegExp(r'/id6823314008$').hasMatch(uri.path) &&
            !uri.hasQuery,
      _ => false,
    };
  }
}

final installedPackageProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

typedef UpdateLinkLauncher = Future<bool> Function(Uri uri);
final updateLinkLauncherProvider = Provider<UpdateLinkLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

typedef UpdateNoticeLoader =
    Future<Map<String, dynamic>?> Function(String channel, String platform);
final updateNoticeLoaderProvider = Provider<UpdateNoticeLoader>(
  (ref) =>
      (channel, platform) => Supabase.instance.client
          .from('app_update_notices')
          .select('channel,platform,enabled,latest_build,destination')
          .eq('channel', channel)
          .eq('platform', platform)
          .maybeSingle()
          .timeout(const Duration(seconds: 5)),
);

/// No stale persisted notice: a failed/missing configuration quietly hides it.
/// Recheck after reconnect, foreground resume, and each foreground minute.
final appUpdateNoticeProvider = FutureProvider.autoDispose<AppUpdateNotice?>((
  ref,
) async {
  if (kIsWeb || !ref.watch(isOnlineProvider)) return null;
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
  if (platform == null) return null;
  final observer = AppLifecycleListener(onResume: ref.invalidateSelf);
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(() {
    observer.dispose();
    timer.cancel();
  });
  try {
    final package = await ref.watch(installedPackageProvider.future);
    final row = await ref.read(updateNoticeLoaderProvider)(
      AppChannel.name,
      platform,
    );
    return AppUpdateNotice.resolve(
      row,
      installedBuild: int.tryParse(package.buildNumber) ?? 0,
      channel: AppChannel.name,
      platform: platform,
    );
  } catch (_) {
    return null;
  }
});
