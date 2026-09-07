class ChatLanguageEra {
  const ChatLanguageEra({
    required this.revision,
    required this.languageCode,
    this.startedAt,
  });

  final int revision;
  final String languageCode;
  final DateTime? startedAt;
}

List<ChatLanguageEra> parseChatLanguageTimeline(
  List<Map<String, dynamic>> rows,
) {
  final eras = <ChatLanguageEra>[];
  for (final row in rows) {
    final revision = (row['revision'] as num?)?.toInt();
    final languageCode = row['learning_language'] as String?;
    if (revision == null || languageCode == null || languageCode.isEmpty) {
      continue;
    }
    eras.add(
      ChatLanguageEra(
        revision: revision,
        languageCode: languageCode,
        startedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      ),
    );
  }
  eras.sort((a, b) => a.revision.compareTo(b.revision));
  return eras;
}

ChatLanguageEra languageEraForMessage({
  required DateTime sentAt,
  required List<ChatLanguageEra> timeline,
  required String fallbackLanguageCode,
}) {
  if (timeline.isEmpty) {
    return ChatLanguageEra(revision: 1, languageCode: fallbackLanguageCode);
  }

  var selected = timeline.firstWhere(
    (era) => era.revision == 1,
    orElse: () => timeline.first,
  );
  for (final era in timeline) {
    if (era.revision == 1) continue;
    final startedAt = era.startedAt;
    if (startedAt != null && !startedAt.isAfter(sentAt)) {
      selected = era;
    }
  }
  return selected;
}
