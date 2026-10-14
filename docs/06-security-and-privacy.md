# Security and privacy

Momentum stores planner data locally and uses a Cloudflare Worker only for external calendar connections. This document describes the current implementation.

**Last checked:** 2026-10-14

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Tasks: titles, descriptions, due dates and times, priorities, estimated durations, recurrence, and completion status | Local SQLite database; on Web, the database is stored in IndexedDB | The user through the app, and anyone with access to the same device or browser profile |
| Events: titles, start and end dates and times, all-day status, location text, notes, and recurrence | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Categories and completion records for recurring tasks | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Focus time: daily totals and totals by category, used by Insights | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Imported calendar items and linked-account details: provider, account name, email when available, provider address, account ID, category, source item IDs, and last sync time | The same local planner database; the Worker also stores account details needed for the connection in Cloudflare D1 | The user can view local records; the Worker and authorized service administrators can access server-side connection details |
| Published calendar feed links | Encrypted in Cloudflare D1; during local development, in Wrangler's local D1 database | The Worker decrypts a link when it fetches that calendar. Administrators with access to both the database and encryption key could also decrypt it. The Flutter app does not receive the stored link in API responses. |
| Calendar connection session ID | A `Secure`, `HttpOnly`, `SameSite=Lax` browser cookie and a session record in D1 | The browser sends the cookie to the Worker, which uses it to identify the connection. App JavaScript cannot read the cookie. Sessions expire after 30 days; authorized service administrators can access server-side session records. |
| Setup completion and the selected calendar view | Local app preferences through `shared_preferences` | The user through the app, and anyone with access to the same device or browser profile |

The local planner database is not encrypted by the app and is not automatically uploaded or synchronized between devices. On Web, clearing the site's browser storage can remove planner records and preferences. Calendar imports pass through the Worker before being saved locally; D1 stores connection information rather than a copy of the planner.

Calendar imports are read-only. Changes made in Momentum are not sent back to the provider. Disconnecting removes the provider connection and its encrypted feed link from D1, but imported items and local account details remain on the device. Disconnecting does not revoke the provider-issued feed link; if a link is exposed, revoke or regenerate it through the provider's calendar settings.

Momentum does not store provider passwords or use provider OAuth sign-in in the current connection flow. The user copies a published feed link from the provider and pastes it into Momentum. Event locations are entered or imported as text; the app does not track GPS location. Insights uses local focus records, and no AI planning service is connected.

## Secrets

The app does **not** load a root `.env` file. The feed-link encryption key is used by the Worker and must stay out of Flutter code and the public web build.

| Variable | What it is | Where it is declared |
| --- | --- | --- |
| `TOKEN_ENCRYPTION_KEY` | A private, randomly generated 32-byte key used to encrypt and decrypt published calendar feed links | Locally in `worker/.dev.vars`; on the hosted app, in Cloudflare Worker secrets |
| `APP_ORIGIN` and `ALLOWED_CANVAS_HOST` | The app address and optional permitted Canvas hostname; these are public configuration | Worker settings in `worker/wrangler.toml`; deployment overrides come from GitHub Actions variables |
| `CLOUDFLARE_API_TOKEN` | A private credential allowing the deployment workflow to update Cloudflare resources | GitHub Actions repository secrets; it is not used by the app in the browser |
| `CLOUDFLARE_ACCOUNT_ID` | Identifies the Cloudflare account used for deployment; it is not a password | GitHub Actions repository variables |

Git ignores `worker/.dev.vars` and local Wrangler state. The committed `worker/.dev.vars.example` contains a placeholder encryption key only. The current feed-link flow needs no Canvas, Google, or Microsoft OAuth credentials. Provider OAuth endpoints return `410 Gone`; the Worker has no active OAuth connection flow. GitHub Actions uses its Cloudflare deployment token, while the feed-link encryption key remains in Cloudflare Worker secrets.

Visitors can inspect the deployed JavaScript, static assets, and any configured backend URL. These contain public app resources and addresses, not the encryption key or the Cloudflare deployment token. Stored feed links stay on the Worker and are not returned in API responses. Setup details are in the [Worker guide](../worker/README.md).

## What protects the data on the service side

- The app uses Cloudflare D1. The browser accesses calendar connections through the Worker rather than connecting directly to D1.
- Connection queries use the current browser session. The `Secure`, `HttpOnly`, and `SameSite=Lax` cookie expires after 30 days.
- Published feed links are encrypted with AES-GCM before storage in D1. The encryption key is stored separately as a Worker secret.
- The Worker checks request origins for non-GET API requests, validates provider feed URLs, and imports calendars read-only. It also includes rate limits and scheduled cleanup of expired sessions and legacy OAuth state.
- Operational logs record information such as request paths, error types, and cleanup or rate-limit events. The logging statements do not include feed URLs or calendar item contents. Access to these logs is controlled through the hosting account.

## Checklist

- [x] Local Worker credentials and Wrangler state are ignored by Git, and `worker/.dev.vars.example` is committed
- [x] Review the full Git history for real keys, secrets, passwords, or tokens
- [x] No service account file, keystore or `service_role` key anywhere in the repo
- [x] Verify Worker session isolation, request-origin checks, feed URL validation, and feed-link encryption in the deployed environment
- [x] No real personal data in sample data, screenshots or the video
- [x] No course or university credentials anywhere
- [x] Anyone whose data appears in a test was asked first
