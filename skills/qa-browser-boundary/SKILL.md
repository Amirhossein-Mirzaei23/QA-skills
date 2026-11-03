---
name: qa-browser-boundary
description: Measure browser support boundaries with browser-boundary.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, browser-boundary, legacy-browser, compatibility]
    related_skills: [qa-playwright, qa-playwright-core]
---

## When to Use

Use when the task is legacy-browser compatibility: "what is the oldest browser that
runs this app", "verify our Chrome 100+ policy", "test these exact browser majors",
or a release-gate compatibility scan. Runs real historical browser binaries via the
`browser-boundary` CLI — no User-Agent spoofing.

Don't use for: interactive functional QA of a running app (use `qa-playwright*`
skills), or static feature-target lists (Browserslist answers a different question).

# QA-browser-boundary — verified compatibility boundary

## Prerequisites

- Node 18+. Historical scans (Linux x64 validated) need the optional deps:
  `npm install -g browser-boundary playwright @puppeteer/browsers selenium-webdriver`
  then once: `npx browser-boundary install` (downloads Chromium/Firefox/WebKit
  builds — hundreds of MB, several minutes).
- `npx` works instead of a global install; `quick` and `--strategy latest` need only
  the current Playwright Chromium, no optional deps.

## Procedure — work in stages, stop when the question is answered

1. **Stage 1 — current-browser proof (seconds):**
   `terminal(command="npx browser-boundary quick <url>")`
   Headless, current Chromium, one URL. Output is explicitly labeled a
   current-browser proof — it says nothing about old browsers.
   *Done when:* it prints PASS or FAIL for the current build.
2. **Stage 2 — verify exact majors from the support policy:**
   `terminal(command="npx browser-boundary <url> --engines chromium --versions 120,115 --headless --timeout 60000")`
   One engine per run; versions run in the order given. Use this when the policy
   names versions ("works on Chrome 120+").
   *Done when:* each requested major shows verified PASS/FAIL/inconclusive.
3. **Stage 3 — find the boundary (oldest verified passing + first verified failing):**
   `terminal(command="npx browser-boundary <url> --engines chromium,firefox --headless --timeout 60000")`
   Binary strategy steps down by 10 majors then binary-searches the gap. Only run
   when the user actually wants the boundary — it downloads many builds.
   *Done when:* the summary table shows both boundary points, or every remaining
   version is explained as inconclusive.
4. **App readiness (SPAs):** a loaded page is not a working app. Require hydration:
   `--readiness-selector '#app' --readiness-selector '[data-hydrated]' --readiness-mode all`
   (repeat `--readiness-selector`; `any`/`all` mode). Without this, an old browser
   can "pass" on an empty unhydrated shell.
5. **Multiple routes:** `--pages /,/login,/dashboard --base-url <url>` — the
   positional URL is always included.
6. **Read evidence:** `reports/compatibility.md` for the human summary,
   `reports/compatibility.json` for per-version verdicts and failure reasons,
   `reports/artifacts/` for screenshots/traces/logs. Default output dir `./reports`;
   change with `-o <dir>`. Cite these files in the report — never paraphrase a
   verdict without opening compatibility.json.

## Exit codes (gate on these, then verify in JSON)

- 0 — no verified failure (inconclusive engines may exist — not an all-pass).
- 1 — at least one verified compatibility failure.
- 2 — invalid configuration. 3 — infrastructure failure (or nothing verified at all).

For strict gating, read compatibility.json and treat unexpected `inconclusive`
entries as their own failure.

## Reading the verdicts (the rules that matter)

- Only `oldestVerifiedPassing` and `firstVerifiedFailing` are claims. Never infer
  that everything below the failing version fails, or above the passing passes.
- `inconclusive` = could not test (binary unavailable, launch failure, WAF stall).
  It is never a pass or a fail — do not convert it in downstream summaries.
- A cluster of inconclusives points at the runner, not the site: try
  `--strategy latest` first, then one engine, then a few `--versions`. Missing
  shared libraries on modern Linux keep old builds inconclusive — report that, and
  suggest an older-container run, rather than calling it a site failure.
- Coverage: Chromium majors 67–current, Firefox 52–current, WebKit current build
  only. WebKit results are playwright-revisions, **not Safari versions** — report
  them as such and mark historical Safari 🚫 (needs macOS or a device cloud).

## Pitfalls

- Browsers open headed by default — always pass `--headless` from an agent.
- Historical scans silently skip without `@puppeteer/browsers` + `selenium-webdriver`.
- `--versions`/`--exact-version` require exactly one engine; WebKit has no
  historical versions.
- Old Chromium may need obsolete host libs (e.g. libgconf) — stays inconclusive.
- Cache `~/.cache/browser-boundary/` grows to multiple GB; disposable
  (`rm -rf`), but never while a scan is running.
- Only scan sites the user owns or is authorized to test — confirm the target URL
  is theirs before scanning; WAFs/anti-bot on third-party sites produce junk
  inconclusives.
- Do not clear Playwright's browser cache mid-task; re-downloading costs minutes.

## Report

Deliverable: `QA-REPORT-<scope>.md` at repo root (same conventions as
`qa-playwright`). Include: a per-engine boundary table (oldest verified passing /
first verified failing / confidence), a version-verdict table citing
compatibility.json lines, inconclusive versions with their recorded reasons, the
report's Suggested Browserslist target when present, and follow-ups. Save key
artifacts by referencing the report dir; copy failure screenshots into
`qa-evidence/<run-timestamp>/` when the repo conventions require it.
