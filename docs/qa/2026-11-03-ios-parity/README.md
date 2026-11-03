# iOS parity17634 — TestFlight50 delivered

**Final:** Blab-test50 VALID, beta APPROVED, internal/external IN_BETA_TESTING. Existing Owner testing1 + Invited friends15 memberships unchanged. Only staging test/ios update notice45→50, anonymous readback confirms all other3 rows unchanged. Main product source3009627/runtime04d2173; no runtime changes or backend deployment. BLA37 and BLA40 delivered on iOS; BLA36 retained/rechecked. BLA31 still unfinished/unreleased on both, excluded. Public-flavor apps/App Store/mixed-language excluded. Detailed checkpoint chronology below is superseded by this final status.

Authorization: Nastia17634 requests iOS release and review BLA-31/37/40/36; default both-platform delivery going forward. Existing Blab-test TestFlight channel, no public store submission, no public-flavor rollout or audience expansion. Source main3009627/runtime04d2173. Both iOS apps live latest45 VALID before work.

| Ticket | Android/main | iOS before this release |
| --- | --- | --- |
| BLA-31 account-deletion friend state | Unmerged partial candidate, not delivered | Not delivered, excluded |
| BLA-37 invented surname/tags | Backend fixes staging+production; chooser Android50 | Backend shared/live; chooser not delivered |
| BLA-40 links | Main191933a, included Android49/50 | Shared code, native verification/delivery pending |
| BLA-36 mentions | Main/delivered | Previously delivered43 and retained45; original receipt explicitly lacks native iOS UI verification |

Additional main delta since45: BLA11 readable header71ee3b6. No new runtime feature/policy/backend changes planned. Mixed-language bug deferred.

Live existing iOS test audience read: Owner testing1, Invited friends15 (current API, not stale historical16). IDs captured privately in release folder; preserve equality. Reuse existing Blab iOS QA simulator with exclusive lease, no reset/delete. Native fixtures establish client behavior only, not live-provider/two-account or physical-device acceptance.

Artifacts and receipts: ../../../releases/20261103-ios-parity-17634 (outside repo). Release not yet uploaded/distributed.

## Native verification checkpoint
- Existing Blab iOS QA simulator, iOS26.3; no explicit erase or uninstall; installed fixture updates. Real ChatScreen fixtures using integrated main code.
- Own/partner form select→Change→clear passes; en/de/es/uk at100/200% pass.18 screenshots inspected, no chooser clipping. Pre-existing oversized message typography at200% retained; not a general accessibility audit. One simulator background interruption resumed by foregrounding the same PID; run ultimately exited0.
- BLA40 8-case Normal/Practice ×incoming/outgoing ×short/huge matrix passed; native clipboard equality, fixed menu actions during scroll, preserved draft/native keyboard and outside dismissal.23 screenshots captured. Additional corrected-text/Safari checks still running.
- BLA31 remains a separate unmerged candidate; no migration/backend mutation included.

- BLA40 corrected German plus separate English comprehension, punctuation/bare-domain/full1209-character Copy and real Safari handoff/return pass (exit0). Safari address is correct; webpage loading not asserted.11 supplemental screenshots inspected. Reaction-row emoji appear as missing-glyph boxes in the simulator fixture; reaction implementation/theme unchanged from iOS45, no physical-phone font-rendering claim or reaction redesign included.
- BLA36 native picker selection inserts @Ash; sender/recipient fixture views captured/inspected, run exits0. This is not a live two-account backend test.
- Delivered iOS chooser PNG17646, link-menu PNG17647,18s actual chooser excerpt17648.

- Header uk/es100/200%,48px semantics/toggle/menu callbacks pass (exit0);12 captures inspected,2 uk100 captures rejected because simulator app-switcher/foreground transition obscured the app. Other10 show expected states. Simulator foreground interruptions required launching same existing app; no new device created.
- App container changed across fixture installs. Firebase Installations preference hash retained; app preference plist hash differs. No claim of full saved-data/signed-in-history or signed TestFlight upgrade verification on a physical iPhone.
- All301 product-source hashes matched integrated main before signing. Build-only signing profile selection uses prior verified override and is restored afterward; no runtime changes or new feature integration required.

The observed emoji boxes match confirmed upstream iOS26.3 simulator font-table issue https://github.com/flutter/flutter/issues/183828 (same runtime23D8133, reproduced by Flutter maintainers; physical iOS reported unaffected). Treat simulator emoji appearance as inconclusive for physical release, not evidence of a new Blab regression. No unrelated app font workaround introduced.

## Signed artifact / Apple checkpoint
- Blab-test1.0.0(50) signed IPA33326218bytes, SHA2560266b5fb93ba9ffc1eac689932a29efe6465369e384e6347076aebd9663d3340. Parent and both notification extensions50; correct blab-staging Firebase identity; all signatures valid, distribution entitlements, debugger disabled. Prior signing override restored; all301 product hashes unchanged.
- Apple upload accepted without errors, delivery880c2f67-4a6d-4065-807f-951d4f3039d0. Processing/distribution pending; no availability claim yet.
- Regular main-entrypoint simulator50 installed over existing QA installation and launches Welcome; screenshot inspected. Not a physical TestFlight install/history-retention proof.
