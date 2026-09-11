import {
  directSubjectRole,
  type FormParticipantContext,
  missingFormAlternativesNeedsAudit,
  normalizeFormSubject,
} from "./contract.ts";
function check(ok: boolean) {
  if (!ok) throw new Error("assertion failed");
}
const context: FormParticipantContext = {
  viewerName: "Bob",
  partnerName: "Alice",
  messageAuthor: "partner",
  viewerForm: null,
  partnerForm: null,
  tone: "informal",
};
Deno.test("direct subjects map independently from sender and name", () => {
  check(
    directSubjectRole("Did you go to the supermarket yesterday?") ===
      "recipient",
  );
  check(directSubjectRole("I was tired yesterday.") === "author");
  check(directSubjectRole("You said I was tired.") === null);
  check(directSubjectRole("Alice said “you were tired”.") === null);
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
    },
    context,
    "Did you go yesterday?",
  );
  check(
    a.subjectIsViewer && a.subjectName === "Bob" &&
      a.subjectRole === "recipient",
  );
  const b = normalizeFormSubject({ ...a, subjectIsViewer: true }, {
    ...context,
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer",
  }, "Did you go yesterday?");
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

Deno.test("embedded and named affected people remain audit-owned", () => {
  for (
    const text of [
      "I think Alice was tired.",
      "You made Bob happy.",
      "I told her yesterday.",
      "I found bob exhausted.",
      "You saw alice exhausted.",
    ]
  ) {
    if (directSubjectRole(text) !== null) {
      throw new Error("Unsafe ownership override: " + text);
    }
  }
});
