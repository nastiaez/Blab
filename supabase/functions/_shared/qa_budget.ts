export type QaRpc = (
  name: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: unknown }>;
export type DispatchGuard = {
  bounded: boolean;
  kind: string;
  authorize: () => Promise<void>;
};
export function dispatchGuard(
  rpc: QaRpc,
  args: Record<string, unknown>,
  bounded: boolean,
): DispatchGuard {
  return {
    bounded,
    kind: String(args.p_kind),
    authorize: async () => {
      const reply = await rpc("qa_provider_dispatch", args);
      if (reply.error || reply.data !== true) {
        throw new Error(
          "qa_dispatch_denied",
        );
      }
    },
  };
}
export function assertQaBody(
  body: Record<string, unknown>,
  model: string,
  kind: string,
) {
  if (
    model !== "gpt-6-luna" ||
    body.max_completion_tokens !== (kind === "base" ? 2500 : 1600) ||
    new TextEncoder().encode(JSON.stringify(body)).length > 10000 ||
    body.tools || body.stream
  ) throw new Error("qa_request_bound_denied");
}
