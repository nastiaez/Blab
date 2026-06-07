import '../models/chat.dart';
import '../models/message.dart';
import '../models/message_token.dart';
import 'languages.dart';

/// Curated demo data used when [portfolioModeProvider] is on. Tamil ↔ English
/// exchange between the local user (Nastia, learning Tamil) and her partner
/// Aswin (learning English). Designed for portfolio screenshots: balanced
/// bubble direction, rich token glosses for the word popup, believable
/// "today, this morning" timestamps.

final BlabLanguage _tamil =
    kBlabLanguages.firstWhere((l) => l.code == 'ta');
final BlabLanguage _english =
    kBlabLanguages.firstWhere((l) => l.code == 'en');

const String kPortfolioChatId = 'portfolio-aswin';

/// Today at HH:mm local time.
DateTime _at(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

final Chat _aswin = Chat(
  id: kPortfolioChatId,
  partnerName: 'Aswin',
  partnerInitial: 'A',
  learningLanguage: _tamil,
  partnerNativeLanguage: _tamil,
  partnerLearningLanguage: _english,
  lastMessage: 'ஆம், மிகவும் பிடிக்கிறது!',
  lastMessageTranslation: 'Yes, I love it!',
  timestamp: _at(9, 38),
  unreadCount: 0,
  startedAt: DateTime.now().subtract(const Duration(days: 12)),
);

List<Chat> portfolioChats() => [_aswin];

// ─────────────────────── token helpers ───────────────────────────────────

MessageToken _t(String text, String english, String roman) => MessageToken(
      text: text,
      english: english,
      romanization: roman,
    );

MessageToken _punct(String s) =>
    MessageToken(text: s, isContent: false);

/// Per-chat message stream. Outgoing messages = current user (Nastia);
/// incoming = Aswin.
List<Message> portfolioMessages(String chatId) {
  if (chatId != kPortfolioChatId) return const [];

  return [
    // ── 9:30 Aswin
    Message(
      id: 'p-1',
      chatId: kPortfolioChatId,
      isOutgoing: false,
      originalText: 'காலை வணக்கம்! எப்படி இருக்கீங்க?',
      translation: 'Good morning! How are you?',
      sentAt: _at(9, 30),
      status: MessageStatus.delivered,
      tokens: [
        _t('காலை', 'Morning', 'Kālai'),
        _t('வணக்கம்', 'Greetings', 'Vaṇakkam'),
        _punct('! '),
        _t('எப்படி', 'How', 'Eppadi'),
        _t('இருக்கீங்க', 'Are you', 'Irukkīṅka'),
        _punct('?'),
      ],
    ),
    // ── 9:31 Nastia (read)
    Message(
      id: 'p-2',
      chatId: kPortfolioChatId,
      isOutgoing: true,
      originalText: "I'm good, thanks! How about you?",
      translation: 'நன்றாக இருக்கிறேன், நன்றி! நீங்கள்?',
      sentAt: _at(9, 31),
      status: MessageStatus.read,
      tokens: [
        _t('நன்றாக', 'Well / Fine', 'Naṉṟāka'),
        _t('இருக்கிறேன்', 'I am', 'Irukkiṟēn'),
        _punct(', '),
        _t('நன்றி', 'Thank you', 'Naṉṟi'),
        _punct('! '),
        _t('நீங்கள்', 'You', 'Nīṅkaḷ'),
        _punct('?'),
      ],
    ),
    // ── 9:33 Aswin
    Message(
      id: 'p-3',
      chatId: kPortfolioChatId,
      isOutgoing: false,
      originalText: 'நானும் நன்றாக. இன்று என்ன செய்கிறீர்கள்?',
      translation: "I'm well too. What are you doing today?",
      sentAt: _at(9, 33),
      status: MessageStatus.delivered,
      tokens: [
        _t('நானும்', 'I also', 'Nāṉum'),
        _t('நன்றாக', 'Well', 'Naṉṟāka'),
        _punct('. '),
        _t('இன்று', 'Today', 'Indṟu'),
        _t('என்ன', 'What', 'Eṉṉa'),
        _t('செய்கிறீர்கள்', 'Doing', 'Seykiṟīrkaḷ'),
        _punct('?'),
      ],
    ),
    // ── 9:34 Nastia (read)
    Message(
      id: 'p-4',
      chatId: kPortfolioChatId,
      isOutgoing: true,
      originalText: "Having coffee and chatting with you ☕",
      translation: 'காபி குடித்துக்கொண்டு உங்களுடன் பேசுகிறேன் ☕',
      sentAt: _at(9, 34),
      status: MessageStatus.read,
      tokens: [
        _t('காபி', 'Coffee', 'Kāpi'),
        _t('குடித்துக்கொண்டு', 'Drinking', 'Kuṭittukkoṇṭu'),
        _t('உங்களுடன்', 'With you', 'Uṅkaḷuṭaṉ'),
        _t('பேசுகிறேன்', 'Talking', 'Pēsukiṟēṉ'),
        _punct(' ☕'),
      ],
    ),
    // ── 9:36 Aswin (two in a row → grouped)
    Message(
      id: 'p-5',
      chatId: kPortfolioChatId,
      isOutgoing: false,
      originalText: 'அது அழகாக இருக்கிறது 😊',
      translation: 'That sounds lovely 😊',
      sentAt: _at(9, 36),
      status: MessageStatus.delivered,
      tokens: [
        _t('அது', 'That', 'Adu'),
        _t('அழகாக', 'Beautiful', 'Aḻakāka'),
        _t('இருக்கிறது', 'Is', 'Irukkiṟadu'),
        _punct(' 😊'),
      ],
    ),
    Message(
      id: 'p-6',
      chatId: kPortfolioChatId,
      isOutgoing: false,
      originalText: 'உங்களுக்கு தமிழ் பிடிக்குமா?',
      translation: 'Do you like Tamil?',
      sentAt: _at(9, 36),
      status: MessageStatus.delivered,
      tokens: [
        _t('உங்களுக்கு', 'To you', 'Uṅkaḷukku'),
        _t('தமிழ்', 'Tamil', 'Tamiḻ'),
        _t('பிடிக்குமா', 'Do you like', 'Piṭikkumā'),
        _punct('?'),
      ],
    ),
    // ── 9:38 Nastia (read)
    Message(
      id: 'p-7',
      chatId: kPortfolioChatId,
      isOutgoing: true,
      originalText: 'Yes, I love it! 💛',
      translation: 'ஆம், மிகவும் பிடிக்கிறது! 💛',
      sentAt: _at(9, 38),
      status: MessageStatus.read,
      tokens: [
        _t('ஆம்', 'Yes', 'Ām'),
        _punct(', '),
        _t('மிகவும்', 'Very much', 'Mikavum'),
        _t('பிடிக்கிறது', 'Like', 'Piṭikkiṟadu'),
        _punct('! 💛'),
      ],
    ),
  ];
}
