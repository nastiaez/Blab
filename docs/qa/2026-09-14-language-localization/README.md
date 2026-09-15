# Language and localization QA

## Language contract

- Interface Language: interface copy only.
- Primary Known Language: Normal translations, word descriptions, and learning explanations.
- Learning Language: Practice results and learning-language audio.

## Clients

- Alice: Chrome, local backend. Exact viewport and session details will be recorded when the language-engine pass begins.
- Bob: `sdk_gphone64_arm64` Android emulator, Android 16 / API 36, 1080×2400 physical viewport, density 420, local backend on 2026-09-14.
- Packet B01A used system font scales 1.0 and 2.0. Font scale was restored to 1.0 after capture.
- Credentials are never stored in this record.

## Review packets

| Packet | Scope | Evidence | Owner status |
|---|---|---|---|
| B01A | Profile overview in EN/DE/ES/UK, default and 200% text | Before: `screenshots/b01a-profile/`; repaired: `screenshots/b01a-profile-fixed/` | Approved 2026-09-14 |
| B01B | Interface Language picker, apply, success, failure, persistence | `screenshots/b01b-interface-language/` | Approved 2026-09-14 |
| B02A | Known Languages and Translation Preferences overview in EN/DE/ES/UK | `screenshots/b02-known-translation-preferences/` | Approved 2026-09-14 |
| B02B | Known Languages and Translation Preferences selection sheets in EN/DE/ES/UK | `screenshots/b02-known-translation-preferences/` | Approved 2026-09-15 |
| B02C | Translation Preferences successful-save and offline save-error states in EN/DE/ES/UK | `screenshots/b02-known-translation-preferences/` | Approved 2026-09-15 |
| B02D | Known Languages successful-save and offline save-error states in EN/DE/ES/UK | `screenshots/b02-known-translation-preferences/` | In progress |
| B03 | Privacy, Notifications, logout, delete account | `screenshots/b03-privacy-notifications-account/` | Not started |
| B04 | Edit profile, email, password | `screenshots/b04-account-forms/` | Not started |
| B05 | Signup, login, password recovery | `screenshots/b05-auth/` | Not started |
| B06 | Chats list and invite flow | `screenshots/b06-chats-invite/` | Not started |
| B07 | Chat controls, menus, and message states | `screenshots/b07-chat/` | Not started |
| B08 | Shared system and accessibility states | `screenshots/b08-system-accessibility/` | Not started |
| L01-L11 | One packet for each Learning Language | `screenshots/l*/` | Not started |
| K01+ | Primary Known Language routing and switching | `screenshots/k*/` | Not started |

## Evidence rules

- Every screenshot comes from the real Blab client connected to the local backend.
- Interface packets use one stable fixture and matching state across English, German, Spanish, and Ukrainian.
- Each packet contains four to eight images.
- Findings are recorded before repairs; owner feedback defines the repair scope.
- Changed screenshots are resent after repair. Tracker completion requires explicit owner approval.
