# Language and localization QA

## Language contract

- Interface Language: interface copy only.
- Primary Known Language: Normal translations, word descriptions, and learning explanations.
- Learning Language: Practice results and learning-language audio.

## Clients

- Alice: Chrome, local backend. Exact viewport and session details will be recorded when the language-engine pass begins.
- Bob: Android emulator, local backend. Exact device, viewport, and text-scale details will be recorded before Packet B01A capture.
- Credentials are never stored in this record.

## Review packets

| Packet | Scope | Evidence | Owner status |
|---|---|---|---|
| B01A | Profile overview in EN/DE/ES/UK, default and 200% text | `screenshots/b01a-profile/` | In progress |
| B01B | Interface Language picker, apply, success, failure, persistence | `screenshots/b01b-interface-language/` | Not started |
| B02 | Known Languages and Translation Preferences | `screenshots/b02-known-translation-preferences/` | Not started |
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

