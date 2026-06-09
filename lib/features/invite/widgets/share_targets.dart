// Pure builders for the share-invite sheet. Kept side-effect-free so the
// URI shapes can be unit-tested without touching the platform. PRD US-009.

/// One-line message shared into other apps alongside the invite link.
String inviteShareText(String link) =>
    "Let's chat and learn languages together on Blab — tap to join: $link";

/// Short message for channels that carry the link as a separate field
/// (e.g. Telegram's `url` + `text`).
const String inviteShareBlurb =
    "Let's chat and learn languages together on Blab.";

/// Opens WhatsApp (app if installed, web otherwise) with the invite
/// pre-filled. `wa.me` needs no phone number for a share-style compose.
Uri whatsAppShareUri(String link) => Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(inviteShareText(link))}',
    );

/// Opens Telegram's share dialog with the link + blurb pre-filled.
Uri telegramShareUri(String link) => Uri.parse(
      'https://t.me/share/url'
      '?url=${Uri.encodeComponent(link)}'
      '&text=${Uri.encodeComponent(inviteShareBlurb)}',
    );

/// Opens the default mail composer with subject + body pre-filled.
/// `Uri.encodeComponent` keeps spaces as `%20` (not `+`) so every mail
/// client renders the body correctly.
Uri emailShareUri(String link) => Uri.parse(
      'mailto:'
      '?subject=${Uri.encodeComponent("Join me on Blab")}'
      '&body=${Uri.encodeComponent(inviteShareText(link))}',
    );
