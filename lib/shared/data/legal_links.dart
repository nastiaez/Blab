import 'invite_host.dart';

/// Public URLs for the hosted Privacy Policy + Terms of Use. Served from
/// the same host as invite links (`web/privacy.html`, `web/terms.html`).
/// Required by the Play Store listing + the in-app legal links. Step 3.5.
const String kPrivacyPolicyUrl = 'https://$kInviteHost/privacy.html';
const String kTermsUrl = 'https://$kInviteHost/terms.html';
