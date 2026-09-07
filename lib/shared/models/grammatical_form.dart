enum GrammaticalForm { feminine, masculine }

extension GrammaticalFormWire on GrammaticalForm {
  String get wire => name;

  String get label => switch (this) {
    GrammaticalForm.feminine => 'Feminine',
    GrammaticalForm.masculine => 'Masculine',
  };
}

GrammaticalForm? grammaticalFormFromWire(String? value) => switch (value) {
  'feminine' => GrammaticalForm.feminine,
  'masculine' => GrammaticalForm.masculine,
  _ => null,
};

enum ConversationTone { informal, respectful }

extension ConversationToneWire on ConversationTone {
  String get wire => name;

  String get label => switch (this) {
    ConversationTone.informal => 'Informal',
    ConversationTone.respectful => 'Respectful',
  };
}

ConversationTone conversationToneFromWire(String? value) => value == 'respectful'
    ? ConversationTone.respectful
    : ConversationTone.informal;
