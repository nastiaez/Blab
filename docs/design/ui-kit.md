# Blab UI Kit

This is the living visual reference for Blab. Update it whenever a visual rule is approved.

## Color roles

| Role | Value | Usage |
| --- | --- | --- |
| Brand | `#F88C5A` | Primary actions, active controls, selections, unread badges, progress |
| Brand pressed | `#F07D4B` | Pressed brand controls |
| App background | `#FAF7F2` | Screen canvas and bottom navigation |
| Raised surface | `#FFFCF8` | Cards, sheets, incoming bubbles, dialogs |
| Divider | `#E1DAD2` | Hairlines and surface outlines |
| Warm ink | `#46281C` | Headings, controls, and text on brand fills |
| Bubble ink | `#231208` | High-contrast text on message and badge fills |
| Warm muted | `#917869` | Secondary text on warm surfaces |
| Selection tint | `#FAF1EC` | Focused inputs and quiet highlights |
| Language selection tint | `#F7EFE5` | Selected language rows |
| Error / destructive | `#C62828` | Errors, destructive actions, and warning confirmations |
| Soft warning surface | `#F3DAD0` | Offline and recoverable warning banners |

Do not introduce `#D4694A`, `#BB573B`, or `#EFEBE2` in product UI.

## Surfaces and layout

- Use `#FAF7F2` for the full-screen background.
- Use `#FFFCF8` with a `#E1DAD2` outline for cards and raised panels.
- Use 16 or 20 px page margins, following the surrounding screen.
- Use an 8 px spacing rhythm. Prefer 8, 12, 16, 20, 24, and 32 px gaps.
- Use 16 px card corners and 14 px control corners.
- Primary actions are 52 px high. Small circular actions are at least 44 px.
- Language pickers use flat 48 px rows without outlines. Selected rows use the language selection tint, bold text, and a trailing check.

## Type hierarchy

- Screen title: 20–22 px, bold.
- Card or section title: 17 px, bold.
- Body and controls: 14–16 px.
- Supporting text and timestamps: 11–13 px.
- Use warm ink for hierarchy and warm muted for supporting copy.

## Controls

- Brand-filled controls use `#F88C5A` with `#46281C` warm ink for text,
  icons, and loading indicators; never use white foregrounds on the brand fill.
- Active tabs, switches, checkmarks, focus borders, links, progress, and selected controls use the brand color.
- Multi-select language rows keep the trailing check and place the 44 px primary-language star immediately before it.
- Disabled controls use neutral disabled surface and ink colors, not faded orange.
- Unread badges use brand fill with dark bubble ink.
- Focus borders use the brand color at reduced opacity.

## Feedback states

- Error and validation copy uses `#C62828`.
- Retry remains a brand action unless the retry itself is destructive.
- Offline state uses the soft warning surface with `#C62828` text.
- Log out stays neutral in the Profile list. Its confirmation action uses `#C62828`.
- Delete Account uses `#C62828` throughout and receives stronger emphasis than Log out.
- Cancel actions remain neutral.

## Reference screens

- Chats list
- Chat in Practice mode
- Chat in Normal mode
- Profile
- Invite recovery and other recently approved error states

New work should reuse their surface, spacing, type, control, and feedback patterns before introducing a new treatment.
