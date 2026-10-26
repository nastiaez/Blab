import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Display metadata only. No payload is used to authorize or write chat history.
class NotificationPresentation {
  const NotificationPresentation({
    required this.title,
    required this.body,
    this.sender,
    this.groupName,
  });
  final String title, body;
  final String? sender, groupName;
  bool get isGroup => groupName != null;
  bool get showsIdentity => sender != null;

  static String conversationId(String receiver, String chat) =>
      'blab:${sha256.convert(utf8.encode('$receiver:$chat'))}';

  static NotificationPresentation fromData(
    Map<String, dynamic> data, {
    String? groupName,
    String? interfaceLanguage,
  }) {
    final generic = switch (interfaceLanguage) {
      'de' => 'Du hast eine neue Nachricht',
      'es' => 'Tienes un mensaje nuevo',
      'uk' => 'У вас нове повідомлення',
      _ => 'You have a new message',
    };
    if (data['previewsEnabled'] == 'false' ||
        data['previewsEnabled'] == false) {
      return NotificationPresentation(title: 'Blab', body: generic);
    }
    String? label(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    final sender = label(data['title']);
    final group = label(groupName);
    return NotificationPresentation(
      title: group ?? sender ?? 'Blab',
      body: label(data['body']) == null ? generic : data['body'] as String,
      sender: sender == 'Blab' ? null : sender,
      groupName: group,
    );
  }
}
