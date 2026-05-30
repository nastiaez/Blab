import '../models/chat.dart';
import 'languages.dart';

final BlabLanguage _tamil = kBlabLanguages.firstWhere((l) => l.code == 'ta');
final BlabLanguage _spanish = kBlabLanguages.firstWhere((l) => l.code == 'es');
final BlabLanguage _german = kBlabLanguages.firstWhere((l) => l.code == 'de');
final BlabLanguage _ukrainian =
    kBlabLanguages.firstWhere((l) => l.code == 'uk');

final List<Chat> kMockChats = [
  Chat(
    id: 'aswin',
    partnerName: 'Aswin',
    partnerInitial: 'A',
    learningLanguage: _tamil,
    partnerNativeLanguage: _tamil,
    partnerLearningLanguage: _ukrainian,
    lastMessage: 'எப்படி இருக்கிறீர்கள்?',
    lastMessageTranslation: 'How are you?',
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    unreadCount: 2,
    startedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Chat(
    id: 'maria',
    partnerName: 'María',
    partnerInitial: 'M',
    learningLanguage: _spanish,
    partnerNativeLanguage: _spanish,
    partnerLearningLanguage: _ukrainian,
    lastMessage: '¡Hasta mañana!',
    lastMessageTranslation: 'See you tomorrow!',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    unreadCount: 0,
    startedAt: DateTime.now().subtract(const Duration(days: 9)),
  ),
  Chat(
    id: 'lukas',
    partnerName: 'Lukas',
    partnerInitial: 'L',
    learningLanguage: _german,
    partnerNativeLanguage: _german,
    partnerLearningLanguage: _ukrainian,
    lastMessage: 'Bis später',
    lastMessageTranslation: 'Talk later',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    unreadCount: 0,
    startedAt: DateTime.now().subtract(const Duration(days: 21)),
  ),
];

/// Aswin's POV chat list — after he accepts Nastia's invite, he sees just one
/// chat waiting for him with invite-state styling. PRD US-026.
final List<Chat> kAswinMockChats = [
  Chat(
    id: 'nastia',
    partnerName: 'Nastia',
    partnerInitial: 'N',
    learningLanguage: _ukrainian,
    partnerNativeLanguage: _ukrainian,
    partnerLearningLanguage: _tamil,
    lastMessage: '',
    lastMessageTranslation: '',
    timestamp: DateTime.now(),
    unreadCount: 0,
    isNewInvite: true,
    startedAt: DateTime.now(),
  ),
];

/// Look up a chat by id across both POV seed lists. Used by the chat screen
/// (US-027/US-028) so it can resolve `nastia` even when the user is in
/// Aswin-mode.
Chat? findChat(String id) {
  for (final c in kMockChats) {
    if (c.id == id) return c;
  }
  for (final c in kAswinMockChats) {
    if (c.id == id) return c;
  }
  return null;
}

