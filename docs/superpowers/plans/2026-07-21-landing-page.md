# Blab Landing Page (loveblab.com) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `web/index.html` stub with a pre-launch waitlist landing page for loveblab.com, reusing the existing Play Store graphics as the scroll story and the existing Supabase project for email capture.

**Architecture:** Single static HTML file (inline CSS + vanilla JS, no framework, no build step), matching the existing `web/` convention (`i.html`, `privacy.html`, `terms.html` are all single files). Deployed to the existing Vercel project (`blab`, already linked in `web/.vercel`, currently live at `blab-gray.vercel.app`). Signups write directly to a new Supabase table via a plain `fetch()` POST to the PostgREST REST endpoint — no SDK, no CDN script dependency.

**Tech Stack:** HTML5, CSS (no preprocessor), vanilla JS (`fetch`), Supabase Postgres + PostgREST (existing project `bhzcexhebjszwyqvcsxs`), Vercel static hosting.

## Global Constraints

- No framework, no build step — plain HTML/CSS/JS only, one file for the page (`web/index.html`), matching `prototype.html` and the rest of `web/`.
- Brand colors (from `claude_design/blab-theme.css` and `assets/blab_playstore_graphics_spec.md`): terracotta `#D4694A`, sage `#5F7A52`, plum `#9A6A8C`, mustard `#C99846`, ink `#1F3340`, cream `#EFEBE2`.
- System font stack only — no custom typeface (tech-spec Resolved Decision #6).
- Copy voice: quiet-bold, short, dry, never corporate/cute (see `docs/superpowers/specs/2026-07-21-landing-page-design.md` § Brand voice).
- Hero headline is fixed: **"Learn any language with someone you care about."**
- Contact email in footer: `me@aswin.sh` (matches `web/privacy.html` / `web/terms.html`).
- Existing `web/vercel.json` rewrites (`/i/:token` → `i.html`) and `.well-known/assetlinks.json` headers must keep working — do not modify `vercel.json`.
- Supabase project: URL `https://bhzcexhebjszwyqvcsxs.supabase.co`, publishable key `sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE` (from `lib/shared/data/supabase_config.dart` — client-safe, RLS enforces access).
- Any step that pushes a migration to the remote Supabase project or deploys to production Vercel is a shared-system change — confirm with the user immediately before running it, even though it's written as a plan step.

---

### Task 1: Copy landing page image assets into `web/`

The Vercel project root is `web/` (see `web/.vercel/project.json`), so any asset the page references must live inside `web/`, not at the repo root.

**Files:**
- Create: `web/assets/img/section-learn-by-chatting.jpg` (copy of `assets/screenshots-for-playstore/Blab-1.jpg`)
- Create: `web/assets/img/section-translate.jpg` (copy of `assets/screenshots-for-playstore/Blab-2.jpg`)
- Create: `web/assets/img/section-tap-word.jpg` (copy of `assets/screenshots-for-playstore/Blab-3.jpg`)
- Create: `web/assets/img/section-invite.jpg` (copy of `assets/screenshots-for-playstore/Blab-4.jpg`)
- Create: `web/assets/img/section-languages.jpg` (copy of `assets/screenshots-for-playstore/Blab-5.jpg`)
- Create: `web/assets/img/blab-logo.svg` (copy of `assets/blab-logo.svg`)

**Interfaces:**
- Produces: five JPGs + one SVG at `web/assets/img/*`, referenced by exact filename in Task 3's HTML.

- [ ] **Step 1: Create the target directory and copy the five section images**

```bash
mkdir -p web/assets/img
cp assets/screenshots-for-playstore/Blab-1.jpg web/assets/img/section-learn-by-chatting.jpg
cp assets/screenshots-for-playstore/Blab-2.jpg web/assets/img/section-translate.jpg
cp assets/screenshots-for-playstore/Blab-3.jpg web/assets/img/section-tap-word.jpg
cp assets/screenshots-for-playstore/Blab-4.jpg web/assets/img/section-invite.jpg
cp assets/screenshots-for-playstore/Blab-5.jpg web/assets/img/section-languages.jpg
cp assets/blab-logo.svg web/assets/img/blab-logo.svg
```

- [ ] **Step 2: Verify all six files landed**

Run: `ls -la web/assets/img/`
Expected: six files listed — `section-learn-by-chatting.jpg`, `section-translate.jpg`, `section-tap-word.jpg`, `section-invite.jpg`, `section-languages.jpg`, `blab-logo.svg`.

- [ ] **Step 3: Commit**

```bash
git add web/assets/img/
git commit -m "assets(web): copy landing page section images from Play Store set"
```

---

### Task 2: Waitlist signups table + RLS

Follows the RLS pattern already used in `supabase/migrations/20260607000003_invites.sql`: table locked down by default, explicit policy for exactly the access the client needs — here, anonymous insert only, no read.

**Files:**
- Create: `supabase/migrations/20260721000001_waitlist_signups.sql`

**Interfaces:**
- Produces: table `public.waitlist_signups (id uuid, email text, created_at timestamptz)`, reachable from an unauthenticated client only via `POST /rest/v1/waitlist_signups` (insert). No select/update/delete from `anon`.

- [ ] **Step 1: Write the migration**

```sql
-- Pre-launch waitlist signups from the loveblab.com landing page.
-- Public, unauthenticated form — insert-only, no read access from the
-- client. A basic email-shape check constraint keeps out obvious junk;
-- this is not full RFC validation, just a spam-resistance floor.

create table public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null check (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  created_at timestamptz not null default now()
);

create unique index waitlist_signups_email_idx on public.waitlist_signups (lower(email));

alter table public.waitlist_signups enable row level security;

create policy waitlist_signups_insert_anon on public.waitlist_signups
  for insert to anon with check (true);
create policy waitlist_signups_no_select on public.waitlist_signups
  for select to anon using (false);
create policy waitlist_signups_no_update on public.waitlist_signups
  for update to anon using (false);
create policy waitlist_signups_no_delete on public.waitlist_signups
  for delete to anon using (false);
```

- [ ] **Step 2: Push the migration to the remote project**

**Confirm with the user before running this** — it changes the live Supabase project.

Run: `supabase db push`
Expected: output lists `20260721000001_waitlist_signups.sql` as applied, no errors.

- [ ] **Step 3: Verify insert works and select is blocked, via the public REST API**

Run (replace nothing — these are the real project URL + publishable key):

```bash
curl -i -X POST 'https://bhzcexhebjszwyqvcsxs.supabase.co/rest/v1/waitlist_signups' \
  -H 'apikey: sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE' \
  -H 'Authorization: Bearer sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE' \
  -H 'Content-Type: application/json' \
  -H 'Prefer: return=minimal' \
  -d '{"email":"plan-verify-test@example.com"}'
```

Expected: `HTTP/2 201`, empty body.

```bash
curl -i 'https://bhzcexhebjszwyqvcsxs.supabase.co/rest/v1/waitlist_signups?select=*' \
  -H 'apikey: sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE' \
  -H 'Authorization: Bearer sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE'
```

Expected: `HTTP/2 200` with an **empty JSON array `[]`** — proves the no-select policy holds even though insert succeeded.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260721000001_waitlist_signups.sql
git commit -m "feat(supabase): add waitlist_signups table, insert-only RLS"
```

---

### Task 3: Build the landing page

Full rewrite of `web/index.html`. One file: markup, inline `<style>`, inline `<script>`. Seven sections in scroll order: hero (text-only, no baked headline image — see rationale below) → 5 story sections (full-bleed reused graphics) → CTA/footer.

**Rationale for a text-only hero:** the five source JPGs each have their headline baked into the pixels. Section 1's original headline ("Learn by chatting") differs from the approved hero headline ("Learn any language with someone you care about"), and there's no clean way to swap baked-in image text without re-exporting the graphic. Cropping the image via CSS to hide the old headline risks clipping the illustration unpredictably across viewports. Simplest correct fix: hero is headline + subhead + CTA on a solid terracotta field (no image), and `section-learn-by-chatting.jpg` becomes the first story section right below it, keeping its own original headline — which still reads fine as supporting copy, not competing with the hero.

**Files:**
- Modify: `web/index.html` (full replacement)

**Interfaces:**
- Consumes: image files from Task 1 (`web/assets/img/*`), Supabase URL + publishable key (Global Constraints), table `waitlist_signups` from Task 2.
- Produces: the deployed page's DOM — two `<form class="waitlist-form">` elements (hero + footer), each with an `<input type="email" required>` and a submit button; both wired to the same `attachWaitlistForm` JS function.

- [ ] **Step 1: Write the full file**

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Blab — Learn any language with someone you care about</title>
    <meta name="description" content="Blab is a chat app that translates as you talk. Learn any language with the one person you actually want to talk to." />
    <meta property="og:title" content="Blab — Learn any language with someone you care about" />
    <meta property="og:description" content="A chat app that translates as you talk. No lessons, no streaks — just real conversations." />
    <meta property="og:image" content="https://loveblab.com/assets/img/section-learn-by-chatting.jpg" />
    <meta property="og:type" content="website" />
    <meta name="twitter:card" content="summary_large_image" />
    <link rel="icon" href="/assets/img/blab-logo.svg" type="image/svg+xml" />
    <style>
      :root {
        color-scheme: light;
        --terracotta: #d4694a;
        --sage: #5f7a52;
        --plum: #9a6a8c;
        --mustard: #c99846;
        --ink: #1f3340;
        --cream: #efebe2;
      }
      * { box-sizing: border-box; }
      html, body {
        margin: 0;
        padding: 0;
        background: var(--cream);
        color: var(--ink);
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      }
      h1, h2, p { margin: 0; }
      .sr-only {
        position: absolute;
        width: 1px; height: 1px;
        padding: 0; margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        white-space: nowrap;
        border: 0;
      }
      section {
        display: flex;
        flex-direction: column;
        align-items: center;
        text-align: center;
        padding: 64px 24px;
      }
      .hero {
        background: var(--terracotta);
        color: white;
        padding: 88px 24px 64px;
      }
      .hero .logo {
        height: 28px;
        margin-bottom: 40px;
      }
      .hero h1 {
        font-size: 40px;
        line-height: 1.15;
        letter-spacing: -0.5px;
        max-width: 380px;
      }
      .hero .promise {
        margin-top: 20px;
        font-size: 17px;
        line-height: 1.5;
        max-width: 340px;
        opacity: 0.92;
      }
      .story-section {
        padding: 0;
      }
      .story-section img {
        display: block;
        width: 100%;
        max-width: 480px;
        height: auto;
      }
      .story-section.learn-by-chatting { background: var(--terracotta); }
      .story-section.translate { background: linear-gradient(135deg, var(--terracotta) 45%, var(--sage) 45%); }
      .story-section.tap-word { background: var(--sage); }
      .story-section.invite { background: var(--plum); }
      .story-section.languages { background: var(--mustard); }
      .waitlist-form {
        margin-top: 32px;
        display: flex;
        flex-direction: column;
        gap: 12px;
        width: 100%;
        max-width: 320px;
      }
      .waitlist-form input[type="email"] {
        padding: 14px 16px;
        border-radius: 12px;
        border: none;
        font-size: 16px;
        width: 100%;
      }
      .waitlist-form button {
        padding: 14px 16px;
        border-radius: 12px;
        border: none;
        background: var(--ink);
        color: white;
        font-size: 16px;
        font-weight: 600;
        cursor: pointer;
      }
      .waitlist-form button:disabled {
        opacity: 0.6;
        cursor: default;
      }
      .waitlist-form .form-message {
        font-size: 14px;
        min-height: 20px;
      }
      .cta-section {
        background: var(--cream);
        padding: 72px 24px 48px;
      }
      .cta-section h2 {
        font-size: 28px;
        max-width: 320px;
      }
      footer {
        padding: 32px 24px 48px;
        text-align: center;
        font-size: 13px;
        color: #6d6961;
      }
      footer a {
        color: var(--ink);
      }
      footer .footer-logo {
        height: 18px;
        margin-bottom: 12px;
        opacity: 0.7;
      }
    </style>
  </head>
  <body>
    <section class="hero">
      <img class="logo" src="/assets/img/blab-logo.svg" alt="Blab" />
      <h1>Learn any language with someone you care about</h1>
      <p class="promise">Blab first. Fluency follows. You already know enough to start.</p>
      <form class="waitlist-form" data-waitlist-form>
        <input type="email" required placeholder="you@wherever.com" aria-label="Email address" />
        <button type="submit">Notify me</button>
        <p class="form-message" role="status"></p>
      </form>
    </section>

    <section class="story-section learn-by-chatting">
      <h2 class="sr-only">Learn by chatting</h2>
      <img src="/assets/img/section-learn-by-chatting.jpg" width="1080" height="1920" loading="lazy" alt="Two people texting each other on a couch, messages shown in two languages" />
    </section>

    <section class="story-section translate">
      <h2 class="sr-only">Translate any chat</h2>
      <img src="/assets/img/section-translate.jpg" width="1080" height="1920" loading="lazy" alt="Two phone screens side by side showing the same conversation, one in German, one in Ukrainian" />
    </section>

    <section class="story-section tap-word">
      <h2 class="sr-only">Tap any word to hear it</h2>
      <img src="/assets/img/section-tap-word.jpg" width="1080" height="1920" loading="lazy" alt="A finger tapping a word in a French message bubble, with a popup showing the word, pronunciation, and English meaning" />
    </section>

    <section class="story-section invite">
      <h2 class="sr-only">Invite someone you trust</h2>
      <img src="/assets/img/section-invite.jpg" width="1080" height="1920" loading="lazy" alt="Three illustrated people connected by lines, representing an invite-only chat" />
    </section>

    <section class="story-section languages">
      <h2 class="sr-only">Say the things that matter</h2>
      <img src="/assets/img/section-languages.jpg" width="1080" height="1920" loading="lazy" alt="A list of ten languages, each showing how to say 'I love you' with its flag" />
    </section>

    <section class="cta-section">
      <h2>Blab launches soon.</h2>
      <form class="waitlist-form" data-waitlist-form>
        <input type="email" required placeholder="you@wherever.com" aria-label="Email address" />
        <button type="submit">Notify me</button>
        <p class="form-message" role="status"></p>
      </form>
    </section>

    <footer>
      <img class="footer-logo" src="/assets/img/blab-logo.svg" alt="Blab" />
      <p>© 2026 Blab · <a href="mailto:me@aswin.sh">me@aswin.sh</a> · <a href="/privacy.html">Privacy</a> · <a href="/terms.html">Terms</a></p>
    </footer>

    <script>
      const SUPABASE_URL = "https://bhzcexhebjszwyqvcsxs.supabase.co";
      const SUPABASE_ANON_KEY = "sb_publishable_vpiuolyBJ5X9-bi8IEvg8g_Hif7k_lE";

      function attachWaitlistForm(form) {
        const input = form.querySelector('input[type="email"]');
        const button = form.querySelector("button");
        const message = form.querySelector(".form-message");

        form.addEventListener("submit", async (event) => {
          event.preventDefault();
          const email = input.value.trim();
          if (!email) return;

          button.disabled = true;
          message.textContent = "Adding you…";

          try {
            const res = await fetch(`${SUPABASE_URL}/rest/v1/waitlist_signups`, {
              method: "POST",
              headers: {
                apikey: SUPABASE_ANON_KEY,
                Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
                "Content-Type": "application/json",
                Prefer: "return=minimal",
              },
              body: JSON.stringify({ email }),
            });

            if (res.ok) {
              form.reset();
              input.style.display = "none";
              button.style.display = "none";
              message.textContent = "You're on the list. Talk soon.";
            } else if (res.status === 409) {
              message.textContent = "You're already on the list.";
              button.disabled = false;
            } else {
              message.textContent = "Something went wrong. Try again?";
              button.disabled = false;
            }
          } catch (err) {
            message.textContent = "Something went wrong. Try again?";
            button.disabled = false;
          }
        });
      }

      document.querySelectorAll("[data-waitlist-form]").forEach(attachWaitlistForm);
    </script>
  </body>
</html>
```

- [ ] **Step 2: Open the page locally and check every section renders**

Run: `open web/index.html`
Expected: hero (terracotta, headline, email field, "Notify me") → five full-bleed story images in order → CTA section → footer with working Privacy/Terms links. No broken images (check each `<img>` loads — broken image icon means Task 1's filenames don't match).

- [ ] **Step 3: Submit a real test signup and confirm it lands**

In the open page, type a real-looking email into the hero form and click "Notify me".
Expected: button disables, message changes to "Adding you…" then "You're on the list. Talk soon."; browser dev tools Network tab shows a `POST .../waitlist_signups` request with status `201`.

Submit the same email again in the footer form.
Expected: message shows "You're already on the list." (the unique index from Task 2 rejects the duplicate with `409`).

- [ ] **Step 4: Commit**

```bash
git add web/index.html
git commit -m "feat(web): build loveblab.com waitlist landing page"
```

---

### Task 4: Point loveblab.com at the deployed page

This is a dashboard + DNS action, not code. Walking through it here so it's tracked in the same plan.

**Confirm with the user before running the deploy command** — it pushes to the production Vercel deployment that Play Store listing links may already reference.

- [ ] **Step 1: Deploy the updated `web/` directory to production**

Run (from the `web/` directory):
```bash
cd web && vercel --prod
```
Expected: output ends with a production URL (`blab-gray.vercel.app` or similar) returning the new page — confirm by opening the printed URL.

- [ ] **Step 2: Add the custom domain in Vercel**

Tell the user:
1. Open vercel.com and go to the **blab** project.
2. Click **Settings → Domains**.
3. Type `loveblab.com`, click **Add**.
4. Vercel shows one or two DNS records (usually an A record and/or a CNAME). Copy those exactly.

- [ ] **Step 3: Point the domain's DNS at Vercel**

Tell the user:
1. Open the site where `loveblab.com` was bought (the domain registrar).
2. Find **DNS settings** for the domain.
3. Add the record(s) Vercel showed in Step 2, exactly as shown.
4. Save. DNS changes can take a few minutes up to a few hours to go live.

- [ ] **Step 4: Verify the domain resolves to the page**

Run: `curl -I https://loveblab.com`
Expected: `HTTP/2 200` (may need to wait and retry if DNS hasn't propagated yet).

- [ ] **Step 5: Update the plan/progress docs**

Mark this plan's tasks complete and flip the corresponding `tasks/progress.md` step to `[x]` once Step 4 above passes.

---

## Self-review notes

- **Spec coverage:** hero copy ✓ (Task 3), 5 story sections in the approved order ✓ (Task 3), email-only CTA swappable to a download button later ✓ (form markup is a self-contained `<form>` block, trivial to swap for a link), Supabase-backed signups ✓ (Task 2), no-framework static build ✓ (Task 3), Vercel deploy on `loveblab.com` ✓ (Task 4). No spec section without a task.
- **Placeholder scan:** none — every step has literal file contents or literal commands with expected output.
- **Type/naming consistency:** `data-waitlist-form` attribute and `attachWaitlistForm()` name used identically in Task 3's markup and script; `waitlist_signups` table/column names match between Task 2's SQL and Task 3's `fetch` body (`{ email }`) and Global Constraints.
