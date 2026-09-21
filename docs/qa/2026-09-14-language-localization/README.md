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
| B02D | Known Languages successful-save and offline save-error states in EN/DE/ES/UK | `screenshots/b02-known-translation-preferences/` | Approved 2026-09-15 |
| B03A | Privacy and Notifications overview in EN/DE/ES/UK, plus unsupported-local-build handling | `screenshots/b03-privacy-notifications-account/` | Approved 2026-09-15 |
| B03B | Minimal logout and credential-free, two-step delete-account confirmations in EN/DE/ES/UK | `screenshots/b03-privacy-notifications-account/` | Approved 2026-09-15 |
| B03C | Privacy preference save/failure states and physical-device Notifications verification | `screenshots/b03-privacy-notifications-account/` | Privacy persistence approved; physical-device Notifications verification pending |
| B04A | Edit Profile and Change Email forms in EN/DE/ES/UK | `screenshots/b04-account-forms/` | Approved 2026-09-15 |
| B04B | Change Password form and localized validation states in EN/DE/ES/UK | `screenshots/b04-account-forms/` | Approved 2026-09-15 |
| B05A | Signup and login in EN/DE/ES/UK | `screenshots/b05-auth/` | Approved 2026-09-15 |
| B05B1 | Password recovery request and email confirmation in EN/DE/ES/UK | `screenshots/b05-auth/` | Approved 2026-09-15 |
| B05B2 | New-password form and validation states in EN/DE/ES/UK | `screenshots/b05-auth/` | Approved 2026-09-15 |
| B05C | Six-character password guidance across signup, reset, and change-password | `screenshots/b05-auth/` | Approved 2026-09-15 |
| B06 | Chats list and invite flow | `screenshots/b06-chats-invite/`, `screenshots/b06-chats-invite-fixed/` | Approved 2026-09-16 |
| B07A | Chat header, language menu, composer, learning-language sheet, and hidden chat states | Before: `screenshots/b07-chat-controls/`; repaired: `screenshots/b07-chat-controls-fixed/` | Approved 2026-09-18 |
| B07B | Reply, edit, delete, report, reaction, photo, delivery, and translation states | `screenshots/b07-message-states/` | Approved 2026-09-19 |
| B08 | Shared system and accessibility states, plus Normal-mode message actions | `screenshots/b08-system-accessibility/` | Approved 2026-09-19, including the compact Ukrainian Normal-pill revision |
| L01 | Dutch translation, correction, word help, and audio | `screenshots/l01-dutch/` | Approved 2026-09-20 |
| L02 | English translation, correction, German word help, and English audio | `screenshots/l02-english/` | Approved 2026-09-20 |
| L03 | French translation, correction, German word help, and French audio | `screenshots/l03-french/` | Approved 2026-09-20 after word-help repair |
| L04 | German translation, correction, French word help, and German audio | `screenshots/l04-german/` | Approved 2026-09-21 |
| L05 | Hindi translation, correction, French word help, and Hindi audio | `screenshots/l05-hindi/` | Approved 2026-09-21 after correction, word-help, and tense repair |
| L06 | Spanish translation, correction, French word help, and Spanish audio | `screenshots/l06-spanish/` | Approved 2026-09-21 |
| L07 | Italian translation, correction, French word help, and Italian audio | `screenshots/l07-italian/` | Approved 2026-09-21 |
| L08 | Portuguese translation, correction, French word help, and Portuguese audio | `screenshots/l08-portuguese/` | Approved 2026-09-21 after word-help repair |
| L09-L11 | One packet for each remaining Learning Language | `screenshots/l*/` | Not started |
| K01+ | Primary Known Language routing and switching | `screenshots/k*/` | Not started |

## Evidence rules

- Every screenshot comes from the real Blab client connected to the local backend.
- Interface packets use one stable fixture and matching state across English, German, Spanish, and Ukrainian.
- Each packet contains four to eight images.
- Findings are recorded before repairs; owner feedback defines the repair scope.
- Changed screenshots are resent after repair. Tracker completion requires explicit owner approval.
