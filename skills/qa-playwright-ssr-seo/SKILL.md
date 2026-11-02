---
name: qa-playwright-ssr-seo
description: Verify SSR HTML and SEO tags via Playwright MCP.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, ssr, seo]
    related_skills: [qa-playwright, qa-playwright-core, nuxt-seo]
---

## When to Use

Use when verifying that a page server-renders its content and exposes correct SEO tags
(title, description, og:*, canonical) in the HTML that crawlers see, not just the
client-rendered DOM.

# QA-playwright SSR & SEO

Prereq: load `qa-playwright-core` for tool loading and the browser loop.

## What to check, and how

1. **SSR HTML contains dynamic content.** `curl -s <url>` (terminal) and look for the
   rendered text. In Playwright, `browser_navigate` then
   `browser_run_code_unsafe` with `async (page) => page.content()` also works but curl
   is the crawler's view — prefer curl.
   - Fail cause: data fetch is `lazy: true` / `server: false` / moved to `onMounted`.
2. **`<title>`, `meta description`, `og:title`, `og:image`, canonical in page source.**
   - `curl -s <url> | grep -E '<title>|name="description"|og:title|og:image|rel="canonical"'`
   - Fail cause: `useSeoMeta` getters read data that is not resolved at SSR time
     (un-awaited or lazy `useAsyncData`), or meta was dropped in a migration.
3. **Payload embeds the data.** Nuxt 3: look for `<script id="__NUXT_DATA__">` and
   confirm the data key has non-null content; Nuxt 2: `window.__NUXT__`.
4. **No flash of empty state on hard refresh.** Playwright:
   `browser_navigate` (fresh load) → immediate `browser_take_screenshot` → snapshot.
   Content should be in the first snapshot, not appear after a delay.
5. **Hydration warnings.** `browser_console_messages` after load — zero
   `Hydration mismatch` / `[Vue warn]: Hydration` entries.
   - Fail cause: initial `ref()` value differs from server-resolved data, or
     `Date.now()`/`Math.random()`/locale-formatted values rendered during SSR.
6. **Canonical matches the production URL** including params.

## Repo notes (Tabdeal)

- `/panel/**` and `/auth/**` are `ssr: false` — SSR/SEO checks are N/A (⏭️) there.
  Do not "fix" their missing SSR HTML.
- Public marketing routes are prerendered with `failOnError: true` — an SSR error is a
  red pipeline, treat any 500/partial HTML as a failure.
- Helper: the `nuxt-composition-migration-qa` skill ships
  `scripts/verify-ssr.sh <url>` — reuse it instead of hand-rolling greps.

## Report

Same format as the hub conventions: ✅/❌/⚠️/⏭️/🚫 table with the grep/HTML evidence per item.
