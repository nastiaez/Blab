# Private language-history verification — 2026-09-12

Environment: local Supabase data and the installed production `ChatScreen` on Android 16 emulator `emulator-5554`. The matrix used only local test accounts and records no message contents or credentials here.

## Result

| Scenario | Evidence | Result |
| --- | --- | --- |
| Meaningful eras remain visible | A message was sent inside one language era before switching again; both surrounding markers remained in timeline order. The exact German → Spanish message → French fixture also passes the focused chat-screen test. | Pass |
| Empty eras collapse | Two language changes were completed without an intervening message. Only the final marker appeared; the intermediate marker was absent while its revision remained stored. | Pass |
| Historical reply language | The cross-era reply regression renders the referenced message in its historical era and the new reply body in the current era. | Pass |
| Normal/Practice | Both meaningful markers remained present while switching modes on the production chat screen. Existing anchor regression also keeps the reading position stable. | Pass |
| Restart/reopen | Force-stop, direct relaunch, and chat reopen restored the same meaningful markers and historical message boundary. | Pass |
| Viewer privacy | After signing into the partner account on the same installed app, none of the viewer's new language markers appeared. Database RLS limits timeline rows to `user_id = auth.uid()`. | Pass |
| Marker localization | German production UI rendered natural full-sentence marker copy. Focused localization checks cover English, German, Spanish, and Ukrainian for all eleven learning-language codes. | Pass |

## UX review

Evidence: production Android chat screen with realistic local history, four-locale marker checks, and focused timeline/reply regressions.

- Information architecture: 10/10
- Interaction design: 9/10
- Trust and clarity: 10/10
- Visual polish: 9/10
- Fit to user intent: 10/10
- Operational usefulness: 9/10

Strongest choices: the marker remains quiet and secondary to messages; meaningful eras remain understandable while empty eras no longer add clutter; full-sentence localization avoids mixing translated UI with English; no marker leaks into the partner's history. No blocking UX issues remain.

## Automated verification

- Focused Flutter matrix: 30 passed.
- Full Flutter suite: 471 passed, 15 intentionally skipped.
- Analyzer and `git diff --check`: clean.
- Relevant database era tests passed: `historical_language_era`, `initial_language_timeline`, and `invite_first_language`.
- The full database suite also reported seven pre-existing failures in translation/correction tests outside this branch; no Supabase files changed here.
