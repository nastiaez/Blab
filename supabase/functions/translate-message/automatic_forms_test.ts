import {
  directSubjectRole,
  formAuditSystemPrompt,
  type FormParticipantContext,
  missingFormAlternativesNeedsAudit,
  normalizeFormSubject,
  systemPrompt,
} from "./contract.ts";
function check(ok: boolean) {
  if (!ok) throw new Error("assertion failed");
}
function checkRole(
  text: string,
  sourceLang: string,
  expected: "author" | "recipient" | null,
) {
  const actual = directSubjectRole(text, sourceLang, ["Bob", "Alice"]);
  if (actual !== expected) {
    throw new Error(
      `${JSON.stringify(text)}: expected ${expected}, got ${actual}`,
    );
  }
}
const context: FormParticipantContext = {
  viewerName: "Bob",
  partnerName: "Alice",
  messageAuthor: "partner",
  viewerForm: null,
  partnerForm: null,
  tone: "informal",
};
const directRoleCases = [
  {
    language: "English",
    code: "en",
    author: [
      "I cooked dinner.",
      "I made dinner.",
      "I went home.",
      "Did I arrive early?",
      "I'm ready.",
    ],
    recipient: [
      "You cooked dinner.",
      "You went home.",
      "Did you arrive early?",
      "You're ready.",
    ],
  },
  {
    language: "German",
    code: "de",
    author: [
      "Ich bin müde.",
      "Ich habe gekocht.",
      "Ich kam früh.",
      "Ich koche Abendessen.",
    ],
    recipient: [
      "Du bist müde.",
      "Du hast gekocht.",
      "Du kamst früh.",
      "Du gehst nach Hause.",
    ],
  },
  {
    language: "Spanish",
    code: "es",
    author: [
      "Yo estoy cansada.",
      "Estoy cansada.",
      "Llegué temprano.",
      "He cocinado.",
    ],
    recipient: [
      "Tú estás cansado.",
      "Estás cansado.",
      "Llegaste temprano.",
      "Has cocinado.",
    ],
  },
  {
    language: "French",
    code: "fr",
    author: ["Je suis fatiguée.", "J'ai cuisiné.", "Je suis arrivée tôt."],
    recipient: ["Tu es fatigué.", "Tu as cuisiné.", "Tu es arrivé tôt."],
  },
  {
    language: "Ukrainian",
    code: "uk",
    author: ["Я втомилася.", "Я приготувала вечерю.", "Я прийшов рано."],
    recipient: ["Ти втомився.", "Ти приготував вечерю.", "Ти прийшла рано."],
  },
  {
    language: "Hindi",
    code: "hi",
    author: ["मैं थक गया हूँ।", "मैं घर गया।", "मैंने खाना बनाया।"],
    recipient: ["तुम थक गए हो।", "तुम घर गए।", "आपने खाना बनाया।"],
  },
  {
    language: "Dutch",
    code: "nl",
    author: ["Ik ben moe.", "Ik heb gekookt.", "Ik kwam vroeg."],
    recipient: ["Jij bent moe.", "Je hebt gekookt.", "Jij kwam vroeg."],
  },
  {
    language: "Italian",
    code: "it",
    author: [
      "Io sono stanco.",
      "Sono arrivata presto.",
      "Ho cucinato la cena.",
    ],
    recipient: ["Tu sei stanco.", "Sei arrivato presto.", "Hai cucinato."],
  },
  {
    language: "Portuguese",
    code: "pt",
    author: [
      "Eu estou cansado.",
      "Estou cansado.",
      "Fui para casa.",
      "Cheguei cedo.",
    ],
    recipient: [
      "Você está cansado.",
      "Estás cansado.",
      "Tu foste para casa.",
      "Chegaste cedo.",
    ],
  },
  {
    language: "Tamil",
    code: "ta",
    author: [
      "நான் சோர்வாக இருக்கிறேன்.",
      "சோர்வாக இருக்கிறேன்.",
      "நான் வீட்டிற்கு சென்றேன்.",
      "வீட்டிற்கு சென்றேன்.",
    ],
    recipient: [
      "நீ சோர்வாக இருக்கிறாய்.",
      "சோர்வாக இருக்கிறாய்.",
      "நீ வீட்டிற்கு சென்றாய்.",
      "வீட்டிற்கு சென்றாய்.",
    ],
  },
  {
    language: "Turkish",
    code: "tr",
    author: ["Ben yorgunum.", "Yorgunum.", "Eve gittim.", "Erken geldim."],
    recipient: [
      "Sen yorgunsun.",
      "Yorgunsun.",
      "Eve gittin.",
      "Erken geldin.",
    ],
  },
] as const;

