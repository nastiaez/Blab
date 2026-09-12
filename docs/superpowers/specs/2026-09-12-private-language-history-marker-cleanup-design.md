# Private Language History Marker Cleanup

## Goal

Make the private learning-language timeline concise and understandable without changing which historical translation belongs to each message.

## Approved behavior

### Localized marker

`Now learning [language]` is interface copy. Render the full marker in the viewer's current interface language, including the learning-language name. English, Ukrainian, German, and Spanish interface locales must be covered. Unknown language codes fall back safely instead of exposing an untranslated template.

The marker remains:

- private to the viewer whose learning language changed;
- visible in both Normal and Practice modes;
- visually identical to the approved date-label treatment;
- positioned after a date label when both begin the same section.

### Collapse empty language eras

Keep every language-revision event in storage, but show a marker only when it describes a visible section of the conversation.

If several language changes happen without a message between them, render only the final change at that boundary. For example, German → Spanish → French with no intervening message produces one visible `Now learning French` marker. If a message exists during the Spanish era, both Spanish and French markers remain visible.

Messages continue to select their translation from the full private timeline. Collapsing markers is presentation-only and must not reassign, duplicate, clear, or retranslate historical messages.

## Existing behavior preserved

- The initial language era stays silent; revision one does not render a marker.
- Completed messages retain their assigned historical learning language.
- A quoted message uses the era of the referenced message, while the new reply uses its own era.
- Late results from an old revision cannot replace the active revision.
- The marker timeline remains account-scoped and private from the chat partner.
- Restart, history paging, and mode switching preserve the same timeline and reading position.

## Alternatives considered

1. **Render every revision event.** Rejected because empty eras create stacked markers with no messages to explain.
2. **Delete superseded revision events.** Rejected because the complete private timeline is needed for correctness and race protection.
3. **Keep all events and collapse only their visible markers.** Selected because it removes clutter without changing historical ownership or translation data.

## Verification

- Marker copy and all supported learning-language names render correctly in English, Ukrainian, German, and Spanish interface locales.
- German → Spanish → French with no messages between switches shows only the French marker.
- German → Spanish, one message, then French shows both markers in order.
- Historical message and cross-era quoted-message translations retain their original eras.
- Date/marker/message spacing remains 18/10/10 at a dated boundary and 10/10 between bubbles.
- The partner cannot load or render the viewer's private markers.
- Focused tests, the full automated suite, static analysis, and the owner language-switch device matrix pass before commit and push.
