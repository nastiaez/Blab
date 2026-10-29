import 'package:flutter/material.dart';
import '../test/chat_screen_primary_known_language_test.dart' as fixture;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(fixture.mentionsPreview(const String.fromEnvironment('BLAB_MENTION_SCENE', defaultValue: 'picker')));
}