for (const cases of directRoleCases) {
  Deno.test(`${cases.language} direct author maps to stable author role`, () => {
    for (const text of cases.author) checkRole(text, cases.code, "author");
  });
  Deno.test(
    `${cases.language} direct recipient maps to stable recipient role`,
    () => {
      for (const text of cases.recipient) {
        checkRole(text, cases.code, "recipient");
      }
    },
  );
}
Deno.test("direct role recognition is isolated to the detected language", () => {
  checkRole("Je werkt vandaag.", "nl", "recipient");
  checkRole("Je travaille aujourd'hui.", "fr", "author");
  checkRole("He was tired.", "en", null);
  checkRole("He cocinado.", "es", "author");
  checkRole("Era feliz.", "es", null);
  checkRole("Era feliz.", "pt", null);
  checkRole("I went home.", "auto", null);
  checkRole("I went home.", "other", null);
  const normalized = normalizeFormSubject(
    {
      before: "",
      feminine: "werkte",
      masculine: "werkte",
      after: " vandaag.",
      subjectName: "wrong",
      subjectIsViewer: false,
      suggestedForm: "feminine",
      feminineTokens: [],
      masculineTokens: [],
    },
    context,
    "Je werkt vandaag.",
    "nl",
  );
  check(
    normalized.subjectRole === "recipient" && normalized.subjectIsViewer &&
      normalized.subjectName === "Bob",
  );
});
Deno.test("wrong incoming you metadata is rebound to Bob and stable recipient role", () => {
  const a = normalizeFormSubject(
    {
      before: "Ти ",
      feminine: "ходила",
      masculine: "ходив",
      after: " вчора?",
      subjectName: "Alice",
      subjectIsViewer: false,
      suggestedForm: "masculine",
      feminineTokens: [],
      masculineTokens: [],
    },
    context,
    "Did you go yesterday?",
    "en",
  );
  check(
    a.subjectIsViewer && a.subjectName === "Bob" &&
      a.subjectRole === "recipient",
  );
  const b = normalizeFormSubject(
    { ...a, subjectIsViewer: true },
    {
      ...context,
      viewerName: "Alice",
      partnerName: "Bob",
      messageAuthor: "viewer",
    },
    "Did you go yesterday?",
    "en",
  );
  check(
    !b.subjectIsViewer && b.subjectName === "Bob" &&
      b.subjectRole === "recipient",
  );
});
Deno.test("existing alternatives require ownership audit too", () => {
  const r: any = {
    mode: "translation",
    formAlternatives: {
      before: "Ти ",
      feminine: "ходила",
      masculine: "ходив",
      after: "?",
      subjectName: "Alice",
      subjectIsViewer: false,
    },
  };
  check(missingFormAlternativesNeedsAudit(r, "uk", context, 0));
});

Deno.test("shared provider prompts are invariant to private saved forms", () => {
  const privateContext: FormParticipantContext = {
    ...context,
    viewerForm: "masculine",
    partnerForm: "feminine",
  };
  const otherPrivateContext: FormParticipantContext = {
    ...context,
    viewerForm: "feminine",
    partnerForm: "masculine",
  };
  check(
    systemPrompt("en", "uk", "en", privateContext) ===
      systemPrompt("en", "uk", "en", otherPrivateContext),
  );
  check(
    systemPrompt("en", "uk", "en", privateContext) ===
      systemPrompt("en", "uk", "en", context),
  );
  check(
    formAuditSystemPrompt("en", "uk", "en", privateContext) ===
      formAuditSystemPrompt("en", "uk", "en", otherPrivateContext),
  );
  check(
    formAuditSystemPrompt("en", "uk", "en", privateContext) ===
      formAuditSystemPrompt("en", "uk", "en", context),
  );
});

