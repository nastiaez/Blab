import 'package:url_launcher/url_launcher.dart';

/// Open [url] in the device browser (or the appropriate external app).
/// Returns `true` if a handler opened it. Used for the hosted Privacy
/// Policy / Terms links. Step 3.5.
Future<bool> openExternalUrl(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
