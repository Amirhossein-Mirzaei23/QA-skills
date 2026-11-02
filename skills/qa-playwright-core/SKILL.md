---
name: qa-playwright-core
description: Load first for any Playwright MCP browser QA task.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, browser]
    related_skills: [qa-playwright, qa-playwright-branch-features, qa-playwright-ssr-seo, qa-playwright-forms-auth, qa-playwright-i18n-rtl, qa-playwright-responsive]
---

## When to Use

Load this skill first in any qa-playwright session — it defines the tool-loading step,
the navigate/snapshot/act/observe loop, and the evidence rules the other sub-skills assume.

# QA-playwright core — the browser loop

## 0. Load tools

Playwright MCP tools are deferred: `tool_search(['playwright browser navigate snapshot click'])`,
then `tool_describe` the ones needed. Minimum set: `browser_navigate`, `browser_snapshot`,
`browser_click`, `browser_type`, `browser_take_screenshot`, `browser_console_messages`,
`browser_network_requests`, `browser_tabs`.

## 1. The loop (repeat per page/feature)

1. **Navigate:** `browser_navigate {url}`. First call auto-launches the headless browser.
2. **Snapshot:** `browser_snapshot` — accessibility tree where every interactive element
   has a `ref`. This is how you "see" the page; use it, not screenshots, to pick targets.
   Use `browser_find {query}` to locate one element cheaply on large pages.
3. **Act:** `browser_click {target: "<ref>", element: "human description"}`,
   `browser_type {target, text, submit?}`, `browser_fill_form` for multi-field forms,
   `browser_select_option` for dropdowns, `browser_press_key` for keyboard.
4. **Observe effects, not intentions:**
   - `browser_snapshot` again — did the DOM change as expected?
   - `browser_console_messages` — collect errors/warnings after each interaction.
   - `browser_network_requests` — did the expected API call fire? Correct payload?
5. **Evidence:** `browser_take_screenshot {scale: "css", filename: "qa-evidence/<run>/NN-<slug>.png"}`
   at meaningful states (before/after action, error states).

## 2. Pitfalls

- Refs go stale after navigation/re-render — re-snapshot before each act on a changed page.
- `browser_take_screenshot` is for eyes only; you cannot click from a screenshot. Snapshot for actions.
- SPA route changes may not fire `browser_navigate`'s implicit wait — follow with
  `browser_wait_for {text: "<known content>"}` or a fresh snapshot before asserting.
- Dialogs (confirm/alert) need `browser_handle_dialog`; auth/paywall prompts: stop and ask the user.
- `browser_run_code_unsafe` runs arbitrary Playwright JS in the server process (RCE-equivalent).
  Use only for what high-level tools cannot do (exact payload assertion, loops), keep snippets small.

## 3. Multi-state testing

`browser_tabs {action: "new", isolatedContext: "guest"}` gives tabs with separate cookie
storage — run logged-out and logged-in (or locale A/B) states side by side without
clobbering sessions.

## 4. Report

Write `QA-REPORT-<scope>.md` at repo root per the conventions in `qa-playwright` (hub):
summary line, results table (✅/❌/⚠️/⏭️/🚫 + evidence), failures, follow-ups.
Never mark ✅ without a cited observation.
