---
name: qa-playwright-responsive
description: Browser-QA viewports and mobile via Playwright.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, responsive, mobile, viewport]
    related_skills: [qa-playwright, qa-playwright-core]
---

## When to Use

Use when QA-testing responsive layouts — desktop/tablet/mobile breakpoints, mobile-web
behavior, and Android WebView-style constraints — after UI changes.

# QA-playwright responsive

Prereq: load `qa-playwright-core`.

## Viewport matrix

1. Test at minimum: 375×667 (mobile), 768×1024 (tablet), 1440×900 (desktop). Set via
   `browser_run_code_unsafe`: `async (page) => page.setViewportSize({ width: 375, height: 667 })`.
2. **Screenshot each breakpoint** on the changed surfaces.
3. **Hunt for:** horizontal overflow (scrollbar at mobile width), content behind the
   fold that should be visible, tap targets too small, sticky elements covering inputs,
   tables that don't collapse, fixed headers hiding content when the on-screen keyboard
   would open.

## Mobile-web specifics

4. **Touch behavior:** tap (not hover) reveals menus/tooltips — hover-only affordances
   break on touch.
5. **Input types:** numeric fields should trigger numeric keyboards (`inputmode`) —
   check the snapshot's input attributes.
6. **WebView constraint (Tabdeal):** features behind the Android bridge must fail closed
   on old app versions; the bridge returns JSON string or `undefined`, never boolean.
   Browser QA can only verify the web fallback path renders — mark native-path items ⚠️.

## Report

Screenshot per breakpoint × surface. Report per hub conventions.
