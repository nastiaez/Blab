import 'dart:async';

import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabled = bool.fromEnvironment('RUN_LOCAL_SUPABASE_INTEGRATION');
const _providerEnabled = bool.fromEnvironment(
  'RUN_LOCAL_OPENROUTER_INTEGRATION',
);
const _url = String.fromEnvironment('SUPABASE_URL');
const _publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _password = 'Blab-local-123!';
const _providerTestTimeoutMinutes = int.fromEnvironment(
  'BLAB_OPENROUTER_TEST_TIMEOUT_MINUTES',
  defaultValue: 5,
);
const _providerCallTimeoutSeconds = int.fromEnvironment(
  'BLAB_OPENROUTER_CALL_TIMEOUT_SECONDS',
  defaultValue: 90,
);
const _providerSmokeTimeout = Timeout(
  Duration(minutes: _providerTestTimeoutMinutes),
);
const _providerCallTimeout = Duration(seconds: _providerCallTimeoutSeconds);

SupabaseClient _client(String key) {
  return SupabaseClient(
    _url,
    key,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

Future<void> _signIn(SupabaseClient client, String email) async {
  await SupabaseAuthService(client).signIn(email: email, password: _password);
  expect(client.auth.currentUser?.email, email);
}

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

Future<Map<String, dynamic>> _invokeProviderTranslation(
  SupabaseClient client, {
  required String messageId,
  required String stage,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    final response = await client.functions
        .invoke('translate-message', body: {'messageId': messageId})
        .timeout(_providerCallTimeout);
    debugPrint(
      'Live translate-message "$stage" finished in '
      '${stopwatch.elapsedMilliseconds}ms with status ${response.status}.',
    );
    expect(response.status, 200);
    return _map(response.data);
  } on TimeoutException catch (error) {
    fail(
      'Live translate-message "$stage" timed out after '
              '${_providerCallTimeout.inSeconds}s. Check the local functions terminal '
              'for OpenRouter/provider logs. ${error.message ?? ''}'
          .trim(),
    );
  } on FunctionException catch (error) {
    debugPrint(
      'Live translate-message "$stage" failed in '
      '${stopwatch.elapsedMilliseconds}ms with status ${error.status}: '
      '${error.details}',
    );
    rethrow;
  } catch (error) {
    debugPrint(
      'Live translate-message "$stage" failed in '
      '${stopwatch.elapsedMilliseconds}ms: $error',
    );
    rethrow;
  } finally {
    stopwatch.stop();
  }
}

Future<List<({SupabaseClient client, String language})>> _setInterfaceLanguage(
  Iterable<SupabaseClient> clients,
  String language,
) async {
  final previous = <({SupabaseClient client, String language})>[];
  for (final client in clients) {
    final user = client.auth.currentUser;
    if (user == null) continue;
    final row = await client
        .from('profiles')
        .select('interface_language')
        .eq('id', user.id)
        .single();
    previous.add((
      client: client,
      language: row['interface_language'] as String,
    ));
    await client.rpc(
      'update_my_interface_language',
      params: {'p_interface_language': language},
    );
  }
  return previous;
}

Future<void> _restoreInterfaceLanguages(
  List<({SupabaseClient client, String language})> previous,
) async {
  for (final entry in previous) {
    try {
      await entry.client.rpc(
        'update_my_interface_language',
        params: {'p_interface_language': entry.language},
      );
    } catch (_) {
      // Cleanup must continue even if an account was suspended by this test.
    }
  }
}

Future<void> _clearTranslationUsage(
  SupabaseClient admin,
  Iterable<SupabaseClient> clients,
) async {
  for (final client in clients) {
    final user = client.auth.currentUser;
    if (user == null) continue;
    await admin.from('translation_usage').delete().eq('user_id', user.id);
  }
}

void main() {
  test(
    'translation API enforces auth, membership, quota, and cache ownership',
    () async {
      expect(_url, isNotEmpty);
      expect(_publicKey, isNotEmpty);
      expect(_serviceRoleKey, isNotEmpty);

      final admin = _client(_serviceRoleKey);
      final anonymous = _client(_publicKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final carol = _client(_publicKey);
      final clients = [admin, anonymous, alice, bob, carol];
      String? chatId;
      String? inviteToken;
      String? reportId;
      var previousLocales = <({SupabaseClient client, String language})>[];

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);
        await _clearTranslationUsage(admin, [alice, bob]);
        previousLocales = await _setInterfaceLanguage([alice, bob], 'en');

        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        final message = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Hello secure translation');

        await expectLater(
          anonymous.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          ),
          throwsA(isA<FunctionException>()),
        );
        await expectLater(
          carol.functions.invoke(
            'translate-message',
            body: {'messageId': message.id},
          ),
          throwsA(
            isA<FunctionException>().having(
              (error) => error.status,
              'status',
              403,
            ),
          ),
        );

        final prepared = _map(
          await alice.rpc(
            'request_message_translation',
            params: {'p_message_id': message.id},
          ),
        );
        expect(prepared['status'], 'ready');
        expect(prepared['targetLang'], 'de');
        expect(prepared['text'], 'Hello secure translation');

        await expectLater(
          alice.from('message_translations').insert({
            'message_id': message.id,
            'target_lang': 'de',
            'interface_lang': 'en',
            'translation_text': 'forged',
            'interface_text': 'forged',
            'source_lang': 'en',
            'tokens': <Map<String, dynamic>>[],
            'source_hash': List.filled(64, '0').join(),
          }),
          throwsA(isA<PostgrestException>()),
        );

        expect(
          await admin.rpc(
            'complete_message_translation',
            params: {
              'p_message_id': message.id,
              'p_requester_id': alice.auth.currentUser!.id,
              'p_target_lang': prepared['targetLang'],
              'p_interface_lang': prepared['interfaceLang'],
              'p_source_hash': prepared['sourceHash'],
              'p_translation_text': 'Hallo sichere Uebersetzung',
              'p_interface_text': 'Hello secure translation',
              'p_source_lang': 'en',
              'p_aid_mode': 'translation',
              'p_explanation': null,
              'p_confidence': null,
              'p_tokens': [
                {
                  'text': 'Hallo sichere Uebersetzung',
                  'gloss': 'Hello secure translation',
                  'isContent': true,
                },
              ],
            },
          ),
          isTrue,
        );

        final response = await alice.functions.invoke(
          'translate-message',
          body: {'messageId': message.id},
        );
        final translated = _map(response.data);
        expect(response.status, 200);
        expect(translated['translation'], 'Hallo sichere Uebersetzung');
        expect(translated['interfaceText'], 'Hello secure translation');
        expect(translated['interfaceLang'], 'en');
        expect(
          (await admin
              .from('translation_usage')
              .select('minute_requests')
              .eq('user_id', alice.auth.currentUser!.id)
              .single())['minute_requests'],
          1,
        );

        final raceMessage = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Before edit');
        final racePrepared = _map(
          await alice.rpc(
            'request_message_translation',
            params: {'p_message_id': raceMessage.id},
          ),
        );
        await ChatService(
          bob,
        ).editMessage(messageId: raceMessage.id, newBody: 'After edit');
        expect(
          await admin.rpc(
            'complete_message_translation',
            params: {
              'p_message_id': raceMessage.id,
              'p_requester_id': alice.auth.currentUser!.id,
              'p_target_lang': racePrepared['targetLang'],
              'p_interface_lang': racePrepared['interfaceLang'],
              'p_source_hash': racePrepared['sourceHash'],
              'p_translation_text': 'Vor Bearbeitung',
              'p_interface_text': 'Before edit',
              'p_source_lang': 'en',
              'p_aid_mode': 'translation',
              'p_explanation': null,
              'p_confidence': null,
              'p_tokens': <Map<String, dynamic>>[],
            },
          ),
          isFalse,
        );

        reportId = await ChatService(alice).reportContent(
          reason: 'spam',
          reportedUserId: bob.auth.currentUser!.id,
          chatId: chatId,
        );
        await admin.rpc(
          'moderate_report',
          params: {
            'p_report_id': reportId,
            'p_action': 'suspend_account',
            'p_notes': 'L-13 local authorization test',
          },
        );
        final suspended = _map(
          await bob.rpc(
            'request_message_translation',
            params: {'p_message_id': message.id},
          ),
        );
        expect(suspended['status'], 'forbidden');
      } finally {
        if (reportId != null) {
          await admin
              .from('account_enforcements')
              .delete()
              .eq('user_id', bob.auth.currentUser?.id ?? '');
          await admin
              .from('moderation_actions')
              .delete()
              .eq('report_id', reportId);
          await admin.from('reports').delete().eq('id', reportId);
        }
        await _clearTranslationUsage(admin, [alice, bob]);
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await _restoreInterfaceLanguages(previousLocales);
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled
        ? false
        : 'Run through scripts/local_test.sh integration against local Supabase.',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'ZDR route translates once and serves the next request from cache',
    () async {
      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      String? chatId;
      String? inviteToken;
      var previousLocales = <({SupabaseClient client, String language})>[];

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
        ]);
        previousLocales = await _setInterfaceLanguage([alice, bob], 'en');
        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'fr');
        final message = await ChatService(
          bob,
        ).sendMessage(chatId: chatId, body: 'Hello from the secure route');

        final first = await _invokeProviderTranslation(
          alice,
          messageId: message.id,
          stage: 'ZDR first request',
        );
        expect(first['translation'], isA<String>());
        expect((first['translation'] as String).trim(), isNotEmpty);
        expect(first['interfaceLang'], 'en');
        expect(first['sourceLang'], 'en');
        expect(first['interfaceText'], 'Hello from the secure route');

        final second = await _invokeProviderTranslation(
          alice,
          messageId: message.id,
          stage: 'ZDR cached request',
        );
        expect(second, first);
        expect(
          (await admin
              .from('translation_usage')
              .select('minute_requests')
              .eq('user_id', alice.auth.currentUser!.id)
              .single())['minute_requests'],
          1,
        );
      } finally {
        if (alice.auth.currentUser != null) {
          await admin
              .from('translation_usage')
              .delete()
              .eq('user_id', alice.auth.currentUser!.id);
        }
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await _restoreInterfaceLanguages(previousLocales);
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled && _providerEnabled
        ? false
        : 'Requires local functions plus a development OpenRouter key.',
    timeout: _providerSmokeTimeout,
  );

  test(
    'same-language writing correction applies to author and recipient',
    () async {
      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final carol = _client(_publicKey);
      final clients = [admin, alice, carol];
      String? chatId;
      String? inviteToken;
      var previousLocales = <({SupabaseClient client, String language})>[];

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(carol, 'carol@blab.test'),
        ]);
        previousLocales = await _setInterfaceLanguage([alice, carol], 'en');
        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'de');
        inviteToken = invite.token;
        chatId = await ChatService(
          carol,
        ).claimInvite(token: invite.token, myLearningLanguage: 'de');
        final message = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'Machen du');

        final authorResult = await _invokeProviderTranslation(
          alice,
          messageId: message.id,
          stage: 'same-language author correction',
        );
        expect(authorResult['mode'], 'correction');
        expect(authorResult['sourceLang'], 'de');
        expect(authorResult['translation'], isNot('Machen du'));
        expect((authorResult['interfaceText'] as String).trim(), isNotEmpty);
        expect((authorResult['explanation'] as String).trim(), isNotEmpty);
        expect(authorResult['confidence'], anyOf('low', 'medium', 'high'));

        final recipientResult = await _invokeProviderTranslation(
          carol,
          messageId: message.id,
          stage: 'same-language recipient correction',
        );
        expect(recipientResult['mode'], 'correction');
        expect(recipientResult['translation'], isNot('Machen du'));
        expect(recipientResult['interfaceText'], authorResult['interfaceText']);
        expect((recipientResult['explanation'] as String).trim(), isNotEmpty);

        final greeting = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'Hallo!!');
        final greetingResult = await _invokeProviderTranslation(
          alice,
          messageId: greeting.id,
          stage: 'same-language clean greeting',
        );
        expect(greetingResult['mode'], 'none');
        expect(greetingResult['sourceLang'], 'de');
        expect(greetingResult['translation'], 'Hallo!!');
        expect(greetingResult['interfaceText'], 'Hello!!');

        for (final locale in const {
          'uk': 'привіт',
          'de': 'hallo',
          'es': 'hola',
        }.entries) {
          await alice.rpc(
            'update_my_interface_language',
            params: {'p_interface_language': locale.key},
          );
          final localizedGreeting = await _invokeProviderTranslation(
            alice,
            messageId: greeting.id,
            stage: 'same-language clean greeting locale ${locale.key}',
          );
          expect(localizedGreeting['mode'], 'none');
          expect(localizedGreeting['sourceLang'], 'de');
          expect(localizedGreeting['translation'], 'Hallo!!');
          expect(localizedGreeting['interfaceLang'], locale.key);
          expect(
            (localizedGreeting['interfaceText'] as String).toLowerCase(),
            contains(locale.value),
          );
        }
        await alice.rpc(
          'update_my_interface_language',
          params: {'p_interface_language': 'en'},
        );

        expect(
          await alice
              .from('message_translations')
              .count(CountOption.exact)
              .eq('message_id', message.id)
              .eq('aid_mode', 'correction'),
          1,
        );
        expect(
          await carol
              .from('message_translations')
              .count(CountOption.exact)
              .eq('message_id', message.id)
              .eq('aid_mode', 'correction'),
          1,
        );
      } finally {
        for (final user in [alice.auth.currentUser, carol.auth.currentUser]) {
          if (user != null) {
            await admin
                .from('translation_usage')
                .delete()
                .eq('user_id', user.id);
          }
        }
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await _restoreInterfaceLanguages(previousLocales);
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled && _providerEnabled
        ? false
        : 'Requires local functions plus a development OpenRouter key.',
    timeout: _providerSmokeTimeout,
  );

  test(
    'reported English correction cases keep signal without paragraph-only noise',
    () async {
      final admin = _client(_serviceRoleKey);
      final alice = _client(_publicKey);
      final bob = _client(_publicKey);
      final clients = [admin, alice, bob];
      String? chatId;
      String? inviteToken;
      var previousLocales = <({SupabaseClient client, String language})>[];

      try {
        await Future.wait([
          _signIn(alice, 'alice@blab.test'),
          _signIn(bob, 'bob@blab.test'),
        ]);
        await _clearTranslationUsage(admin, [alice, bob]);
        previousLocales = await _setInterfaceLanguage([alice, bob], 'en');
        final invite = await ChatService(
          alice,
        ).createInvite(myLearningLanguage: 'en');
        inviteToken = invite.token;
        chatId = await ChatService(
          bob,
        ).claimInvite(token: invite.token, myLearningLanguage: 'en');

        final clean = await ChatService(alice).sendMessage(
          chatId: chatId,
          body:
              'I went to the shop yesterday and bought milk for dinner tonight.',
        );
        final cleanResult = await _invokeProviderTranslation(
          alice,
          messageId: clean.id,
          stage: 'English paragraph-only correction guard',
        );
        expect(cleanResult['mode'], 'none');
        expect(
          cleanResult['translation'],
          'I went to the shop yesterday and bought milk for dinner tonight.',
        );
        expect((cleanResult['translation'] as String), isNot(contains('\n')));

        final spelling = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'I goed to the shop yesterday.');
        final spellingResult = await _invokeProviderTranslation(
          alice,
          messageId: spelling.id,
          stage: 'English small spelling mistake',
        );
        expect(spellingResult['mode'], 'correction');
        expect(
          (spellingResult['translation'] as String).toLowerCase(),
          contains('went'),
        );

        final wrongWord = await ChatService(
          alice,
        ).sendMessage(chatId: chatId, body: 'I did a mistake yesterday.');
        final wrongWordResult = await _invokeProviderTranslation(
          alice,
          messageId: wrongWord.id,
          stage: 'English contextual wrong word',
        );
        expect(wrongWordResult['mode'], 'correction');
        expect(
          (wrongWordResult['translation'] as String).toLowerCase(),
          contains('made'),
        );

        final recipientResult = await _invokeProviderTranslation(
          bob,
          messageId: spelling.id,
          stage: 'English correction recipient cache',
        );
        expect(recipientResult['mode'], 'correction');
        expect(recipientResult['translation'], spellingResult['translation']);
        expect((recipientResult['interfaceText'] as String).trim(), isNotEmpty);
      } finally {
        await _clearTranslationUsage(admin, [alice, bob]);
        if (inviteToken != null) {
          await admin.from('invites').delete().eq('token', inviteToken);
        }
        if (chatId != null) {
          await admin.from('chats').delete().eq('id', chatId);
        }
        await _restoreInterfaceLanguages(previousLocales);
        await Future.wait(clients.map((client) => client.dispose()));
      }
    },
    skip: _enabled && _providerEnabled
        ? false
        : 'Requires local functions plus a development OpenRouter key.',
    timeout: _providerSmokeTimeout,
  );
}
