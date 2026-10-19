# Update notices (BLA-15)

The connection-banner slot can show plain **Update available** on soft peach,
with a separate right-aligned orange **Update** button. Only the button is
actionable. Nastia approved Paper option D on 19 October (14157): 48px baseline
peach banner, 32px visible brand-orange button with 8px corners and warm-ink
14px/20px semibold text. The invisible touch target remains at least 48px.
The button expands for larger text. On narrow screens with large text, the action
wraps below the status rather than splitting the button label. Connecting/Offline
remain silent per the 19 October US-031 revision; update availability hides while
offline or checking access. Text follows
Interface Language; no learning or translation preferences change.

## Owner control

Supabase Dashboard → Table Editor → `app_update_notices`. Choose platform and
channel. Set `latest_build` to the already distributed integer release number,
verify `destination`, then turn `enabled` on. Turn it off to hide it. This is
operator-only configuration, never a user-accessible preference. No app rebuild
is required. Keep platform rows independent when Apple review delays availability.
Clients check on reconnect, foreground resume and once per foreground minute.
Missing/unreachable/malformed configuration hides the notice. There is no forced
upgrade, blocked chat, automatic install or stale persisted notice.

The migration seeds all four rows **disabled, latest_build=0**. Test Android
uses the existing Firebase tester app; test iOS uses the existing Blab-test
TestFlight app identity. Public uses the actual package/App Store app identity,
not a search page. Do not enable public rows until the store release is actually
available. Public beta distribution remains separate from public-store availability.
TestFlight/Firebase access is still required; a link does not grant membership.

The installed version comes from native package metadata, not the source
pubspec's development version. The latest build must be larger than the installed
build. Every published platform/channel must maintain increasing build numbers.
Unknown build numbers and nonmobile clients do not display an update notice.

## Rollout boundary

Already installed clients cannot acquire this new UI remotely. They need the
feature-bearing release once before later releases can advertise updates.
Native destination handoff and actual tester account access must be verified
before enabling. Production migration/configuration/distribution is a separate
exact-scope approval; screenshots alone do not authorize it.
