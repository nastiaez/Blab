import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(Platform.environment['BLAB_QA_OUTPUT']!);
  await output.create(recursive: true);
  Process? recording;
  final android = Platform.environment['BLAB_QA_RECORD_ANDROID'] == '1';
  final ios = Platform.environment['BLAB_QA_RECORD_IOS'] == '1';
  if (ios) {
    recording = await Process.start('xcrun', [
      'simctl',
      'io',
      'B15A31DB-1DA2-4114-8FF5-D9D5C1D6D4DA',
      'recordVideo',
      '--codec=h264',
      '${output.path}/journey.mp4',
    ]);
  }
  if (android) {
    recording = await Process.start('adb', [
      '-s',
      'emulator-5554',
      'shell',
      'screenrecord',
      '--time-limit',
      '60',
      '/sdcard/bla6-journey.mp4',
    ]);
  }
  await integrationDriver(
    responseDataCallback: (_) async {
      if (recording != null) {
        if (ios) {
          recording!.kill(ProcessSignal.sigint);
          await recording!.exitCode;
        } else {
          await Process.run('adb', [
            '-s',
            'emulator-5554',
            'shell',
            'pkill',
            '-INT',
            'screenrecord',
          ]);
          await recording!.exitCode;
          await Process.run('adb', [
            '-s',
            'emulator-5554',
            'pull',
            '/sdcard/bla6-journey.mp4',
            '${output.path}/journey.mp4',
          ]);
        }
      }
    },
    onScreenshot: (name, bytes, [args]) async {
      if (android && recording == null) {
        recording = await Process.start('adb', [
          '-s',
          'emulator-5554',
          'shell',
          'screenrecord',
          '--time-limit',
          '45',
          '/sdcard/bla6-journey.mp4',
        ]);
      }
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return true;
    },
  );
}
