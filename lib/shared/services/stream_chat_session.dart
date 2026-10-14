import 'dart:async';

import 'package:stream_chat/stream_chat.dart' as stream;
import 'package:flutter/foundation.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// US-031: one identity-scoped connection, using server-minted credentials.
class StreamChatSession {
  StreamChatSession(this._supabase, {this.backgroundFetch = false});

  final bool backgroundFetch;

  final SupabaseClient _supabase;
  stream.StreamChatClient? _client;
  String? _userId;
  bool _disposed = false;
  Future<void>? _connecting;

  stream.StreamChatClient get client {
    final value = _client;
    if (value == null || _disposed) throw StateError('stream_not_connected');
    if (_supabase.auth.currentUser?.id != _userId) {
      throw StateError('stream_account_changed');
    }
    return value;
  }

  Future<Map<String, dynamic>> _credentials(String expectedUserId) async {
    if (_disposed || _supabase.auth.currentUser?.id != expectedUserId) {
      throw StateError('stream_account_changed');
    }
    final response = await _supabase.functions.invoke('stream-token');
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      throw StateError('stream_token_unavailable');
    }
    final value = Map<String, dynamic>.from(data);
    if (_disposed ||
        _supabase.auth.currentUser?.id != expectedUserId ||
        value['userId'] != expectedUserId ||
        value['apiKey'] is! String ||
        value['token'] is! String) {
      throw StateError('stream_identity_mismatch');
    }
    return value;
  }

  Future<void> connect() {
    final existing = _connecting;
    if (existing != null) return existing;
    final work = _connect();
    _connecting = work;
    unawaited(
      work.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_connecting, work)) _connecting = null;
        },
      ),
    );
    return work;
  }

  Future<void> _connect() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _disposed) throw StateError('not_signed_in');
    if (_userId != null && _userId != userId) {
      throw StateError('stream_account_changed');
    }
    if (_client != null) throw StateError('stream_already_connected');
    _userId = userId;
    final credentials = await _credentials(userId);
    final client = stream.StreamChatClient(
      credentials['apiKey'] as String,
      logLevel: stream.Level.OFF,
    );
    if (!kIsWeb && !backgroundFetch) {
      client.chatPersistenceClient = StreamChatPersistenceClient(
        connectionMode: ConnectionMode.background,
        logLevel: stream.Level.OFF,
      );
    }
    _client = client;
    try {
      var initialToken = credentials['token'] as String?;
      await client.connectUserWithProvider(stream.User(id: userId), (id) async {
        if (id != _userId ||
            _disposed ||
            _supabase.auth.currentUser?.id != id) {
          throw StateError('stream_identity_mismatch');
        }
        final token = initialToken;
        initialToken = null;
        if (token != null) return token;
        return (await _credentials(id))['token'] as String;
      }, connectWebSocket: !backgroundFetch);
      if (_disposed || _supabase.auth.currentUser?.id != userId) {
        throw StateError('stream_account_changed');
      }
    } catch (_) {
      if (identical(_client, client)) {
        _client = null;
        await client.dispose();
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final client = _client;
    _client = null;
    await client?.dispose();
  }
}
