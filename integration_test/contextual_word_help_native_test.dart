import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;
import '../test/contextual_word_help_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('contextual meanings in actual chat popups', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await journey.runContextualWordHelpJourney(
      tester,
      jsonDecode(contextualWordHelpFixture) as Map<String, dynamic>,
      capture: (name) async {
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${Directory.systemTemp.path}/bla5-$name.png',
        ).writeAsBytes(bytes);
      },
    );
  });
}
