# Component implementation disposition

All rows are implemented or deliberately retained as listed. None is owner-accepted or released yet. The full migration checklist remains the acceptance contract; this is a source/evidence index, not a claim that every external integration was re-exercised.

## Shared C01–C25

| ID | Current implementation / retention |
|---|---|
| C01 | `BlabNavigationBar`: genuine NavigationBar/Destinations, one foreground border/shadow and theme across both tabs. |
| C02 | `BlabAppBar`: native AppBar with original icons/actions and account/chat variants. |
| C03 | Existing Scaffold/SafeArea feature layouts retained; shared account language scaffold. Keyboard owner remains feature-specific. |
| C04 | `BlabSectionCard`, explicit inset/flush variants for original outlines. |
| C05 | `BlabSettingsRow`, `BlabValueRow`, external-link/icon-label variants; native ListTile where geometry fits. |
| C06 | `BlabSettingSwitchRow`: single labeled semantic control, switch-only pointer policy. |
| C07 | `BlabSwitch`: genuine Material Switch, account geometry exception awaiting review. |
| C08 | `BlabChatModeToggle.segmented`: owner-directed exact custom capsule; thin per-chat ModeToggle adapter. |
| C09 | `BlabSelectionRow`: native ListTile and selected Material surface. |
| C10 | `showBlabModalSheet`: typed native presentation, selection layout stays feature-composed to preserve staged/required policies. |
| C11 | `BlabFormField.account/onboarding`: shared native editing engine, existing controllers/rules retained. |
| C12 | `BlabPasswordField`: shared visibility/action engine and named visual variants. |
| C13 | `BlabButton.account/onboarding`: FilledButton with retained press/loading contract. |
| C14 | `BlabIconButton`: native IconButton; Chats plus remains native FAB. |
| C15 | `BlabAvatar`: exact named size/initials variants; transparent Material avoids double-paint drift. |
| C16 | `BlabLanguageChip`: real Chip, original noninteractive styling. |
| C17 | `BlabUnreadBadge`: constrained custom count composition preserves old geometry. |
| C18 | `showBlabDialog`/`BlabConfirmationDialog`: native dialog routes, feature copy/busy policies retained. |
| C19 | Action sheets share Material route mechanism; content/eligibility stay feature-specific. |
| C20 | Existing app_messenger owns native ScaffoldMessenger/SnackBars; Undo/timing/route dismissal retained. |
| C21 | Existing shared skeletons/offline/inline errors retained; custom invite/message motion is not replaced by spinners. |
| C22 | `ChatListTile`: retained Material/InkWell composition using shared avatar/badge; no incompatible stock trailing geometry. |
| C23 | Chat header MenuAnchor and MenuItemButton entries, Back closes menu first. |
| C24 | `BlabAuthMethodButton.account/onboarding`: shared OutlinedButton; legacy SSO/provider availability retained. |
| C25 | `BlabSectionDivider`, `BlabSectionLabel` named variants; chat separators remain chat-specific. |

## Custom M01–M19

| ID | Current implementation / retention |
|---|---|
| M01 | `ChatHeader`, `ChatHeaderFrame`, identity/avatar/mode adapter; native AppBar frame, large-text typing reflow. |
| M02 | `ChatTimeline` extracted; list/state/read/pagination ownership unchanged. |
| M03 | `ChatMessageRow` extracted with existing gestures/selection/width/grouping. |
| M04 | `MessageBubble`, pure `MessageBubbleSurface`, lifecycle logic retained. |
| M05 | Existing MessageLearningContent/MessageText/InlineCorrectionText reused unchanged in ownership. |
| M06 | `ReplyPreview`, `ReplyThumbnail` extracted. |
| M07 | `ComposerReplyBar`, `ComposerEditBar` extracted; snapshots/cancel retained. |
| M08 | `ChatComposer` + ChatComposerInput/BlabComposerField and native send/attach controls. |
| M09 | MessageMeta/delivery status extracted; receipts/privacy preserved. |
| M10 | PhotoMessageView/OfflinePhotoPlaceholder/PhotoViewerScreen extracted; dark preview uses shared editing engine. |
| M11 | Existing reaction components reused; detail/emoji sheets use native Material presentation. |
| M12 | Existing MessageActionRow and pure eligibility retained; no generic context-menu replacement. |
| M13 | Existing MessageInteractionTarget/reply target gesture ownership retained. |
| M14 | Existing translation/arrival/delayed status motion retained; no message algorithm rewrite. |
| M15 | Existing custom anchored word popup retained; no exact stock replacement exists. |
| M16 | ChatDateDivider/ChatUnreadDivider/ChatLanguageMarker extracted. |
| M17 | ChatHistoryErrorState, MessageStatusNotice, UnsupportedLanguageNotice extracted; blocked/retry patterns retained. |
| M18 | ChatModeTipCard extracted; existing anchor/eligibility policy retained. |
| M19 | Existing grammatical-form chooser/note/alternatives retained, shared generic actions available; domain rules unchanged. |

## Verification and acceptance separation

- Full Flutter suite: **832 passed, 15 environment-dependent skips**. Analyzer and format clean. Baseline had 821 tests; four removed tests exercised only the removed unreachable subtitle renderer; replacement/native contracts add coverage.
- Backend unit: 136 passed. Owned disposable integration: 12 passed; three live-provider cases intentionally skipped. No production model credentials/data used.
- Separate Android baseline/candidate screenshots: Chats, Profile, Privacy, language editor, Edit Profile, both modes. Capsule static crops match exactly; language editor static region matches. Navigation shadow is intentional; native account Switch thumb/track differs.
- Android local account setup, invite/native-share return, used-invite recovery, two-client literal/Normal messages, gallery/photo/view/cache and incoming ACTION_SEND recipient/preview/send exercised. Predictive Back completed/cancelled recording retained.
- Widget/regression coverage covers all four locales at 100%/200% text, focused native destination semantics, keyboard/disabled capsule, border paint, guarded Back, form validation and existing product rules.
- **Not yet proven by this migration:** fresh physical-phone notification delivery, Google identity login, live translation quality, production signed update, distributed artifact hash. Existing integrations are preserved, not asserted newly certified.
- **Pending:** exact-head pinned repository CI, remaining journey review, owner screenshot/behavior acceptance, then integrated-main signed release/update/distribution evidence. Main/tester unchanged.
