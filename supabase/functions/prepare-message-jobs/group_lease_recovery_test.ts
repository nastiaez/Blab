import { runMessageBatch } from "./single_call_worker.ts";

Deno.test("group generation honors invocation deadline and never commits late output", async () => {
  const reasons: string[] = [];
  let commits = 0;
  let generated = 0;
  const job = {
    id: "j",
    message_id: "m",
    source_version: "s",
    lease_token: "l",
    attempts: 1,
  };
  await runMessageBatch(
    {
      rpc: async (name, args) => {
        if (name === "prepare_translation_viewers") {
          return {
            data: [{
              id: "j",
              prepared: {
                status: "ready",
                messageId: "m",
                text: "Hallo",
                sourceHash: "s",
                targetLang: "de",
                interfaceLang: "uk",
                context: {},
                formContext: { group: true, messageAuthor: "viewer" },
              },
            }],
            error: null,
          };
        }
        if (name === "group_translation_artifact") {
          return {
            data: null,
            error: null,
          };
        }
        if (name === "renew_message_preparation_leases") {
          return {
            data: true,
            error: null,
          };
        }
        if (name === "complete_group_translation_viewers") {
          commits++;
          return { data: [{ jobId: "j", error: null }], error: null };
        }
        if (name === "leased_translation_action") {
          reasons.push(
            (args.p_payload as { reason: string }).reason,
          );
        }
        return { data: true, error: null };
      },
    },
    [job],
    async () => {
      generated++;
      await new Promise((r) => setTimeout(r, 80));
      return {};
    },
    performance.now() + 35,
  );
  if (
    generated !== 1 || commits !== 0 ||
    !reasons.includes("generation_budget_exhausted")
  ) {
    throw Error(JSON.stringify({ generated, commits, reasons }));
  }
  // Drain intentionally uncancellable fake provider output; no late publication.
  await new Promise((r) => setTimeout(r, 90));
  if (commits !== 0) throw Error("late group publication");
});

Deno.test("group loses ownership after generation and cannot publish artifact or viewer result", async () => {
  let renewals = 0;
  let writes = 0;
  const reasons: string[] = [];
  await runMessageBatch({
    rpc: async (name, args) => {
      if (name === "prepare_translation_viewers") {
        return {
          data: [{
            id: "j",
            prepared: {
              status: "ready",
              messageId: "m",
              text: "Bonjour",
              sourceHash: "s",
              targetLang: "fr",
              interfaceLang: "es",
              context: {},
              formContext: { group: true, messageAuthor: "viewer" },
            },
          }],
          error: null,
        };
      }
      if (name === "renew_message_preparation_leases") {
        return { data: ++renewals < 3, error: null };
      }
      if (name === "group_translation_artifact") {
        if (args.p_result) {
          writes++;
        }
        return { data: null, error: null };
      }
      if (name === "complete_group_translation_viewers") writes++;
      if (name === "leased_translation_action") {
        reasons.push((args.p_payload as { reason: string }).reason);
      }
      return { data: true, error: null };
    },
  }, [{
    id: "j",
    message_id: "m",
    source_version: "s",
    lease_token: "l",
    attempts: 1,
  }], async () => ({}));
  if (writes !== 0 || !reasons.includes("lease_expired")) {
    throw Error(JSON.stringify({ writes, reasons }));
  }
});
