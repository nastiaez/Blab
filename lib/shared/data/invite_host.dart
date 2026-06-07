/// Host that serves invite URLs + Android App Link verification. The
/// HTTPS URLs are the public share format (`https://<host>/i/<token>`)
/// because custom-scheme URLs aren't auto-detected as tappable links
/// by most messaging apps. Deferred upgrade: swap this for a custom
/// domain like `blab.aswin.sh` / `getblab.app` before public launch
/// (Step 3.7 in `tasks/progress.md`).
const String kInviteHost = 'blab-gray.vercel.app';
