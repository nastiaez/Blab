import { advanceStreamErasure } from "./stream_account_erasure.ts";

for (const failure of ["devices", "patch", "deactivate"]) {
  Deno.test(`BLA31 interrupted ${failure} erasure resumes without destructive deletion`, async () => {
    let failed = false;
    let inactive = false;
    let privateName = true;
    const devices = new Set(["one", "two"]);
    const paths: string[] = [];
    const server = {
      request: async (
        path: string,
        body?: unknown,
        options?: any,
      ): Promise<any> => {
        paths.push(path);
        const stage = path === "devices" && options?.method === "DELETE"
          ? "devices"
          : options?.method === "PATCH"
          ? "patch"
          : path.endsWith("/deactivate")
          ? "deactivate"
          : "read";
        if (stage === failure && !failed) {
          failed = true;
          throw new Error("injected outage");
        }
        if (path === "devices") {
          if (options?.method === "DELETE") devices.delete(options.query.id);
          return { devices: [...devices].map((id) => ({ id })) };
        }
        if (options?.method === "PATCH") {
          privateName = false;
          return {};
        }
        if (stage === "deactivate") {
          inactive = true;
          return {};
        }
        return {
          users: [{
            id: "actor",
            name: privateName ? "Private" : "Deleted account",
            image: "",
            language: "en",
            teams: [],
            devices: [...devices].map((id) => ({ id })),
            ...(inactive ? { deactivated_at: "now" } : {}),
          }],
        };
      },
    };
    let rejected = false;
    try {
      await advanceStreamErasure(server, "actor", null);
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("partial failure reported success");
    const retry = await advanceStreamErasure(server, "actor", null);
    const repeated = await advanceStreamErasure(server, "actor", null);
    if (
      !retry.done || !repeated.done || devices.size || privateName || !inactive
    ) throw new Error("retry did not settle");
    if (paths.some((p) => p.includes("delete"))) {
      throw new Error("destructive provider path");
    }
  });
}
