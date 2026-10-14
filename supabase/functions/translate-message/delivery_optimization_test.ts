import { providerMessages } from "./contract.ts";

Deno.test("participant changes retain the long stable language-pair prefix", () => {
  const request = {
    sourceLang: "auto",
    targetLang: "de",
    interfaceLang: "en",
    text: "Hello",
  };
  const participant = {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer" as const,
    viewerForm: null,
    partnerForm: null,
    tone: "informal" as const,
  };
  const first = providerMessages({ ...request, formContext: participant });
  const second = providerMessages({
    ...request,
    text: "Tomorrow",
    formContext: {
      ...participant,
      viewerName: "Carol",
      partnerName: "Dan",
      messageAuthor: "partner",
    },
    context: [{ speaker: "partner", text: "Are you coming?", isReply: true }],
  });
  const settings = first[0].content.indexOf("Request settings:");
  if (settings < 8000) {
    throw new Error("long invariant rules no longer precede settings");
  }
  if (
    first[0].content.slice(0, settings) !== second[0].content.slice(0, settings)
  ) {
    throw new Error("dynamic participant context breaks the cache prefix");
  }
  if (second[1].content !== "Tomorrow") {
    throw new Error("translated the context instead of current text");
  }
  if (
    !second[0].content.includes("partner [replied-to message]: Are you coming?")
  ) {
    throw new Error("explicit quote context lost");
  }
});
