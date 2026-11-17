import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/deep_dive_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'selectable word glyph bounds scale once with the surrounding paragraph',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<Size> mount(double scale) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: blabTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const DeepDiveScreen(
                messageId: 'scale-only',
                authoredText: 'Hallo Bücher.',
                displayText: 'Hallo Bücher.',
                learningLanguageCode: 'de',
                knownLanguageCode: 'en',
                aidsEnabled: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final box = tester.renderObject<RenderBox>(find.text('Hallo'));
        final size =
            box.localToGlobal(box.size.bottomRight(Offset.zero)) -
            box.localToGlobal(Offset.zero);
        expect(tester.takeException(), isNull);
        return Size(size.dx, size.dy);
      }

      final normal = await mount(1);
      final large = await mount(2);
      debugPrint('Selectable Hallo transformed bounds: 1x=$normal 2x=$large');
      expect(large.width, closeTo(normal.width * 2, 0.01));
      expect(large.height, closeTo(normal.height * 2, 0.01));
    },
  );
}
