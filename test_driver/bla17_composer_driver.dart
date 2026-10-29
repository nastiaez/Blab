// ignore_for_file: prefer_interpolation_to_compose_strings, avoid_print
import 'dart:io';
import 'dart:convert';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(Platform.environment['BLAB_QA_OUTPUT']!);
  await output.create(recursive: true);
  final serial = Platform.environment['BLAB_QA_DEVICE'] ?? 'emulator-5586';
  const remote = '/sdcard/bla17-composer16710.mp4';
  final recording = await Process.start('adb', [
    '-s',
    serial,
    'shell',
    'screenrecord',
    '--time-limit',
    '180',
    remote,
  ]);
  final logcat = await Process.start('adb', [
    '-s',
    serial,
    'logcat',
    '-T',
    '1',
    '-v',
    'raw',
    '-s',
    'flutter:I',
  ]);
  final pending = <Future<void>>[];
  logcat.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    final m = RegExp(r'BLA17_CAPTURE:([a-z-]+)').firstMatch(line);
    if (m == null) return;
    final name = m[1]!;
    pending.add(() async {
      final r = await Process.run('adb', [
        '-s',
        serial,
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null);
      if (r.exitCode != 0) throw StateError('screencap failed ' + name);
      await File(
        output.path + '/' + name + '.png',
      ).writeAsBytes(r.stdout as List<int>);
      print('Actual Android capture: ' + name);
    }());
  });
  Future<void> finish(dynamic data) async {
    await Future.wait(pending);
    logcat.kill();
    await Process.run('adb', [
      '-s',
      serial,
      'shell',
      'pkill',
      '-INT',
      'screenrecord',
    ]);
    await recording.exitCode;
    await Process.run('adb', [
      '-s',
      serial,
      'pull',
      remote,
      output.path + '/native-composer.mp4',
    ]);
  }

  await integrationDriver(
    responseDataCallback: finish,
    writeResponseOnFailure: true,
  );
}
