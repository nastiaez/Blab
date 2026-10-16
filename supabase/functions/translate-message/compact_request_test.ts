import {
  COMPACT_RESPONSE_FORMAT,
  compactPlan,
  expandCompactResponse,
} from "./compact_request.ts";
import { type PreparedViewer, singleCallRequest } from "./single_call.ts";
import { COMPACT_TRANSLATION_RULES, WORD_HELP_POLICY } from "./rulebook.ts";
import { wordMetadataRepairSystemPrompt } from "./contract.ts";
const assert = (ok: unknown, message = "assertion failed") => {
  if (!ok) throw new Error(message);
};
const viewers: PreparedViewer[] = [
  {
    key: "v0",
    messageId: "m",
    sourceHash: "h",
    text: "Ik ben moe.",
    targetLang: "nl",
    interfaceLang: "en",
    formContext: {
      viewerName: "Alice",
      partnerName: "Bob",
      messageAuthor: "viewer",
      tone: "informal",
    },
  },
  {
    key: "v1",
    messageId: "m",
    sourceHash: "h",
    text: "Ik ben moe.",
    targetLang: "es",
    interfaceLang: "uk",
    formContext: {
      viewerName: "Bob",
      partnerName: "Alice",
      messageAuthor: "partner",
      tone: "informal",
    },
  },
];
Deno.test("word meanings use the same contextual rule in generation and metadata repair", () => {
  for (
    const [targetLang, interfaceLang] of [["en", "uk"], ["de", "es"], [
      "ta",
      "en",
    ]]
  ) {
    const request = singleCallRequest([{
      ...viewers[0],
      targetLang,
      interfaceLang,
    }]);
    const generation = request.messages[0].content;
    const repair = wordMetadataRepairSystemPrompt(
      targetLang,
      interfaceLang,
      "accepted sentence",
    );
    assert(generation.includes(WORD_HELP_POLICY.rule));
    assert(repair.includes(WORD_HELP_POLICY.rule));
    assert(
      WORD_HELP_POLICY.rule.includes("briefly explain its grammatical role"),
    );
    assert(
      WORD_HELP_POLICY.rule.includes("never a neighboring word's meaning"),
    );
    assert(
      WORD_HELP_POLICY.rule.includes("Keep repeated occurrences separate"),
    );
    assert(repair.includes("The sentence is immutable"));
  }
});
Deno.test("four distinct languages share one message, stable schema and compact rules", () => {
  const p = compactPlan(viewers);
  assert(p.requested.sentences.length === 4 && p.requested.help.length === 2);
  assert(p.request.messages[0].content.startsWith(COMPACT_TRANSLATION_RULES));
  assert(
    JSON.stringify(p.request.response_format) ===
      JSON.stringify(COMPACT_RESPONSE_FORMAT),
  );
  const data = JSON.parse(p.request.messages[1].content);
  assert(
    data.sender === "Alice" && data.recipient === "Bob" &&
      data.message === viewers[0].text,
  );
  assert(!("contexts" in data) && !("viewers" in data));
  assert(!p.request.messages[0].content.includes("interfaceLang"));
  const next = singleCallRequest(
    viewers.map((v) => ({ ...v, text: "Next message" })),
  );
  assert(next.messages[0].content === p.request.messages[0].content);
});
Deno.test("matching pair deduplicates sentences and word help; explanation language remains independent", () => {
  const same = viewers.map((v) => ({
    ...v,
    targetLang: "de",
    interfaceLang: "en",
  }));
  const p = compactPlan(same);
  assert(p.requested.sentences.length === 2 && p.requested.help.length === 1);
  const distinct = compactPlan([same[0], { ...same[1], interfaceLang: "uk" }]);
  assert(
    distinct.requested.sentences.length === 3 &&
      distinct.requested.help.length === 2,
  );
  const identical = compactPlan(
    same.map((v) => ({ ...v, interfaceLang: "de" })),
  );
  assert(
    identical.requested.sentences.length === 1 &&
      identical.requested.help.length === 1,
  );
});
Deno.test("same context shared across opposite viewer perspectives, quote retained and bounded", () => {
  const a = [{ speaker: "partner", text: "How are you?" }, {
    speaker: "viewer",
    text: "Earlier question",
    isReply: true,
  }];
  const b = [{ speaker: "viewer", text: "How are you?" }, {
    speaker: "partner",
    text: "Earlier question",
    isReply: true,
  }];
  const p = compactPlan([{ ...viewers[0], context: a }, {
    ...viewers[1],
    context: b,
  }]);
  const contexts = JSON.parse(p.request.messages[1].content).contexts;
  assert(Object.keys(contexts).length === 1);
  assert(contexts.c0.reply_to.message === "Earlier question");
  assert(contexts.c0.previous[0].sender === "recipient");
  const huge = compactPlan([{
    ...viewers[0],
    context: [...a, { speaker: "partner", text: "x".repeat(4000) }],
  }]);
  assert(
    huge.request.messages[1].content.includes("Earlier question") &&
      !huge.request.messages[1].content.includes("xxxx"),
  );
});
Deno.test("different historical context and tone must not coalesce language outputs", () => {
  const same = viewers.map((v) => ({
    ...v,
    targetLang: "de",
    interfaceLang: "en",
  }));
  const p = compactPlan([same[0], {
    ...same[1],
    context: [{ speaker: "viewer", text: "A different era" }],
  }]);
  assert(p.requested.sentences.length === 4 && p.requested.help.length === 2);
  const q = compactPlan([same[0], {
    ...same[1],
    formContext: { ...same[1].formContext as object, tone: "respectful" },
  }]);
  assert(q.requested.sentences.length === 4 && q.requested.help.length === 2);
});
Deno.test("shared gender alternative maps to opposite viewers without model-relative booleans", () => {
  const same = viewers.map((v) => ({
    ...v,
    targetLang: "es",
    interfaceLang: "en",
  }));
  const p = compactPlan(same);
  const raw = {
    sentences: p.requested.sentences.map((s) => ({
      id: s.id,
      text: s.language === "Spanish" ? "Estás cansada." : "You are tired.",
      sourceLang: "en",
      mode: "translation",
      confidence: null,
      forms: s.language === "Spanish"
        ? {
          before: "Estás ",
          feminine: "cansada",
          masculine: "cansado",
          after: ".",
          subject: "recipient",
          suggestedForm: "masculine",
        }
        : null,
    })),
    help: p.requested.help.map((h) => ({
      id: h.id,
      tokens: [],
      explanation: null,
      feminineTokens: [],
      masculineTokens: [],
    })),
  };
  const r = expandCompactResponse(raw, same, p);
  assert(
    r.v0.formAlternatives.subjectIsViewer === false &&
      r.v1.formAlternatives.subjectIsViewer === true,
  );
  assert(
    r.v0.formAlternatives.subjectName === "Bob" &&
      r.v1.formAlternatives.subjectName === "Bob",
  );
  r.v0.tokens.push({ text: "mutation" });
  assert(r.v1.tokens.length === 0, "independent mutable parser results");
  for (
    const bad of [{ ...raw, sentences: [raw.sentences[0], raw.sentences[0]] }, {
      ...raw,
      help: [],
    }]
  ) {
    let failed = false;
    try {
      expandCompactResponse(bad, same, p);
    } catch {
      failed = true;
    }
    assert(failed);
  }
});
Deno.test("all supported target/known pairs remain dynamic, no UI or private forms sent", () => {
  const languages = [
    "en",
    "nl",
    "fr",
    "de",
    "hi",
    "it",
    "pt",
    "es",
    "ta",
    "tr",
    "uk",
  ];
  for (const targetLang of languages) {
    for (const interfaceLang of languages) {
      const p = compactPlan([{
        ...viewers[0],
        targetLang,
        interfaceLang,
        formContext: {
          ...viewers[0].formContext as object,
          viewerForm: "masculine",
          interfaceLanguage: "SECRET_UI",
        },
      }]);
      assert(
        p.requested.sentences.length === (targetLang === interfaceLang ? 1 : 2),
      );
      assert(p.requested.help.length === 1);
      assert(
        !JSON.stringify(p.request).includes("SECRET_UI") &&
          !JSON.stringify(p.request).includes("viewerForm"),
      );
    }
  }
});

