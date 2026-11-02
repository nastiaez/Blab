import 'dart:io';
import 'package:flutter/services.dart';

/// Use Flutter's bundled Android typeface, not square Ahem glyphs, for
/// untranslated full-size accessibility layout assertions.
Future<void> loadMaterialTestFonts() async {
  var directory = File(Platform.resolvedExecutable).parent;
  while (!Directory('${directory.path}/material_fonts').existsSync()) {
    if (directory.parent.path == directory.path) {
      throw StateError('Flutter bundled Material fonts not found');
    }
    directory = directory.parent;
  }
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final file = File('${directory.path}/material_fonts/Roboto-$weight.ttf');
    loader.addFont(
      Future.value(ByteData.sublistView(await file.readAsBytes())),
    );
  }
  await loader.load();
}
