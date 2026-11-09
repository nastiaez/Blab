import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:blab/features/profile/edit_photo_screen.dart';

void main() {
  testWidgets('photo glyphs use canonical family and render comparison', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1030);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const names = [
      'edit-pencil',
      'check',
      'plus',
      'media-image',
      'profile-circle',
      'camera',
      'close',
      'arrow-up',
      'arrow-right',
    ];
    final font = FontLoader('ReviewArial')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '/System/Library/Fonts/Supplemental/Arial.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final key = GlobalKey();
    Widget icon(String n, int s, double scale) => Transform.scale(
      scale: scale,
      child: BlabIcon(name: '$n - $s', color: Colors.black, size: s.toDouble()),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'ReviewArial'),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xfffaf7f2),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BLA39 / canonical SVG family / 18562',
                      style: TextStyle(fontSize: 24),
                    ),
                    const Text('16px actual | 20px actual | 16px x4 | 20px x4'),
                    for (final n in names)
                      SizedBox(
                        height: 83,
                        child: Row(
                          children: [
                            SizedBox(width: 180, child: Text(n)),
                            for (final spec in [
                              (16, 1.0),
                              (20, 1.0),
                              (16, 4.0),
                              (20, 4.0),
                            ])
                              SizedBox(
                                width: 165,
                                child: Center(child: icon(n, spec.$1, spec.$2)),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        PhotoCircleButton(
                          label: 'Pencil',
                          icon: Icons.edit_outlined,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 24),
                        PhotoCircleButton(
                          label: 'Close',
                          icon: Icons.close,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 24),
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xffff8d56),
                          ),
                          child: const FrozenPhotoIcon(
                            icon: Icons.check,
                            color: Color(0xff46281c),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Text('44px circles / 48px targets; 56px confirm'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final pencil = tester.widget<BlabIcon>(
      find.descendant(
        of: find.byTooltip('Pencil'),
        matching: find.byType(BlabIcon),
      ),
    );
    expect(pencil.name, 'edit-pencil - 20');
    expect(pencil.size, 20);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(
        '/Users/aswin/.openclaw/media/blab-bla39-18562',
      ).create(recursive: true);
      await File(
        '/Users/aswin/.openclaw/media/blab-bla39-18562/icon-family.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
