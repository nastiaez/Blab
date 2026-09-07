# Blab landing page — design spec

Date: 2026-07-21
Domain: loveblab.com
Status: approved, pending spec review

## Purpose

Pre-launch waitlist page. App isn't on Play Store yet; page collects emails now, swaps the CTA to "Download" once the app ships (soft launch, closed-testing tester pool already secured — see `project_ship_fast_plan` memory).

## Audience

Couples/partners learning a language for each other — the sharpest slice of Blab's audience truth ("language is primary, relationship is motivation" — see `project_brand_personality` memory). Copy speaks to this directly, not to language learners in general.

## Brand voice for this page

Quiet-bold register: confidence through restraint, one strong move per section, not saturation everywhere. Explorer archetype — curious, dive-in energy — with Innocent undertones — no shame, safe to be bad at this. Reference brands: Aesop, MUBI, On Running, Granola.

Copy rules:
- Short, direct, dry wit. Mistakes are never the punchline.
- Sounds like: *"Nice. Try the next one."* Not like: *"Great job!! 🎉"*
- No corporate throat-clearing, no cute mascot energy, no forced exclamation points.

## Structure

One scrolling page, six sections, mirrors the existing Play Store graphic set 1:1 (`assets/screenshots-for-playstore/Blab-1.jpg` … `Blab-5.jpg`). No new visual concepts needed — reuse the illustration + real-UI style already produced.

1. **Hero** — background: terracotta `#D4694A`. Headline: **"Learn any language with someone you care about."** Illustrated couple-on-a-couch chat visual (`Blab-1.jpg` style). Primary CTA below headline: email field + "Notify me" button.
2. **Translate any chat** — split terracotta/sage diagonal background. Real phone UI, two-view mockup (`Blab-2.jpg` style): same conversation, two people's screens side by side, each in their own learning language.
3. **Tap any word to hear it** — sage `#5F7A52` background. Zoomed real-UI bubble with word popup + sound wave (`Blab-3.jpg` style).
4. **Invite someone you trust** — plum `#9A6A8C` background. Illustrated closed two-person loop (`Blab-4.jpg` style, drop the vampire cameo — that was a Play Store in-joke, not landing-page appropriate).
5. **Say the things that matter** — mustard `#C99846` background. Language pill list, flag + native-script name, full 10-language set (`Blab-5.jpg` style).
6. **CTA + footer** — repeat email capture. Footer: loveblab.com wordmark/logo, contact, copyright line. No nav bar anywhere on the page — single-purpose pitch, not a website.

## Visual system

Reuse existing tokens, no new design work:
- Color, ink, cream, line values from `claude_design/blab-theme.css` (`--orange #D4694A`, `--ink #1F3340`, `--cream #EFEBE2`, etc.)
- Section accent colors from the Play Store graphics spec (`assets/blab_playstore_graphics_spec.md`): terracotta, sage `#5F7A52`, plum `#9A6A8C`, mustard `#C99846`
- Typography: system stack (Roboto), per locked tech-spec decision #6 — no custom typeface
- Logo: `assets/blab-logo.svg`

## CTA mechanics

- Now: single email field + "Notify me" button per hero and footer sections.
- Post-launch: same slot swaps to a single "Download on Google Play" button, same position, same width — no layout change, just a content swap.
- No secondary CTAs, no tester-recruitment framing (testers already secured separately).

## Backend

Reuse the existing Supabase project (`bhzcexhebjszwyqvcsxs`, EU region — tech-spec Resolved Decision #5/#9). New table `waitlist_signups` (email, created_at), insert-only RLS policy, no read access from the client. Publishable/anon key used client-side, same pattern as the app.

## Build

Plain HTML + CSS + vanilla JS, no framework, no build step — same convention as `prototype.html`. Single static file (or a small set: index.html + one CSS + one JS), deployed to `loveblab.com` via Vercel. No server code beyond the Supabase insert call.

## Out of scope

- No analytics beyond what Supabase gives for free (signup count). Full analytics stack is an open tech-spec decision (#2) for the app itself, not this page.
- No blog, no changelog, no multi-page site. Single scrolling page only.
- No localization of the landing page copy itself (English only) — separate from in-app interface-language support.
- No A/B testing infrastructure for v1.

## Open questions

None — all product decisions were resolved during brainstorming (2026-07-21 session).
