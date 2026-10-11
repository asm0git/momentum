# Security and privacy

Momentum stores planner data locally and uses a Cloudflare Worker only for external calendar connections. This document describes the current implementation.

**Last checked:** 2026-10-11

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Tasks: titles, descriptions, due dates and times, priorities, estimated durations, recurrence, and completion status | Local SQLite database; on Web, the database is stored in IndexedDB | The user through the app, and anyone with access to the same device or browser profile |
| Events: titles, start and end dates and times, all-day status, location text, notes, and recurrence | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Categories and completion records for recurring tasks | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Focus time: daily totals and totals by category, used by Insights | The same local planner database | The user through the app, and anyone with access to the same device or browser profile |
| Imported calendar items and linked-account details: provider, account name, email when available, provider address, account ID, category, source item IDs, and last sync time | The same local planner database; the Worker also stores account details needed for the connection in Cloudflare D1 | The user can view local records; the Worker and authorized service administrators can access server-side connection details |
| Calendar access and refresh tokens | Encrypted in Cloudflare D1; during local development, in Wrangler's local D1 database | The Worker can decrypt them to fetch calendar data. Administrators with access to both the database and encryption key could also decrypt them. The Flutter app does not receive these tokens. |
| Calendar session ID and temporary sign-in verification records | Session ID in a browser cookie; session and OAuth verification records in D1 | The browser sends the cookie to the Worker, which uses it to identify the connection. App JavaScript cannot read the HttpOnly cookie. Authorized service administrators can access the server records. |
| Setup completion and the selected calendar view | Local app preferences through `shared_preferences` | The user through the app, and anyone with access to the same device or browser profile |

The local planner database is not encrypted by the app and is not automatically uploaded or synchronized between devices. On Web, clearing the site's browser storage can remove planner records and preferences. Calendar imports pass through the Worker before being saved locally; D1 stores connection information rather than a copy of the planner.

Calendar imports are read-only. Changes made in Momentum are not sent back to the provider. Disconnecting removes the provider connection and its tokens from D1, but imported items and local account details remain on the device. Disconnecting Momentum does not necessarily revoke the provider's own app permission; that permission can be removed in the provider's account settings.

Momentum does not store provider passwords. Sign-in takes place on the provider's own website. Event locations are entered or imported as text; the app does not track GPS location. Insights uses local focus records, and no AI planning service is connected.

## Secrets

The app does **not** load a root `.env` file.  Calendar credentials are used by the Worker and must stay out of Flutter code and the public web build.

| Variable | What it is | Where it is declared |
| --- | --- | --- |
| `CANVAS_CLIENT_SECRET`, `GOOGLE_CLIENT_SECRET`, `MICROSOFT_CLIENT_SECRET` | Private credentials for the registered calendar apps; only configured providers need them | Locally in `worker/.dev.vars`; on the hosted app, in Cloudflare Worker secrets |
| `TOKEN_ENCRYPTION_KEY` | A private, randomly generated 32-byte key used to encrypt and decrypt calendar tokens | Locally in `worker/.dev.vars`; on the hosted app, in Cloudflare Worker secrets |
| `CANVAS_CLIENT_ID`, `GOOGLE_CLIENT_ID`, `MICROSOFT_CLIENT_ID` | Identifiers for the registered calendar apps; these are not passwords | Locally in `worker/.dev.vars`; on the hosted app, alongside provider credentials in the Worker settings |
| `CANVAS_REDIRECT_URI`, `GOOGLE_REDIRECT_URI`, `MICROSOFT_REDIRECT_URI` | Addresses where each provider returns the user after sign-in; these are public configuration | Locally in `worker/.dev.vars`; on the hosted app, in the Worker settings |
| `APP_ORIGIN`, `ALLOWED_CANVAS_HOST`, optional `MICROSOFT_TENANT_ID` | The app address, permitted Canvas institution, and Microsoft account organization; these are public configuration | Worker settings in `worker/wrangler.toml` or environment overrides; deployment overrides for the first two come from GitHub Actions variables |
| `CLOUDFLARE_API_TOKEN` | A private credential allowing the deployment workflow to update Cloudflare resources | GitHub Actions repository secrets; it is not used by the app in the browser |
| `CLOUDFLARE_ACCOUNT_ID` | Identifies the Cloudflare account used for deployment; it is not a password | GitHub Actions repository variables |
| Optional `CANVAS_BACKEND_URL` | The calendar backend address; it is public configuration | Flutter build configuration through `--dart-define`; the web app otherwise uses its own address for `/api` requests |

Git ignores `worker/.dev.vars` and local Wrangler state. The committed `worker/.dev.vars.example` contains placeholders and variable names only. Local credentials are not copied to the hosted Worker during deployment; production provider credentials must be configured separately in Cloudflare's **Variables and Secrets** settings. GitHub Actions uses its Cloudflare deployment token, while provider secrets remain in Cloudflare.

Visitors can inspect the deployed JavaScript, static assets, and any configured backend URL. These contain public app resources and addresses, not provider client secrets, the encryption key, or the Cloudflare deployment token. Calendar tokens stay on the Worker and are not returned in API responses. Setup details are in the [Worker guide](../worker/README.md).

## What protects the data on the service side

- The app uses Cloudflare D1. The browser accesses calendar connections through the Worker rather than connecting directly to D1.
- Connection queries use the current browser session. The session cookie is marked `Secure`, `HttpOnly`, and `SameSite=Lax`; sessions expire after 30 days. OAuth verification records expire after 10 minutes and are checked against the session before a connection is saved.
- Access and refresh tokens are encrypted with AES-GCM before storage. The encryption key is stored separately as a Worker secret.
- The Worker checks request origins for non-GET API requests, restricts provider addresses, and requests read-only calendar access. It also includes rate limits and scheduled cleanup of expired session and sign-in records.
- Operational logs record information such as request paths, error types, and cleanup or rate-limit events. The logging statements do not include provider tokens or calendar item contents. Access to these logs is controlled through the hosting account.

## Checklist

- [x] Local Worker credentials and Wrangler state are ignored by Git, and `worker/.dev.vars.example` is committed
- [x] Review the full Git history for real keys, secrets, passwords, or tokens
- [x] No service account file, keystore or `service_role` key anywhere in the repo
- [x] Verify Worker session isolation, OAuth checks, and token handling in the deployed environment
- [x] No real personal data in sample data, screenshots or the video
- [x] No course or university credentials anywhere
- [x] Anyone whose data appears in a test was asked first
