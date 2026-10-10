# Momentum

Momentum is a personal planner for tasks, events, deadlines, and focus time. It
is built with Flutter and stores planner data locally. Calendar imports are
read-only copies: provider passwords and OAuth tokens are never entered into or
stored by the Flutter app.

> **Use Momentum:** The official hosted app is not published yet. After the
> first production deployment, the repository owner should replace this note
> with the official HTTPS link. People using Momentum should open that link;
> they do not need to clone the repository or create OAuth credentials.

Developers who clone or fork this repository need their own Cloudflare Worker,
database, and provider OAuth setup. They cannot safely use the owner's private
provider credentials or production OAuth service. See
[worker/README.md](worker/README.md) for the local development setup.

## Publish the official app (maintainer setup)

The GitHub Actions workflow builds the Flutter website, applies the Worker
database migrations, and deploys the site and `/api` sign-in routes together to
one Cloudflare domain whenever `main` is updated. This is a one-time owner setup;
calendar users do not do these steps.

Cloudflare Free is a reasonable pilot starting point. Its published allowance
currently includes 100,000 Worker requests per day; static asset requests do
not use that Worker request allowance. D1 also has daily read/write limits, so
calendar API calls can fail until the daily reset if the database reaches them.
Check the current
[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/),
[D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), and
[D1 limits](https://developers.cloudflare.com/d1/platform/limits/) before
opening the app to more people. When a daily D1 limit is reached, calendar
connection or sync requests can fail until the limit resets.

1. Add your domain to Cloudflare and confirm that its DNS is active there. Choose
   the HTTPS origin you will use, such as `https://momentum.example.com`.
2. In Cloudflare, create a D1 database named `momentum-canvas`. Put its database
   ID into `worker/wrangler.toml` as `database_id`. The workflow applies the
   checked-in migrations before every deploy.
3. Create a Cloudflare API token for the deployment. It needs **Workers
   Admin** to create the Worker the first time, **D1 Write** to apply database
   migrations, and **Workers Routes Write** for the zone where the custom domain
   lives. Limit it to the Momentum account and zone. See Cloudflare's
   [Worker permissions guide](https://developers.cloudflare.com/workers/authorization/workers/).
   In GitHub, open **Settings → Secrets and variables → Actions** and add:

   - **Secret** `CLOUDFLARE_API_TOKEN` — the token from Cloudflare.
   - **Variable** `CLOUDFLARE_ACCOUNT_ID` — the Cloudflare account ID.
   - **Variable** `APP_ORIGIN` — the full HTTPS origin, with no path or trailing
     slash, such as `https://momentum.example.com`.
   - **Variable** `ALLOWED_CANVAS_HOST` — your school's Canvas hostname only,
     such as `canvas.school.edu`. Leave it empty if Canvas is not configured.

4. Register these exact callback addresses in each provider's app settings,
   replacing `momentum.example.com` with your domain:

   ```text
   Google:     https://momentum.example.com/api/google/oauth/callback
   Canvas:     https://momentum.example.com/api/canvas/oauth/callback
   Microsoft:  https://momentum.example.com/api/outlook/oauth/callback
   ```

   Google must approve the Calendar read-only scope before unrestricted public
   use; while it is in Testing mode, add each tester as a test user. Microsoft
   needs delegated `Calendars.Read`; publisher verification improves trust, and
   some organizations may require their administrator's approval. Canvas needs
   a Developer Key approved by the school's Canvas administrator. Provider
   setup details are in [worker/README.md](worker/README.md).

5. Add provider credentials to **Cloudflare Worker secrets**, not GitHub
   Actions and not Flutter. After the first successful deployment, open the
   `momentum-canvas` Worker in Cloudflare and add `TOKEN_ENCRYPTION_KEY`, then
   the credential and callback secrets for each provider you enabled:

   ```text
   Canvas:    CANVAS_CLIENT_ID, CANVAS_CLIENT_SECRET, CANVAS_REDIRECT_URI
   Google:    GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI
   Microsoft: MICROSOFT_CLIENT_ID, MICROSOFT_CLIENT_SECRET, MICROSOFT_REDIRECT_URI
   ```

   Generate the encryption key with:

   ```sh
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
   ```

   Save the key somewhere private and keep it unchanged. Changing it prevents
   the Worker from decrypting tokens already saved for linked calendars.
6. Push these changes to `main`, or run **Actions → Build and deploy Momentum →
   Run workflow** on `main`. If the first run happened before you added the
   provider secrets, rerun the workflow after adding them.
7. Open the HTTPS origin. Connect and sync each provider in a separate browser
   profile to confirm that connections stay separate. Then put the resulting
   official URL in the **Use Momentum** note at the top of this file.

The app's planner items and imported copies stay in each user's browser storage.
Only encrypted provider tokens and minimal account connection details are kept
in the Worker database. Disconnecting a calendar removes its server-side
connection and leaves imported copies in that browser.

The Worker has a daily job that removes expired sign-in requests and sessions.
It also limits repeated OAuth and sync requests and records Worker errors in
Cloudflare Observability. These controls help with routine abuse and support a
small pilot; keep monitoring **Workers & Pages → momentum-canvas → Metrics/Logs**
and the D1 database's usage page, along with provider approval status. Cloudflare
rate-limit counters are an abuse guard and are not exact billing meters.

## Run the app

Install Flutter, then run these commands from the repository root:

```powershell
flutter pub get
flutter run -d chrome
```

This starts the planner UI. Calendar sign-in also needs the Worker backend
described below; `flutter run -d chrome` by itself does not provide the OAuth
API. Web database data is kept by the browser for that app origin. See
[Local database](docs/local-database.md) for browser storage details.

## Import a calendar

### What you do in Momentum

On a new install, choose **Get started**. Otherwise, open **Calendar** and tap
**Add calendars**. Choose a provider, tap **Connect**, and sign in on that
provider's own page. Momentum then imports the calendar items. Use **Sync now**
to request another import. You can rename the provider's category in its
connection screen.

The app never asks for your Canvas, Google, or Microsoft password. The OAuth
client secrets and provider tokens belong on the Worker backend. This setup is
required because the frontend redirects to same-origin `/api/...` routes; a
Flutter development server alone cannot handle those routes.

### Set up a cloned repository for local development

This is only for developers who are running their own copy. You need Flutter,
Node.js with npm, a Cloudflare account, and your own OAuth credentials for each
provider you want to test. Register the localhost callback URLs listed below.
The official hosted app has its own credentials and domain.

1. Install the project and Worker dependencies:

   ```powershell
   flutter pub get
   cd worker
   npm.cmd install
   npx.cmd wrangler login
   ```

   On Windows, the `.cmd` endings avoid a PowerShell script-policy error. Use
   `npx.cmd` for the other Wrangler commands below too.

2. Create a D1 database for your own copy and replace the existing
   `database_id` value in `worker/wrangler.toml` with the ID printed by Wrangler:

   ```powershell
   npx.cmd wrangler d1 create momentum-canvas
   ```

3. For local development, keep `APP_ORIGIN` set to `http://localhost:8787` in
   `worker/wrangler.toml`. If you use Canvas, change `ALLOWED_CANVAS_HOST` to
   your school's hostname only, such as `canvas.school.edu` (no `https://` and
   no path).

4. Apply the migrations to your local test database:

   ```powershell
   npx.cmd wrangler d1 migrations apply momentum-canvas --local
   ```

5. Create a local secrets file next to `wrangler.toml` and enter credentials
   only for the providers you plan to use:

   ```powershell
   Copy-Item .dev.vars.example .dev.vars
   ```

   Open `worker/.dev.vars` and replace its example values. Generate a random
   encryption key with:

   ```powershell
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
   ```

   Put the result in `TOKEN_ENCRYPTION_KEY`. Set this key once per Worker and
   keep it stable; changing it makes already stored provider tokens unreadable.
   Do not commit `.dev.vars`; Git ignores that file.

6. Build the web app and start the Worker from the `worker` directory:

   ```powershell
   cd ..
   flutter build web
   cd worker
   npx.cmd wrangler dev
   ```

   Open `http://localhost:8787`, even if Wrangler prints
   `http://127.0.0.1:8787`. The browser treats these as different addresses,
   and the local Google callback is registered for `localhost`. Keep using
   `http://localhost:8787` during sign-in so the callback returns to the same
   app session. To publish the official app, follow the maintainer steps at the
   top of this README; do not point a clone at the official app's OAuth service.
   More local backend details are in [worker/README.md](worker/README.md).

### 1. Canvas

Canvas OAuth needs an institution-approved developer key. If your institution
does not let students create keys, ask its Canvas administrator to register
and enable one for Momentum. Do not create or paste a personal access token.
See the [Canvas OAuth guide](https://canvas.instructure.com/doc/api/file.oauth.html)
and [Canvas Developer Keys guide](https://canvas.instructure.com/doc/api/developer_keys.html).

1. Ask the Canvas administrator for the **client ID** and **client secret**,
   and have them allow the read-only scopes Momentum uses for courses,
   calendar events, and the profile:

   ```text
   GET /api/v1/courses
   GET /api/v1/calendar_events
   GET /api/v1/users/self/profile
   ```
2. Have the administrator add the exact redirect URL to the developer key:

   ```text
   Local:      http://localhost:8787/api/canvas/oauth/callback
   Deployed:   https://YOUR-DOMAIN/api/canvas/oauth/callback
   ```

   Use the same URL for `CANVAS_REDIRECT_URI` in `.dev.vars` for local testing.
   For the official app, use your deployed domain and save the credential and
   callback values as Cloudflare Worker secrets (see the maintainer section at
   the top). Set `ALLOWED_CANVAS_HOST` as a GitHub Actions variable to the
   institution hostname, for example `canvas.school.edu`. One host is supported.
4. Put the client ID, client secret, redirect URL, and shared
   `TOKEN_ENCRYPTION_KEY` in `worker/.dev.vars` for local use. Do not put them in
   Flutter or GitHub Actions.
5. Open Momentum, choose **Canvas**, enter the full site URL (for example,
   `https://canvas.school.edu`), and tap **Connect with Canvas**. Sign in and
   approve access on Canvas. Momentum then syncs dated assignments and calendar
   events into the Canvas category.

### 2. Google Calendar

1. In [Google Cloud Console](https://console.cloud.google.com/), create or
   choose a project and enable the [Google Calendar API](https://developers.google.com/workspace/calendar/api/guides/overview).
2. Configure the OAuth consent screen. While the app is in testing mode, add
   each Google account that will test it as a test user.
3. Create an OAuth client with application type **Web application**. Add the
   exact callback URL for the environment you are testing:

   ```text
   Local:      http://localhost:8787/api/google/oauth/callback
   Deployed:   https://YOUR-DOMAIN/api/google/oauth/callback
   ```

   The server-side OAuth flow and exact redirect URI matching are described in
   [Google's web server OAuth guide](https://developers.google.com/identity/protocols/oauth2/web-server).
4. Put the OAuth client ID, client secret, callback URL, and
   `TOKEN_ENCRYPTION_KEY` in `worker/.dev.vars` for local use. For the official
   app, save them as Cloudflare Worker secrets as described at the top of this
   README.
5. In Momentum, choose **Google Calendar** → **Connect with Google Calendar**.
   Sign in to Google and approve the read-only calendar access. Choose **Sync
   now** to import the calendars visible to that account.

### 3. Outlook

1. In [Microsoft Entra](https://entra.microsoft.com/), register an application.
   Choose the account types you want to allow. The Worker defaults to
   `MICROSOFT_TENANT_ID = "common"`, which supports personal and work or school
   accounts.
2. Under the app's **Authentication** settings, add a **Web** redirect URI for
   the environment you are testing:

   ```text
   Local:      http://localhost:8787/api/outlook/oauth/callback
   Deployed:   https://YOUR-DOMAIN/api/outlook/oauth/callback
   ```

   See Microsoft's [redirect URI instructions](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-redirect-uri).
3. Add the delegated Microsoft Graph permission `Calendars.Read`. Create a
   client secret and copy its value while it is visible.
4. Put the application ID, client secret, callback URL, and
   `TOKEN_ENCRYPTION_KEY` in `worker/.dev.vars` for local use. For the official
   app, save them as Cloudflare Worker secrets as described at the top of this
   README.
5. In Momentum, choose **Outlook** → **Connect with Outlook**. Sign in and
   approve access, then choose **Sync now** to import events from the account's
   calendars. The Worker uses Microsoft Graph's
   [calendar view API](https://learn.microsoft.com/en-us/graph/api/calendar-list-calendarview?view=graph-rest-1.0).

## Troubleshooting calendar sign-in

- If sign-in immediately returns to Momentum, make sure `npx.cmd wrangler dev` (or
  your deployed Worker) is serving the app and `/api` routes on the same origin.
  Running `flutter run -d chrome` alone is not enough for OAuth.
- If a provider reports a redirect URI mismatch, compare the URI in its console
  character-for-character with the matching `*_REDIRECT_URI` value, including
  `http`/`https`, hostname, path, and trailing slash.
- If Canvas rejects the request, verify that the developer key is enabled for
  your institution and that `ALLOWED_CANVAS_HOST` matches the Canvas hostname.
- The Worker needs the D1 migrations and `TOKEN_ENCRYPTION_KEY` before a
  successful connection can be stored.

## Data and privacy

Tasks, events, categories, and focus totals are stored in Momentum's local
SQLite database (IndexedDB for Web). Calendar connections use the Worker to
keep OAuth tokens encrypted on the server; disconnecting leaves already
imported items in Momentum. Imported item edits and task completion stay local
and are not sent back to the calendar provider.
