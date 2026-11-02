---
name: qa-playwright-forms-auth
description: Browser-QA forms, auth flows, captcha via Playwright.
version: 1.0.0
author: Amir
license: proprietary
metadata:
  hermes:
    tags: [qa, playwright, forms, auth, captcha]
    related_skills: [qa-playwright, qa-playwright-core]
---

## When to Use

Use when QA-testing form flows — login, register, OTP, password reset, change password,
any submit-with-validation surface — including captcha behavior and error states.

# QA-playwright forms & auth

Prereq: load `qa-playwright-core`.

## Test matrix per form

1. **Happy path:** valid input → submit → expected navigation/state + expected network
   request with expected payload fields (check via `browser_network_requests`).
2. **Validation errors:** empty required fields, invalid format (bad phone/email),
   boundary values. Expect inline errors, no network call.
3. **Server rejection:** repeat on a flow the backend rejects (already-used email, wrong
   OTP) — expect the error UI, form still usable, spinner cleared.
4. **Submit guards:** double-click the submit button rapidly — expect one network
   request (button disabled/loading during flight).
5. **Enter-key submit:** focus the last field and press Enter — must behave exactly like
   the button click. This is where native-form-submit bypasses hide (captcha-less
   submits, double submits). Compare request count and payload between both paths.
6. **Captcha (if present):** token is attached to the request payload under the
   provider's key (`g-recaptcha-response` / `arcaptcha-token` / `tcaptcha-token`);
   closing the challenge clears the loading state; failure resets the captcha.

## Mechanics

- Fill fields with `browser_type` (per field) or `browser_fill_form` (batch).
- Press Enter via `browser_type {submit: true}` or `browser_press_key {key: "Enter"}`.
- Assert spinner/loading via fresh `browser_snapshot` (button disabled attribute).
- Assert requests: `browser_network_requests` — name, status, and (with
  `browser_run_code_unsafe` if needed) the POST body.

## Safety rules

- Never enter real credentials or real phone numbers. Ask the user for test accounts,
  or test only the client-side validation layer of auth forms.
- Never solve real captcha challenges at scale — one QA pass is fine, this is not a
  bypass exercise. If the challenge blocks testing, report and move on.

## Evidence & report

Screenshot each error state; record request method/URL/status/payload-diff for each
path. Report per the hub conventions.
