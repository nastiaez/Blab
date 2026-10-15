# Practice language integrity — candidate review

Base: main45c1ea4, dedicated fix/practice-language-context-20261014. Recovery v17 is already distributed. This follow-up is unmerged/unreleased; production cached results remain unchanged.

## Diagnosis and changes

Scoped read-only production inspection confirmed a saved English primary result under target German. A fresh replay also reproduced rejection of consecutive malformed learner German. Lexical-overlap rejection, literal grammar anchoring, and unaudited same-language known-language output were separate causes. Candidate independently checks meaning and target language, repairs copied foreign known-language output before review, and lets legitimate grammar repairs reach meaning consensus. No meaning-review bypass. Practice unchanged German now retains English long-press reveal and Listen; learning-aid-disabled/unsupported exceptions remain.

## Verification

- 900 Flutter tests passed;15 intentional skips. Static analysis clean. Web and Android debug builds passed.
-197 backend tests passed. No database schema changes in this slice.
-22 synthetic sends across11 languages:44/44 readable viewer results and44/44 word-help results. Median1.8725s, sample p95 2.708s, maximum5.679s. This is a test sample, not a production SLO guarantee.
- Exact synthetic learner sequence: Los geht’s; Kannst du mir hier replyieren; Wenn ich du Message senden; Komme hier. Both viewers completed all four on first job attempt. Ambiguous Komme hier is preserved rather than forcibly inventing an imperative.
- Android emulator5558 in-place update retained Bob test session. Browser Alice and Android Bob show German Practice primary; actual UI send Los geht’s! observed at both clients. API-seeded prior sequence exercised real backend.
- Android long-press reveals English for both unchanged and corrected German. Tapping antworten opens reply. Actual screenshots inspected. Video duration18.904s; sampled frame inspected.
- Browser primary rendering inspected at420x900. Long-press interaction verified on Android, not separately on browser.

## Review walkthrough

1. android-practice-final.png: both malformed messages corrected in German; no failed translation.
2. android-known-reveal-final.png: German remains primary; English appears beneath divider only on long-press.
3. android-correction-reveal.png: corrected sentence reveals English meaning.
4. android-word-final.png: corrected word popup shows antworten / reply.
5. android-flow.mp4: actual long-press interaction recording; web-practice.png is the partner client.

## Remaining

Owner approval of this actual flow; integrated release verification; targeted repair/requeue of the specifically diagnosed stale production translations. Do not invalidate all history. Physical-phone and live Firebase push verification remain outstanding from v17. No new production write performed for this follow-up.
