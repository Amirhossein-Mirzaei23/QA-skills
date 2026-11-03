---
name: qa-playwright
description: Browser QA with Playwright MCP — start at this hub.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, browser, testing]
    related_skills: [qa-playwright-core, qa-playwright-branch-features, qa-playwright-ssr-seo, qa-playwright-forms-auth, qa-playwright-i18n-rtl, qa-playwright-responsive, qa-browser-boundary]
---

## When to Use

Use whenever a task needs browser-based QA or testing of a running web app via the
Playwright MCP — pick a sub-skill from the table below and load `qa-playwright-core` too.

# QA-playwright — hub

Browser QA of running web apps through the Playwright MCP server. This is the index;
load the sub-skill that matches the task:

| Skill | Use when |
|---|---|
| `qa-playwright-core` | Any browser QA — the shared loop, tool reference, evidence rules. Load this one always. |
| `qa-playwright-branch-features` | "Test this branch", "QA the changes" — map a git diff to routes and test what changed. |
| `qa-playwright-ssr-seo` | Verify SSR HTML, title/description/og tags, canonical, payload. |
| `qa-playwright-forms-auth` | Forms, login/register/reset flows, captcha, validation errors. |
| `qa-playwright-i18n-rtl` | Locale matrix (fa/en/ar), RTL layout, dark/light theme. |
| `qa-playwright-responsive` | Viewport sizes, mobile emulation, touch, WebView-ish constraints. |
| `qa-browser-boundary` | Legacy-browser support: find the oldest verified passing browser / first verified failing major with real historical builds (`browser-boundary` CLI). |

## How tools are loaded

Playwright MCP tools are deferred in Hermes. Before using them, run
`tool_search(['playwright browser navigate snapshot click'])` then
`tool_describe([...])` for the exact tools needed. Core set:
`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`,
`browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`,
`browser_tabs`, `browser_fill_form`, `browser_wait_for`, `browser_run_code_unsafe`.

## Shared conventions (all sub-skills)

- Evidence before claims: every ✅/❌ in a report cites a snapshot line, console message,
  network request, or screenshot path. "Looks fine" is not evidence.
- Screenshots go to an evidence dir: `qa-evidence/<run-timestamp>/` in the repo root.
- The final deliverable is a markdown report `QA-REPORT-<branch-or-scope>.md` at repo
  root: summary line (PASS / PASS WITH NOTES / FAIL + counts), results table with
  ✅ verified pass / ❌ verified fail / ⚠️ needs human / ⏭️ N/A / 🚫 blocked, failures
  with evidence, follow-ups.
- Test, don't fix. Findings go in the report; never edit app code mid-QA.
- Never enter real credentials, payment UIs, or permission dialogs. Ask the user for
  test accounts or test only logged-out paths.
- If the dev server is not running, try to start it (project's dev command, background
  terminal, health-check before proceeding). If it cannot start, that is finding #1 —
  run the static checks that remain possible and mark runtime items 🚫.
