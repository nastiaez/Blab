export type Mention = { userId: string; label: string; start: number };
/** Offsets match Dart/JS UTF-16, not PostgreSQL Unicode character indexes. */
export function parseMentions(raw: unknown, body: string): Mention[] {
  if (raw === undefined) return [];
  if (!Array.isArray(raw) || raw.length > 50) {
    throw new Error("invalid_mentions");
  }
  let end = 0;
  return raw.map((m) => {
    if (
      !m || typeof m.userId !== "string" ||
      !/^[0-9a-f-]{36}$/i.test(m.userId) || typeof m.label !== "string" ||
      !m.label.trim() || /[\r\n]/.test(m.label) || !Number.isInteger(m.start) ||
      m.start < end ||
      body.slice(m.start, m.start + m.label.length + 1) !== "@" + m.label
    ) throw new Error("invalid_mentions");
    end = m.start + m.label.length + 1;
    return { userId: m.userId, label: m.label, start: m.start };
  });
}
