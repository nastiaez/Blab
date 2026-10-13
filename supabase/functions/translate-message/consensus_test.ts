import { independentConsensus } from "./consensus.ts";
function consensus(values: string[]): string | null {
  return values.find((v) => values.filter((x) => x === v).length >= 2) ?? null;
}
Deno.test("first two reviews start independently; agreement avoids third call", async () => {
  const starts: number[] = [];
  const releases: Array<(value: string) => void> = [];
  const work = independentConsensus((i) => {
    starts.push(i);
    return new Promise<string>((resolve) => releases.push(resolve));
  }, consensus);
  if (JSON.stringify(starts) !== "[0,1]") throw new Error("serial reviews");
  releases[0]("accepted");
  releases[1]("accepted");
  if (await work !== "accepted" || starts.length !== 2) {
    throw new Error("budget");
  }
});
Deno.test("disagreement requires third review and never accepts one vote", async () => {
  let calls = 0;
  const result = await independentConsensus(async (i) => {
    calls++;
    return ["a", "b", "b"][i];
  }, consensus);
  if (result !== "b" || calls !== 3) throw new Error("consensus weakened");
  if (
    await independentConsensus(async (i) => ["a", null, "c"][i], consensus) !==
      null
  ) {
    throw new Error("unverified result accepted");
  }
});
