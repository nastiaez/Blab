// Independent reviews share inputs, not outputs. Keep the existing two-vote
// acceptance and at-most-three-call budget while removing serial latency.
export async function independentConsensus<T>(
  review: (attempt: number) => Promise<T | null>,
  resolve: (reviews: T[]) => T | null,
): Promise<T | null> {
  const first = await Promise.all([review(0), review(1)]);
  const reviews: T[] = [];
  for (const value of first) if (value !== null) reviews.push(value);
  const agreed = resolve(reviews);
  if (agreed !== null) return agreed;
  const third = await review(2);
  if (third !== null) reviews.push(third);
  return resolve(reviews);
}
