---
name: qa-playwright-branch-features
description: Test a git branch's code changes in the browser.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, git, branch, testing]
    related_skills: [qa-playwright, qa-playwright-core, qa-playwright-forms-auth]
---

## When to Use

Use when asked to "test this branch", "QA the changes", or verify a feature works based on
code changes vs a base ref (default `origin/main`). Pairs well with a red/blue code review
(e.g. `.agents/tabdeal-reviewer.md` in the Tabdeal repo): review findings become test cases.

## 1. Establish scope (terminal, read-only)

1. `git status` — note uncommitted work; test the working tree as-is.
2. `git log <base>..HEAD --oneline` — the intent list: each commit names a behavior that should work.
3. `git diff <base>...HEAD --stat` — affected files.
4. `git diff <base>...HEAD -- <file>` per key file when writing test cases — read the actual
   changed hunks. Every changed conditional (flag, role, error branch) becomes at least one
   test case: happy path AND the fail path.

## 2. Map changes to routes

- `pages/**/*.vue` → URL directly (file-based routing). Dynamic segments: fill a realistic value.
- Changed `components/**` → owning route: `rg -n "<ComponentName" pages/` and walk up consumers
  until a page (or layout used by one) is found. A component used on many routes: pick the
  1–2 highest-traffic routes and note the rest as covered-by-proxy.
- New/changed API seams (`services/api/*`, stores fetching) → note the expected network
  request name+payload to assert later via `browser_network_requests`.

## 3. Write the test matrix first

Table before any browser step: feature → route → steps → expected observable result
(DOM change / network call / navigation / state). Derived from the diff, not from the UI.

## 4. Execute (see qa-playwright-core for the loop)

Per route: navigate → snapshot → console → run each test case → assert via snapshot diff,
console messages, network requests, screenshots. Use `browser_tabs` + `isolatedContext`
for state variants (guest vs user, flag on vs off when flag is client-readable).

Edge priorities: the exact scenario the branch's commits claim to fix; error branches
touched by the diff; empty/invalid input; double-submit.

## 5. Report

`QA-REPORT-<branch>.md` at repo root: summary line, per-test-case table
(feature | route | action | expected | observed | status+evidence), failures with
console/network/screenshot evidence, follow-ups (anything needing prod-only or manual check).

## Guardrails

- If the branch does not build/serve, report it as finding #1 and stop runtime QA.
- Test, don't fix. Do not commit, do not edit app code.
- Login-gated features: ask for a test account; never use real credentials.
