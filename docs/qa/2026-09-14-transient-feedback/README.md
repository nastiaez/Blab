# Transient feedback verification — 2026-09-14

## Scope

Verified the interface-language confirmation Snackbar on the installed Android debug app using Bob's local account.

| Target interface language | Message | Action | Result |
| --- | --- | --- | --- |
| English | `Switched to English` | `Undo` | One line, no close icon |
| German | `Zu Deutsch gewechselt` | `Rückgängig` | One line, no close icon |
| Spanish | `Idioma cambiado a Español` | `Deshacer` | One line, no close icon |
| Ukrainian | `Мову змінено на Українська` | `Скасувати` | One line, no close icon |

Canonical captures:

- `snackbar-en.png`
- `snackbar-de.png`
- `snackbar-es.png`
- `snackbar-uk.png`
- `snackbar-locales-comparison.png`

## Behavior checks

- Actionable feedback remains available for 4 seconds.
- Passive feedback uses 2.5 seconds.
- The close icon is absent.
- An unrelated tap does not dismiss actionable feedback.
- Back, route navigation, a replacement Snackbar, swipe, Undo, or timeout dismisses it.
- Language-change feedback uses the successfully saved target locale for the message, language name, and Undo label.
- Android route navigation dismissal was confirmed from the visible Ukrainian Snackbar.

## UI review

| Category | Score | Note |
| --- | ---: | --- |
| Visual hierarchy | 9/10 | Message and action are immediately distinguishable. |
| Layout and spacing | 9/10 | All four launch locales fit the compact single-line height. |
| Consistency | 9/10 | Identical structure and placement across locales. |
| Usability | 9/10 | Undo remains prominent without a competing close control. |
| Accessibility | 8/10 | Text is untruncated and the action retains its platform tap target. |
| Content clarity | 9/10 | Copy identifies the saved language and exposes one reversible action. |
| Responsive behavior | 9/10 | The longest launch-locale copy remains within one line on the default Android test viewport. |
| Polish | 9/10 | Compact, stable, and free of the previous X-induced wrapping. |
