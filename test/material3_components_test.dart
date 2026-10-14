import 'package:blab/app/theme.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/widgets/selection/blab_language_chip.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/chat_mode_toggle.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/widgets/navigation/blab_navigation_bar.dart';
import 'package:blab/shared/widgets/settings/blab_setting_switch_row.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate, ImageByteFormat;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  theme: blabTheme,
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);
void main() {
  testWidgets('pressed toggle ink cannot paint outside the visible capsule', (
    tester,
  ) async {
    const boundaryKey = ValueKey('toggle-ink-boundary');
    await tester.pumpWidget(
      _host(
        UnconstrainedBox(
          child: RepaintBoundary(
            key: boundaryKey,
            child: BlabChatModeToggle.segmented(
              practice: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    Future<List<int>> pixels() => tester
        .runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
          image.dispose();
          return bytes!.buffer.asUint8List().toList();
        })
        .then((value) => value!);
    final before = await pixels();
    final press = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('mode-toggle-segment-flash - 16')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 80));
    final during = await pixels();
    final width = boundary.size.width.toInt();
    // The 44-high accessible target has five transparent pixels above/below
    // the 34-high pill; pressed feedback must not reach either margin.
    for (final y in [0, 1, 2, 3, 4, 39, 40, 41, 42, 43]) {
      final start = y * width * 4;
      expect(
        during.sublist(start, start + width * 4),
        before.sublist(start, start + width * 4),
      );
    }
    expect(during, isNot(equals(before)));
    await press.up();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'native language chip keeps the original centered 32-high label',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: BlabLanguageChip(
              language: kBlabLanguages.firstWhere(
                (language) => language.code == 'en',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pill = tester.getRect(find.byType(BlabLanguageChip));
      final label = tester.getRect(find.text('English'));
      expect(pill.height, 32);
      expect(label.center.dy, closeTo(pill.center.dy, 0.01));
      expect(label.left - pill.left, closeTo(13, 0.01));
    },
  );

  testWidgets('navigation top border survives the native bar paint', (
    tester,
  ) async {
    const boundaryKey = ValueKey('navigation-paint');
    await tester.pumpWidget(
      _host(
        RepaintBoundary(
          key: boundaryKey,
          child: BlabNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final rgba = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    final pixel = (boundary.size.width ~/ 2) * 4;
    expect(rgba!.buffer.asUint8List().sublist(pixel, pixel + 4), [
      0xE1,
      0xDA,
      0xD2,
      0xFF,
    ]);
  });
  testWidgets(
    'custom capsule keyboard activation is single and disabled state blocks it',
    (tester) async {
      var practice = false;
      var enabled = true;
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BlabChatModeToggle.segmented(
                practice: practice,
                onChanged: enabled
                    ? (next) {
                        calls++;
                        setState(() => practice = next);
                      }
                    : null,
              );
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(practice, isTrue);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(find.byType(BlabChatModeToggle));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );

  testWidgets(
    'account switch announces its label and only the switch handles pointer taps',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          BlabSettingSwitchRow(
            label: 'Typing indicators',
            caption: 'Shared typing policy',
            value: true,
            onChanged: (_) => calls++,
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, contains('Typing indicators'));
      expect(
        node.getSemanticsData().flagsCollection.isToggled,
        Tristate.isTrue,
      );
      await tester.tap(find.text('Typing indicators'));
      expect(calls, 0);
      await tester.tap(find.byType(Switch));
      expect(calls, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'custom capsule segments each activate once; semantics retain mode',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var value = false;
      final calls = <bool>[];
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => BlabChatModeToggle.segmented(
              practice: value,
              onChanged: (next) {
                calls.add(next);
                setState(() => value = next);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(BlabChatModeToggle));
      expect(
        node.getSemanticsData().flagsCollection.isToggled != Tristate.none,
        isTrue,
      );
      expect(node.label, 'Normal mode');
      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();
      expect(calls, [true]);
      expect(
        tester
            .widget<BlabChatModeToggle>(find.byType(BlabChatModeToggle))
            .practice,
        isTrue,
      );
      await tester.tap(find.byType(BlabChatModeToggle));
      await tester.pumpAndSettle();
      expect(calls, [true, false]);
      semantics.dispose();
    },
  );
  testWidgets(
    'native destinations change selection without duplicate activation',
    (tester) async {
      var selected = 0;
      final calls = <int>[];
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => BlabNavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (index) {
                calls.add(index);
                setState(() => selected = index);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(calls, [1]);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    },
  );
  for (final locale in ['en', 'de', 'es', 'uk']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'native chat header is reachable at 320 width, $locale, ${scale * 100}% text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _host(
              ChatHeaderFrame(
                identity: ChatHeaderIdentity(
                  name: 'Bob Local Long Name',
                  typing: true,
                  onTap: () {},
                ),
                modeControl: BlabChatModeToggle.segmented(
                  practice: false,
                  onChanged: (_) {},
                ),
                menuButton: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
                onBack: () {},
              ),
              locale: Locale(locale),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final control = tester.getRect(find.byType(BlabChatModeToggle));
          expect(control.right, lessThanOrEqualTo(320));
          expect(control.left, greaterThanOrEqualTo(0));
        },
      );
    }
  }
}
