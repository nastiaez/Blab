import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/app_update_notice_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA-15 native update banner review', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await journey.runUpdateBannerJourney(
      tester,
      native: true,
      capture: (name) async {
        await tester.pump();
        await binding.takeScreenshot(name);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
