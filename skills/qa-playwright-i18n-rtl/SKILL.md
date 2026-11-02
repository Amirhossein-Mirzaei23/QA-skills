---
name: qa-playwright-i18n-rtl
description: Browser-QA locale, RTL, theme via Playwright.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, i18n, rtl, theme]
    related_skills: [qa-playwright, qa-playwright-core]
---

## When to Use

Use when QA-testing multi-locale apps — RTL vs LTR layout, per-locale builds, dark/light
theme — especially after changes to shared components or layouts.

# QA-playwright i18n / RTL / theme

Prereq: load `qa-playwright-core`.

## Locale & RTL

1. **Open the page in each locale build** (Tabdeal: fa-ir, en-ae, ar-ae — different
   deployments or a locale switcher; use `browser_tabs` to run them side by side).
2. **Layout direction:** snapshot + screenshot per locale. In RTL builds check:
   - Text alignment, icon direction (arrows flipped), form label/input order.
   - No truncated/overlapping text — Arabic strings are often longer than the design's.
   - Numbers: Persian locale may render Persian digits; inputs must still accept them.
3. **No raw untranslated strings:** scan the snapshot text for English leaking into
   fa/ar pages (or vice versa) — a hardcoded string misses the translation file.
4. **Placeholders/aria-labels localized too**, not just visible text.

## Theme

5. **Toggle dark/light** (via the app's toggle or by setting the class on `<html>` with
   `browser_run_code_unsafe`: `async (page) => page.evaluate(() => document.documentElement.classList.add('dark'))`).
6. **Screenshot both themes** on the changed surfaces. Hunt for: invisible text
   (`text-grey-800` with no `dark:` counterpart), wrong-border/panel colors, images
   that assume white background.

## Report

Screenshot per locale × theme cell that the change touches. Report per hub conventions;
a missing-translation finding cites the exact leaked string and where it appears.
