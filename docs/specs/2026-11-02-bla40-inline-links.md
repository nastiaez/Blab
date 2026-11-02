# BLA-40 · Inline chat URLs

## Authority and review gate
Nastia explicitly authorized implementation in Telegram topic8856 message17281, 2 November 2026 at15:32 Berlin. This is design/build authorization only. No commit, push, integration, Firebase/TestFlight distribution, or production/backend mutation. Candidate begins at fetched origin/main ed2ac549d287944613341491eaf700299aaf8a38 in feat/bla40-links-20261102. Owner review of actual candidate screenshots and motion is still required.

Canonical Paper file01M3PCM6SC0AMB5Q0M3AZ58WBR pagep-K-0:557-0,55O-0,567-0. All three exact JSX/style exports and prior PNGs inspected. Latest conversational approval supersedes the older “not approved” compact-option annotation and static non-scrolling menu. Do not reproduce prototype labels/debug annotation content in the app.

## Final approved contract
- Incoming URLs use actual incoming mention ink #BC6C4E; outgoing use actual outgoing mention ink #231208 in both Normal and Practice. Every URL is underlined. Incoming contrast3.81:1 was disclosed and is below4.5:1; no darkening was approved.
- Render inline using natural line wrapping and normal line boxes, not indivisible word-sized URL boxes. Preserve source paragraph breaks. Short URLs remain complete. Long URLs compact after two rendered URL lines with ellipsis, keeping the complete authority/security-relevant host visible.
- The display is not the payload. Keep authored raw strings unchanged. Copy returns the complete raw URL including full query/fragment; external Open uses the full destination. Bare domains (including nastia.design) use https for browser launch, while Copy retains the authored bare form. No server shortening, new AI request, rich website card, source-message mutation, translation-policy change, or cache mutation.
- Tap URL opens a separate anchored menu. One destination appears in a height-capped area (~four visible lines at normal text). That area alone scrolls for very long strings. Open in browser precedes Copy link; both remain visible. Message height and compact text remain unchanged while the menu is open. Outside tap and system Back dismiss. Retain keyboard/draft where possible without a layout-changing selection action.
- Menu uses existing warm surface #FFFCF8,20px radius, subtle shadow,16px horizontal and8px vertical padding; destination14px/20px muted #5F6770, actions16px,16px icons with16px gap,48px minimum rows and #E1DAD2 separators. Localize interface labels independently of learning/primary-known languages.
- Link taps take precedence over message selection/heart recognizers. Other words, mentions, reaction controls, reply and BLA17 anchored actions retain existing behavior.

## Security and accessibility adaptations
A pathological authority longer than two rendered lines is shown in full, even if it exceeds the two-line compact goal. Only the path/query can be elided; never conceal the host behind ellipsis or show a different domain. Long continuous domains use Flutter's native wrapping and are available unabridged in the scrollable menu. Large text scales the destination cap and action rows. Universal tiny-screen/keyboard-occluded fit must not be claimed without evidence.

URL-containing bubbles use their existing maximum bubble width rather than asking the new layout-dependent paragraph for intrinsic width. Non-URL bubbles retain the incumbent intrinsic layout. This avoids a proven native blank-chat intrinsic-layout exception and allows two-line measurement against the actual available width. It is a candidate layout adaptation subject to screenshot review, not a redesign of unrelated messages.

## Preference-to-output mapping (unchanged)
Interface Language owns menu/error labels only. Primary Known Language owns unknown incoming Normal output and expanded comprehension. Learning Language owns Practice output/audio. Known Normal source, learning-aids-off, unsupported-source, historical correction eligibility, cached forms and reading-script resolution retain existing logic. Links are applied only after that existing visible-text choice. Generated mention IDs and authored mention ranges remain owned by existing parsers. No backend/prompt/cache work is in scope.

## Original report (preserved)
Nastia reported in Blab Dev1(Sol),2 November2026: https://t.me/c/1003767595888/17175 ; screenshot https://t.me/c/1003767595888/17174 . Android Practice corrected German text containing https://berlinscienceweek.com/ wraps after https:// and has excessive blank gaps. Highlight/action expected. Root cause initially unknown; distinguish source newlines from renderer gaps. Reproduce in both directions/modes, corrected bilingual text, long/multiple/bare URLs, punctuation/query, narrow/large text; verify full clipboard, external browser, scrolling URL/fixed actions, keyboard/dismissal and gesture regressions.

## Acceptance status
Implementation/QA in progress, not owner accepted. Automated checks do not substitute for actual Android/iOS evidence. Native fixture proof is not live two-account/provider/backend proof. See ../qa/2026-11-02-bla40/ and ../qa/2026-11-02-bla40-native/ for exact results and platform limitations.
