import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(Platform.environment['BLAB_QA_OUTPUT']!);
  await output.create(recursive: true);
  final recording = await Process.start('adb', [
    '-s',
    'emulator-5580',
    'shell',
    'screenrecord',
    '--time-limit',
    '45',
    '/sdcard/bla27-reading.mp4',
  ]);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return true;
    },
    responseDataCallback: (_) async {
      await Process.run('adb', [
        '-s',
        'emulator-5580',
        'shell',
        'pkill',
        '-INT',
        'screenrecord',
      ]);
      await recording.exitCode;
      await Process.run('adb', [
        '-s',
        'emulator-5580',
        'pull',
        '/sdcard/bla27-reading.mp4',
        '${output.path}/reading.mp4',
      ]);
    },
  );
}
