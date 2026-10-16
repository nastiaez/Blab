import 'dart:io';

/// Removes only this local fixture's automatically queued work before the test
/// manually completes its translation. No application/API privileges change.
Future<void> isolateDirectTranslationFixture(
  String backendUrl,
  String messageId,
) async {
  final host = Uri.parse(backendUrl).host;
  if (!{'localhost', '127.0.0.1', '::1'}.contains(host) ||
      !RegExp(
        r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
      ).hasMatch(messageId)) {
    throw StateError('Fixture cleanup requires a local backend and UUID');
  }
  final config = File('supabase/config.toml').readAsStringSync();
  final projectId = RegExp(
    r'^project_id = "([^"]+)"',
    multiLine: true,
  ).firstMatch(config)?.group(1);
  if (projectId == null) throw StateError('Local project ID missing');
  final container =
      Platform.environment['BLAB_TEST_DATABASE_CONTAINER'] ??
      'supabase_db_$projectId';
  final result = await Process.run('docker', [
    'exec',
    container,
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '-c',
    "delete from public.message_preparation_jobs where message_id='$messageId'::uuid",
  ]);
  if (result.exitCode != 0) {
    throw StateError('Local fixture cleanup failed: ${result.stderr}');
  }
}
