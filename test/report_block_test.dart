import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/chat/widgets/report_sheet.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/state/chat_list_state.dart';

BlabLanguage _lang(String code) =>
    kBlabLanguages.firstWhere((l) => l.code == code);

Chat _chat(String id, String partnerId) => Chat(
  id: id,
  partnerId: partnerId,
  partnerName: 'P$id',
  partnerInitial: 'P',
  learningLanguage: _lang('ta'),
  mode: ChatMode.practice,
  partnerNativeLanguage: _lang('ta'),
  partnerLearningLanguage: _lang('uk'),
  lastMessage: 'hi',
  lastMessageTranslation: '',
  timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
  unreadCount: 0,
);

void main() {
  test('filterBlockedChats hides chats whose partner is blocked', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterBlockedChats(chats, {'u2'}).map((c) => c.id), ['a']);
  });

  test('filterBlockedChats with an empty set shows all chats', () {
    final chats = [_chat('a', 'u1'), _chat('b', 'u2')];
    expect(filterBlockedChats(chats, const {}).map((c) => c.id), ['a', 'b']);
  });

  test('filterBlockedChats keeps chats that have no partner id', () {
    final mock = Chat(
      id: 'm',
      partnerName: 'M',
      partnerInitial: 'M',
      learningLanguage: _lang('ta'),
      mode: ChatMode.practice,
      partnerNativeLanguage: _lang('ta'),
      partnerLearningLanguage: _lang('uk'),
      lastMessage: '',
      lastMessageTranslation: '',
      timestamp: DateTime.parse('2026-06-09T00:00:00Z'),
      unreadCount: 0,
    );
    expect(filterBlockedChats([mock], {'x'}).map((c) => c.id), ['m']);
  });

  test('report reasons map to stable wire values', () {
    expect(ReportReason.childSafety.wire, 'child_safety');
    expect(ReportReason.harassment.wire, 'harassment');
    // Every reason has a non-empty wire + label.
    for (final r in ReportReason.values) {
      expect(r.wire, isNotEmpty);
      expect(r.label, isNotEmpty);
    }
  });
}