Deno.test("normalized shared alternatives preserve name-derived provider suggestions", () => {
  const alternative = {
    before: "",
    feminine: "втомилася",
    masculine: "втомився",
    after: ".",
    subjectName: "wrong",
    subjectIsViewer: true,
    suggestedForm: "masculine" as const,
    feminineTokens: [],
    masculineTokens: [],
  };
  const unset = normalizeFormSubject(
    alternative,
    context,
    "I cooked dinner.",
    "en",
  );
  const privatelySet = normalizeFormSubject(
    alternative,
    {
      ...context,
      viewerForm: "feminine",
      partnerForm: "masculine",
    },
    "I cooked dinner.",
    "en",
  );
  check(JSON.stringify(unset) === JSON.stringify(privatelySet));
  check(unset.subjectName === "Alice" && unset.suggestedForm === "masculine");
  const oppositeViewer = normalizeFormSubject(
    unset,
    {
      ...context,
      viewerName: "Alice",
      partnerName: "Bob",
      messageAuthor: "viewer",
    },
    "I cooked dinner.",
    "en",
  );
  check(
    oppositeViewer.subjectRole === "author" &&
      oppositeViewer.subjectIsViewer &&
      oppositeViewer.subjectName === "Alice" &&
      oppositeViewer.suggestedForm === "masculine",
  );

  const recipient = normalizeFormSubject(
    { ...alternative, suggestedForm: "feminine" },
    context,
    "You cooked dinner.",
    "en",
  );
  check(
    recipient.subjectName === "Bob" && recipient.suggestedForm === "feminine",
  );
  const fallback = normalizeFormSubject(
    { ...alternative, suggestedForm: undefined },
    context,
    "I cooked dinner.",
    "en",
  );
  check(fallback.suggestedForm === "feminine");
});

Deno.test("embedded and named affected people remain audit-owned", () => {
  for (
    const [sourceLang, text] of [
      ["en", "I think Alice was tired."],
      ["en", "You made Bob happy."],
      ["en", "I told her yesterday."],
      ["en", "I found bob exhausted."],
      ["en", "You saw alice exhausted."],
      ["en", "You said I was tired."],
      ["en", "Alice said “you were tired”."],
      ["en", "“I was tired,” Alice said."],
      ["nl", "Ik zei dat jij moe was."],
      ["it", 'Alice ha detto: "Tu sei stanco".'],
      ["pt", "Eu disse que você estava cansado."],
      ["ta", "நான் சொன்னேன் நீ சோர்வாக இருக்கிறாய்."],
      ["hi", "मैंने सीमा को देखा।"],
      ["ta", "நான் அலிஸை பார்த்தேன்."],
      ["ta", "நான் அவளை பார்த்தேன்."],
      ["tr", 'Alice "Yorgunum" dedi.'],
      ["en", "I cooked and you cleaned."],
      ["de", "Ich kochte und du hast geputzt."],
      ["es", "Yo cociné y tú limpiaste."],
      ["fr", "Je suis partie parce qu'elle est arrivée."],
      ["uk", "Я прийшла, а ти пішов."],
      ["hi", "मैं गया और तुम रुके।"],
      ["nl", "Ik kookte terwijl jij schoonmaakte."],
      ["it", "Sono arrivata perché lei ha chiamato."],
      ["pt", "Eu cheguei quando ela saiu."],
      ["ta", "நான் சென்றேன், நீ தங்கினாய்."],
      ["tr", "Eve gittim ama sen kaldın."],
      ["en", "She went home."],
      ["de", "Alice war müde."],
      ["es", "Ella llegó temprano."],
      ["uk", "Вона прийшла рано."],
      ["ta", "அவள் வீட்டிற்கு சென்றாள்."],
      ["tr", "O eve gitti."],
      ["it", "Sono qui."],
      ["nl", "Je collega komt."],
      ["pt", "Rei cansado."],
      ["es", "Café caliente."],
    ] as const
  ) {
    checkRole(text, sourceLang, null);
  }
});
