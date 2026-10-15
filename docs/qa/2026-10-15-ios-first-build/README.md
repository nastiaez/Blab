# iOS + shared onboarding acceptance, 15 October 2026

Base: main 63cedf28b2a148dd1a5118bd8d837fa0cd5e05f5.
Owner confirmed illustrated flow in Telegram13132; added native Apple control approved13161 after screenshot13159 (original13154) and walkthrough13155.

Verified native introduction: Welcome → learning demo → sign-up → email on Android production/staging and iOS production/staging. Screenshots retained in this directory; screenshots verify those states, not completed social authentication. Native staging email login additionally authenticated the existing QA account, passed tester access, and reached Chats. Chat data completion was not asserted.

Automated evidence: 947 full Flutter tests passed, 15 skipped; after isolating release fixtures and final harness fixes, final focused suite 89 passed and analysis clean. Tests no longer modify real environment files. iOS environment guard rejects cross-channel bundle/backend combinations.

Both signed iOS build23 candidates uploaded and Apple processing is VALID:
- Production: app6823314008; build9565e260-628d-47ed-8dcf-edde7a326dd6; SHA25678b5413dbcc580d44b25f8c011109daa89ebefb9686f702b476a1f1af2876dc8.
- Test: app6823316052; buildf4416a5a-5afc-423e-89a1-72c2aca730a4; SHA256368d8c100be1d47db06868528b5d9eefd31107c2f4d4d3fb852dda4e69eba082.

No tester assignment yet. Google/Apple account authentication, physical iPhone push delivery, universal links and signed integrated Android release remain outstanding. APNs configuration and iOS token registration enabled on both backends; staging iOS/Android registration and invalid-platform rejection checked, synthetic token removed. Migration20261015215400 recorded on both; unrelated staging boundary migration preserved.

Credentials are excluded from Git. Native QA credential defines were removed from generated release configuration and temporary file deleted; release IPAs did not use them. Signing authorization was scoped to Blab's private key.
