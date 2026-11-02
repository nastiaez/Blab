import { assert, assertEquals } from "jsr:@std/assert";
import { runMessageBatch } from "./single_call_worker.ts";
import { generateMessageOnce } from "../translate-message/single_call.ts";
import { compactPlan } from "../translate-message/compact_request.ts";
import { isMentionIntegrityFailure } from "../translate-message/mention_identity.ts";

for (const group of [false, true]) {
  for (
    const fault of [
      "invented",
      "all_invented",
      "missing",
      "duplicated",
      "altered",
      "valid",
      "transport",
    ]
  ) {
    Deno.test(`${group ? "group" : "direct"} ${fault}: integrity stops once, healthy viewers persist`, async () => {
      const jobs = [0, 1, 2].map((i) => ({
        id: `j${i}`,
        message_id: "m",
        source_version: "h",
        lease_token: `l${i}`,
        attempts: 1,
      }));
      const selected = ["missing", "duplicated"].includes(fault);
      const text = selected
        ? "Hello @Ash"
        : fault === "altered"
        ? "Hello @ash"
        : "hi ashwin";
      const mentions = selected
        ? [{
          userId: "11111111-1111-4111-8111-111111111111",
          label: "Ash",
          start: 6,
        }]
        : [];
      const finishes: any[] = [], commits: any[] = [];
      const admin = {
        rpc: async (name: string, args: any) => {
          if (name === "prepare_translation_viewers") {
            return {
              error: null,
              data: jobs.map((j, i) => ({
                id: j.id,
                prepared: {
                  status: "ready",
                  messageId: "m",
                  text,
                  mentions,
                  sourceHash: "h",
                  targetLang: i === 2 ? "uk" : "de",
                  interfaceLang: "en",
                  formContext: {
                    group,
                    messageAuthor: "viewer",
                    viewerName: "Aswin Ranganathan",
                    partnerName: group ? "Group" : "Nastia",
                  },
                },
              })),
            };
          }
          if (name === "group_translation_artifact") {
            return { error: null, data: null };
          }
          if (name === "renew_message_preparation_leases") {
            return { error: null, data: true };
          }
          if (name === "leased_translation_action") {
            finishes.push(args);
            return { error: null, data: true };
          }
          if (name === "complete_translation_message_batch") {
            commits.push(...args.p_results);
            return { error: null, data: true };
          }
          if (name === "complete_group_translation_viewers") {
            commits.push(...args.p_entries);
            return {
              error: null,
              data: args.p_entries.map((e: any) => ({
                jobId: e.jobId,
                error: e.result ? null : "invalid_viewer_result",
              })),
            };
          }
          throw new Error(`unexpected_rpc_${name}`);
        },
      };
      let calls = 0;
      await runMessageBatch(
        admin,
        jobs,
        async (vs, onFailure) =>
          await generateMessageOnce(
            vs,
            {
              provider: "openrouter",
              apiKey: "test",
              model: "test",
              useOpenRouterProviderPolicy: true,
            },
            async (_url, init) => {
              calls++;
              if (fault === "transport") {
                return new Response("", { status: 503 });
              }
              const body = JSON.parse(String(init?.body));
              const source = JSON.parse(body.messages[1].content).message;
              assert(!body.messages[1].content.includes("Aswin Ranganathan"));
              assert(!body.messages[1].content.includes("Nastia"));
              const plan = compactPlan(vs);
              const sentences = plan.requested.sentences.map((s) => {
                let output = source;
                if (s.language === "German" || fault === "all_invented") {
                  if (
                    fault === "invented" || fault === "all_invented"
                  ) output += " @Aswin_Ranganathan";
                  if (fault === "missing") output = "Hallo";
                  if (fault === "duplicated") {
                    output = source + " " + source;
                  }
                  if (fault === "altered") {
                    output = source.replace("@ash", "@ash_changed");
                  }
                }
                return {
                  id: s.id,
                  mode: "translation",
                  sourceLang: "en",
                  text: output,
                };
              });
              return Response.json({
                choices: [{
                  message: { content: JSON.stringify({ sentences, help: [] }) },
                }],
              });
            },
            true,
            onFailure,
          ),
      );
      assertEquals(calls, 1);
      if (fault === "transport") {
        assertEquals(finishes.length, 3);
        assert(finishes.every((f) => f.p_payload.outcome === "retry"));
      } else if (fault === "valid") {
        assertEquals(finishes.length, 0);
        assertEquals(commits.length, 3);
      } else {
        assertEquals(finishes.length, fault === "all_invented" ? 3 : 2);
        assert(
          finishes.every((f) =>
            f.p_payload.outcome === "failed" &&
            f.p_payload.delaySeconds === 0 &&
            isMentionIntegrityFailure(f.p_payload.reason)
          ),
        );
        assertEquals(
          commits.map((c) => c.jobId),
          fault === "all_invented" ? [] : ["j2"],
        );
      }
    });
  }
}

Deno.test("later group transport failure cannot requeue earlier integrity failures", async () => {
  const jobs = Array.from(
    { length: 6 },
    (_, i) => ({
      id: `j${i}`,
      message_id: "m",
      source_version: "h",
      lease_token: `l${i}`,
      attempts: 1,
    }),
  );
  const finishes: any[] = [];
  const langs = ["de", "uk", "fr", "es", "it", "de"];
  const admin = {
    rpc: async (name: string, args: any) => {
      if (name === "prepare_translation_viewers") {
        return {
          error: null,
          data: jobs.map((j, i) => ({
            id: j.id,
            prepared: {
              status: "ready",
              messageId: "m",
              text: "Hello",
              sourceHash: "h",
              targetLang: langs[i],
              interfaceLang: "en",
              formContext: { group: true, messageAuthor: "viewer" },
            },
          })),
        };
      }
      if (name === "group_translation_artifact") {
        return {
          error: null,
          data: null,
        };
      }
      if (name === "renew_message_preparation_leases") {
        return {
          error: null,
          data: true,
        };
      }
      if (name === "leased_translation_action") {
        finishes.push(args);
        return { error: null, data: true };
      }
      throw Error("unexpected_rpc");
    },
  };
  let calls = 0;
  await runMessageBatch(admin, jobs, async (vs, onFailure) => {
    calls++;
    if (calls === 1) {
      for (const v of vs) onFailure(v, new Error("unknown_mention_handle"));
      return {};
    }
    throw Error("provider_http_503");
  });
  assertEquals(calls, 2); // Two distinct contract batches, not a failed-output retry.
  assertEquals(
    finishes.filter((f) => f.p_payload.outcome === "failed").map((f) =>
      f.p_job_id
    ),
    ["j0", "j1", "j2", "j3", "j5"],
  );
  assertEquals(
    finishes.filter((f) => f.p_payload.outcome === "retry").map((f) =>
      f.p_job_id
    ),
    ["j4"],
  );
});
