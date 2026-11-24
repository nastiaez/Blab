import 'dart:io';
import 'dart:ui' as ui;
import 'package:blab/app/design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'empty illustration orange equals brand; blue notes preserved',
    () async {
      expect(BlabColors.brand.toARGB32(), 0xFFF88C5A);
      final codec = await ui.instantiateImageCodec(
        await File('assets/empty-chats-friends.png').readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var brand = 0, blue = 0, legacy = 0;
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        if (pixels.getUint8(i + 3) == 0) continue;
        final r = pixels.getUint8(i),
            g = pixels.getUint8(i + 1),
            b = pixels.getUint8(i + 2);
        if (r == 248 && g == 140 && b == 90) brand++;
        if (r == 159 && g == 186 && b == 253) blue++;
        if (r >= 250 && g >= 145 && g <= 155 && b >= 55 && b <= 75) legacy++;
      }
      expect(brand, greaterThan(100000));
      expect(blue, greaterThan(1000));
      expect(legacy, 0);
      frame.image.dispose();
      codec.dispose();
    },
  );
}
