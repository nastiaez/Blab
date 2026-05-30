import '../models/message.dart';
import '../models/message_token.dart';

/// Seeded mock conversation for the dev preview. Only the Aswin chat (`id ==
/// 'aswin'`) has messages; everything else returns an empty list until
/// Step 2.2 wires real persistence.
///
/// Reference: prototype.html § Phone 3 (lines ~1079-1283).
List<Message> mockMessagesFor(String chatId) {
  if (chatId != 'aswin') return const <Message>[];

  final DateTime today = DateTime.now();
  DateTime at(int hour, int minute) =>
      DateTime(today.year, today.month, today.day, hour, minute);

  return [
    Message(
      id: 'm1',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'காலை! எப்படி இருக்கீங்க?',
      translation: 'Good morning! How are you?',
      tokens: const [
        MessageToken(text: 'காலை', romanization: 'kālai', english: 'morning'),
        MessageToken(text: '! ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', english: 'how'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'இருக்கீங்க',
            romanization: 'irukkīṅka',
            english: 'are you'),
        MessageToken(text: '?', isContent: false),
      ],
      sentAt: at(9, 30),
      status: MessageStatus.delivered,
    ),
    Message(
      id: 'm2',
      chatId: 'aswin',
      isOutgoing: true,
      originalText: "I'm good, thanks! How about you?",
      translation: 'நான் நன்றாக இருக்கிறேன், நன்றி! நீங்கள் எப்படி?',
      tokens: const [
        MessageToken(text: 'நான்', romanization: 'nāṉ', english: 'I'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'நன்றாக', romanization: 'naṉṟāka', english: 'well'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'இருக்கிறேன்',
            romanization: 'irukkiṟēṉ',
            english: 'am'),
        MessageToken(text: ', ', isContent: false),
        MessageToken(text: 'நன்றி', romanization: 'naṉṟi', english: 'thanks'),
        MessageToken(text: '! ', isContent: false),
        MessageToken(text: 'நீங்கள்', romanization: 'nīṅkaḷ', english: 'you'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', english: 'how'),
        MessageToken(text: '?', isContent: false),
      ],
      sentAt: at(9, 31),
      status: MessageStatus.read,
    ),
    Message(
      id: 'm3',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'நானும் நன்றாக இருக்கிறேன். இன்று என்ன செய்கிறீர்கள்?',
      translation: "I'm good too. What are you doing today?",
      tokens: const [
        MessageToken(
            text: 'நானும்', romanization: 'nāṉum', english: 'I also'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'நன்றாக', romanization: 'naṉṟāka', english: 'well'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'இருக்கிறேன்',
            romanization: 'irukkiṟēṉ',
            english: 'I am'),
        MessageToken(text: '. ', isContent: false),
        MessageToken(text: 'இன்று', romanization: 'iṉṟu', english: 'today'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'என்ன', romanization: 'eṉṉa', english: 'what'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'செய்கிறீர்கள்',
            romanization: 'seykiṟīrkaḷ',
            english: 'are you doing'),
        MessageToken(text: '?', isContent: false),
      ],
      sentAt: at(9, 33),
      status: MessageStatus.delivered,
    ),
    Message(
      id: 'm4',
      chatId: 'aswin',
      isOutgoing: true,
      originalText: "Drinking coffee and chatting with you ☕",
      translation: 'காபி குடித்துக்கொண்டு உங்களுடன் பேசுகிறேன் ☕',
      tokens: const [
        MessageToken(text: 'காபி', romanization: 'kāpi', english: 'coffee'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'குடித்துக்கொண்டு',
            romanization: 'kuṭittukkoṇṭu',
            english: 'drinking'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'உங்களுடன்',
            romanization: 'uṅkaḷuṭaṉ',
            english: 'with you'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(
            text: 'பேசுகிறேன்',
            romanization: 'pēsukiṟēṉ',
            english: 'am chatting'),
        MessageToken(text: ' ☕', isContent: false),
      ],
      sentAt: at(9, 38),
      status: MessageStatus.read,
    ),
    Message(
      id: 'm5',
      chatId: 'aswin',
      isOutgoing: true,
      originalText: 'How do you say "coffee" in Tamil?',
      translation: 'தமிழில் "coffee" என்று எப்படி சொல்வது?',
      tokens: const [
        MessageToken(text: 'தமிழில்', romanization: 'tamiḻil', english: 'in Tamil'),
        MessageToken(text: ' "coffee" ', isContent: false),
        MessageToken(text: 'என்று', romanization: 'eṉṟu', english: 'as'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எப்படி', romanization: 'eppadi', english: 'how'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'சொல்வது', romanization: 'solvatu', english: 'to say'),
        MessageToken(text: '?', isContent: false),
      ],
      sentAt: at(9, 38),
      status: MessageStatus.read,
    ),
    Message(
      id: 'm6',
      chatId: 'aswin',
      isOutgoing: false,
      originalText: 'காபி!',
      translation: 'Coffee!',
      tokens: const [
        MessageToken(text: 'காபி', romanization: 'kāpi', english: 'coffee'),
        MessageToken(text: '!', isContent: false),
      ],
      sentAt: at(9, 40),
      status: MessageStatus.delivered,
    ),
    Message(
      id: 'm7',
      chatId: 'aswin',
      isOutgoing: true,
      originalText: 'Easy to remember 😄',
      translation: 'நினைவில் வைக்க எளிது 😄',
      tokens: const [
        MessageToken(text: 'நினைவில்', romanization: 'niṉaivil', english: 'in memory'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'வைக்க', romanization: 'vaikka', english: 'to keep'),
        MessageToken(text: ' ', isContent: false),
        MessageToken(text: 'எளிது', romanization: 'eḷitu', english: 'easy'),
        MessageToken(text: ' 😄', isContent: false),
      ],
      sentAt: at(9, 41),
      status: MessageStatus.read,
    ),
  ];
}
