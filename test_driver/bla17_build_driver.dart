// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(Platform.environment['BLAB_QA_OUTPUT']!);
  await output.create(recursive: true);
  await Process.start('adb', [
    '-s',
    'emulator-5586',
    'shell',
    'screenrecord',
    '--time-limit',
    '180',
    '/sdcard/bla17-final-review.mp4',
  ]);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File(output.path + '/' + name + '.png').writeAsBytes(bytes);
      if (name == 'long-final-end') {
        await Process.run('adb', [
          '-s',
          'emulator-5586',
          'shell',
          'pkill',
          '-INT',
          'screenrecord',
        ]);
        await Future<void>.delayed(const Duration(seconds: 2));
        await Process.run('adb', [
          '-s',
          'emulator-5586',
          'pull',
          '/sdcard/bla17-final-review.mp4',
          output.path + '/native-review.mp4',
        ]);
      }
      return true;
    },
  );
}