Deno.test("same-language authored gender is not normalized into a correction", () => {
  const vs = [{
    ...viewers[1],
    text: "Estoy cansado.",
    targetLang: "es",
    interfaceLang: "uk",
  }];
  const p = compactPlan(vs);
  const raw = {
    sentences: p.requested.sentences.map((s) => ({
      id: s.id,
      text: s.language === "Spanish" ? "Estoy cansado." : "Я втомлений.",
      mode: s.language === "Spanish" ? "none" : "translation",
      sourceLang: "es",
      confidence: null,
      forms: {
        before: "Estoy ",
        feminine: "cansada",
        masculine: "cansado",
        after: ".",
        subject: "sender",
        suggestedForm: "masculine",
      },
    })),
    help: p.requested.help.map((h) => ({
      id: h.id,
      explanation: null,
      tokens: [],
      feminineTokens: [],
      masculineTokens: [],
    })),
  };
  const r = expandCompactResponse(raw, vs, p);
  assert(
    r.v1.translation === "Estoy cansado." && r.v1.formAlternatives === null,
  );
});

Deno.test("reuse complete matching form tokens instead of rejecting omitted duplicate base metadata", () => {
  const vs = [{
    ...viewers[0],
    text: "I am tired",
    targetLang: "es",
    interfaceLang: "en",
  }];
  const p = compactPlan(vs);
  const tokens = [{
    text: "cansada",
    gloss: "tired",
    roman: null,
    isContent: true,
  }];
  const raw = {
    sentences: p.requested.sentences.map((s) => ({
      id: s.id,
      text: s.language === "Spanish" ? "cansada" : "tired",
      mode: "translation",
      sourceLang: "en",
      confidence: null,
      forms: null,
    })),
    help: p.requested.help.map((h) => ({
      id: h.id,
      explanation: null,
      tokens: [],
      feminineTokens: tokens,
      masculineTokens: [],
    })),
  };
  assert(expandCompactResponse(raw, vs, p).v0.tokens[0].text === "cansada");
  raw.help[0].feminineTokens = [{ ...tokens[0], text: "unrelated" }];
  assert(expandCompactResponse(raw, vs, p).v0.tokens.length === 0);
});
