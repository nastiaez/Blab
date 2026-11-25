import { deliverReport } from "./linear.ts";

const id = "00000000-0000-4000-8000-000000000002";
const report = { report_id: id, reason: "partial" };
const issue = { id, identifier: "BLA-100", team: { id: "team" } };

Deno.test("sends only the reason and opaque reference to Linear", async () => {
  const request: typeof fetch = (url, options) => {
    const { variables } = JSON.parse(String(options?.body));
    const expected = {
      id,
      teamId: "team",
      title: "Translation report: Incomplete translation",
      description: "Blab report reference: `" + id + "`",
      useDefaultTemplate: false,
    };
    if (
      url !== "https://api.linear.app/graphql" ||
      JSON.stringify(variables.input) !== JSON.stringify(expected)
    ) throw new Error("unexpected delivery payload");
    return Promise.resolve(
      Response.json({ data: { issueCreate: { success: true, issue } } }),
    );
  };
  const identifier = await deliverReport(
    {
      ...report,
      ...JSON.parse('{"note":"private","original_text":"private"}'),
    },
    "test-key",
    "team",
    request,
  );
  if (identifier !== issue.identifier) throw new Error("issue not confirmed");
});

Deno.test("recovers the same issue after a lost create response", async () => {
  let requests = 0;
  const request: typeof fetch = (_url, options) => {
    const { variables } = JSON.parse(String(options?.body));
    if (++requests === 1) {
      if (variables.input.id !== id) throw new Error("wrong create id");
      return Promise.resolve(new Response(null, { status: 503 }));
    }
    if (variables.id !== id) throw new Error("wrong lookup id");
    return Promise.resolve(Response.json({ data: { issue } }));
  };
  const identifier = await deliverReport(report, "test-key", "team", request);
  if (identifier !== issue.identifier || requests !== 2) {
    throw new Error("existing issue not recovered");
  }
});

Deno.test("does not confirm failed deliveries or an issue in a different team", async () => {
  for (
    const request of [
      () => Promise.resolve(new Response(null, { status: 429 })),
      () =>
        Promise.resolve(Response.json({
          data: {
            issueCreate: {
              success: true,
              issue: { ...issue, team: { id: "another-team" } },
            },
          },
        })),
    ]
  ) {
    let delivered = false;
    try {
      await deliverReport(report, "test-key", "team", request);
      delivered = true;
    } catch {
      // The worker leaves this report queued.
    }
    if (delivered) throw new Error("incorrect delivery acknowledged");
  }
});
