import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';
Future<void> main() async {
 final output = Directory(Platform.environment['BLAB_QA_OUTPUT']!);
 await output.create(recursive:true);
 await integrationDriver(onScreenshot:(name,bytes,[args]) async {
   await Future<void>.delayed(const Duration(milliseconds:350));
   final result = await Process.run('adb',['-s','emulator-5588','exec-out','screencap','-p'],stdoutEncoding:null);
   if(result.exitCode != 0) return false;
   await File('${output.path}/$name.png').writeAsBytes(result.stdout as List<int>);
   return true;
 });
}
