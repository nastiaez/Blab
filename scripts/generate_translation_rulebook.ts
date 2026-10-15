import { renderTranslationRulebook } from "../supabase/functions/translate-message/rulebook.ts";
await Deno.writeTextFile(
  new URL("../docs/translation-rulebook.md", import.meta.url),
  renderTranslationRulebook(),
);
