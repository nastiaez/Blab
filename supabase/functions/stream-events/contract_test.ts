import {
  retainedStreamEvent,
  streamBodyHash,
  verifyStreamSignature,
} from "./contract.ts";
const enc = new TextEncoder();
const fixture = {
  type: "message.new",
  cid: "blab:00000000-0000-4000-8000-000000000901",
  created_at: "2026-10-14T09:00:00Z",
  message: {
    id: "00000000-0000-4000-8000-000000000902",
    text: "private",
    user: { id: "private-user" },
  },
  request_info: { ip: "private-ip" },
};
Deno.test("signature verifies exact raw bytes, not reserialized JSON", async () => {
  const body = enc.encode(JSON.stringify(fixture));
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode("fixture-secret"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const bytes = new Uint8Array(await crypto.subtle.sign("HMAC", key, body));
  const sig = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join(
    "",
  );
  if (!await verifyStreamSignature(body, sig, "fixture-secret")) {
    throw new Error("valid signature rejected");
  }
  for (
    const [input, signature, secret] of [
      [enc.encode(JSON.stringify(fixture, null, 2)), sig, "fixture-secret"],
      [body, sig, "wrong"],
      [body, "invalid", "fixture-secret"],
      [body, null, "fixture-secret"],
    ] as const
  ) {
    if (await verifyStreamSignature(input, signature, secret)) {
      throw new Error("invalid signature accepted");
    }
  }
});
Deno.test("queue retains reconciliation identity, not chat text, profiles or network metadata", () => {
  const event = retainedStreamEvent(fixture);
  if (event === null || /private/.test(JSON.stringify(event))) {
    throw new Error("unnecessary personal data retained");
  }
  for (
    const change of [{ type: "typing.start" }, { cid: "messaging:unrelated" }, {
      cid: "blab:invalid",
    }]
  ) {
    if (retainedStreamEvent({ ...fixture, ...change }) !== null) {
      throw new Error("unrelated event accepted");
    }
  }
});
Deno.test("body hash deduplicates replays even if an unsigned delivery header changes", async () => {
  const body = enc.encode(JSON.stringify(fixture));
  if (await streamBodyHash(body) !== await streamBodyHash(body)) {
    throw new Error("unstable event key");
  }
  if (
    await streamBodyHash(body) === await streamBodyHash(enc.encode("changed"))
  ) throw new Error("changed body deduplicated");
});
Deno.test("reaction events reconcile canonical activity without retaining reaction payloads", () => {
  for (const type of ["reaction.new", "reaction.updated", "reaction.deleted"]) {
    const event = retainedStreamEvent({
      ...fixture,
      type,
      reaction: { type: "private-emoji", user: { id: "private-user" } },
    });
    if (
      event?.type !== "message.updated" ||
      JSON.stringify(event).includes("private")
    ) throw new Error("reaction not minimized or reconciled");
  }
});
