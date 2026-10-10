# Connect a calendar to Momentum

This guide walks through the calendar setup from the beginning. Follow the
steps in order. You only need to set up the provider you want to try.

Calendar sign-in needs a small service running beside Momentum. It is called a
Cloudflare **Worker**. It sends you to Canvas, Google, or Microsoft to sign in,
then saves an encrypted sign-in token so Momentum can import calendar items.
Momentum never asks for your provider password. When testing locally, Wrangler
keeps a test database on your computer. When you deploy, the Worker uses
Cloudflare's online database.

## First, decide what you want to do

- **Try it on your own computer:** follow Parts 1 to 5, then stop. This is the
  best place to start.
- **Put Momentum online for other people:** first finish the local setup, then
  follow Part 5.
- **Only want to use tasks and events without a connected calendar?** You can
  skip this guide. Calendar setup is optional.

## What you need

- Git, Flutter, Node.js with npm, and a web browser. Install them from the
  [Git website](https://git-scm.com/downloads), [Flutter install guide](https://docs.flutter.dev/get-started/install),
  and [Node.js website](https://nodejs.org/).
- A [Cloudflare account](https://dash.cloudflare.com/sign-up) for the sign-in
  service and its database.
- A text editor for changing settings files. [Visual Studio Code](https://code.visualstudio.com/download)
  is free and works on Windows, macOS, and Linux.
- An account with the calendar provider you plan to connect.
- For Canvas, help from your school's Canvas administrator. Students usually
  cannot create the required Canvas developer key themselves.

## Words used in this guide

- **Worker:** the Cloudflare service that handles calendar sign-in.
- **D1 database:** Cloudflare's database. Wrangler uses a local test copy on
  your computer while you are developing.
- **OAuth:** the sign-in process where you approve access on the provider's
  own website. You do not give Momentum your password.
- **Callback URL:** the web address the provider sends you back to after you
  approve access. It must be copied exactly into both places.
- **Client ID:** the public identifier for Momentum in the provider's settings.
- **Client secret:** a private password for Momentum in the provider's
  settings. Do not put it in Flutter code or commit it to GitHub.

## Part 1: Download Momentum and install its tools

**Windows PowerShell note:** If PowerShell says that scripts are disabled when
you type `npm` or `npx`, use `npm.cmd` and `npx.cmd` instead. For example, use
`npm.cmd install` and `npx.cmd wrangler login`. This avoids changing your
computer's security settings. On macOS or Linux, keep using `npm` and `npx`.

The **main project folder** is the folder named `momentum`. Inside it is the
`worker` folder. Some steps below ask you to move between these folders.

If you already have a copy of the repository, open a terminal in that folder
and skip to step 3.

1. Open PowerShell (Windows) or Terminal (macOS/Linux).
2. Copy and run these commands to download the project and enter its folder:

   ```sh
   git clone https://github.com/asm0git/momentum.git
   cd momentum
   ```

   If GitHub asks you to sign in, finish that in your browser. The commands
   should leave your terminal in the `momentum` folder.

3. Download the Flutter packages:

   ```sh
   flutter pub get
   ```

4. Enter the `worker` folder and install its packages:

   ```sh
   cd worker
   npm install
   ```

5. Connect Wrangler (Cloudflare's command-line tool) to your Cloudflare
   account:

   ```sh
   npx wrangler login
   ```

   A browser window opens. Sign in and approve the connection. When it says
   you are logged in, return to the terminal. Keep using this terminal from
   inside the `worker` folder for the next steps.

### How to open the settings files

In Visual Studio Code, choose **File > Open Folder**, select the `momentum`
folder, and choose **Select Folder**. In the left Explorer panel, open the
`worker` folder. Click `wrangler.toml` to edit the Worker settings. The
`.dev.vars` file will appear there after you create it in Part 3. You can use
another text editor if you prefer; save each file after changing it.

## Part 2: Create and configure the database

The Worker needs a database for calendar sign-in information. Do these steps
once for this Momentum copy.

1. From the `worker` folder, create the Cloudflare database:

   ```sh
   npx wrangler d1 create momentum-canvas
   ```

   Wrangler prints several lines. Find the line named `database_id` and copy
   the long ID after it. If the command says that this database already exists,
   do not create another one; use its existing ID.

   This creates an empty online database in your Cloudflare account. When you
   run Momentum locally, the app uses a separate local test database.

2. Open `worker/wrangler.toml` in a text editor. Near the bottom, find:

   ```toml
   database_id = "REPLACE_WITH_CLOUDFLARE_D1_DATABASE_ID"
   ```

   Replace the words inside the quotation marks with the ID from step 1. Keep
   the quotation marks. Save the file.

3. In the same file, find the `[vars]` section. For testing on your own
   computer, set the app address to:

   ```toml
   APP_ORIGIN = "http://localhost:8787"
   ```

   If you are not using Canvas yet, leave `ALLOWED_CANVAS_HOST` as it is. If
   you are using Canvas, you will replace it in the Canvas section below.

4. Create the local database tables by running this command from the `worker`
   folder:

   ```sh
   npx wrangler d1 migrations apply momentum-canvas --local
   ```

   If Wrangler asks whether it should apply the migrations, type `y` and press
   Enter. Look for a success message before continuing.

   The `--local` option creates a database for testing on your computer. The
   separate Cloudflare database is used only when you deploy the app online.

## Part 3: Make a private settings file

This file holds the provider keys needed for sign-in. It stays on your
computer. Git is set up to ignore it so you do not accidentally upload it.

1. Make sure your terminal is still in the `worker` folder. Copy the example
   file using the command for your terminal:

   **Windows PowerShell**

   ```powershell
   Copy-Item .dev.vars.example .dev.vars
   ```

   **macOS or Linux**

   ```sh
   cp .dev.vars.example .dev.vars
   ```

2. Open `worker/.dev.vars` in a text editor. Leave the example values for now;
   you will replace the values for your chosen provider in Part 4.

3. Make a local encryption key. Run this in the same terminal:

   ```sh
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
   ```

   The terminal prints a long string. Copy the entire string and replace the
   example after `TOKEN_ENCRYPTION_KEY=` in `.dev.vars`. Keep the quotation
   marks around it. Do not share the key. Keep it unchanged; if you lose or
   replace it, you will have to connect your calendars again.

4. Save `.dev.vars`. It should still contain all the provider names, even if
   you are only setting up one provider. Only replace the values for the
   provider you chose, plus `TOKEN_ENCRYPTION_KEY`.

## Part 4: Set up one calendar provider

Choose **one** section below. If a provider's website looks different, use its
linked official help page or ask the account administrator for help.

### A. Canvas

Canvas needs an app key approved by the school that runs your Canvas site. This
is different from your Canvas username and password. Do not create a personal
access token.

1. Find your Canvas site address. It looks like `https://canvas.school.edu`.
   Write down only the hostname part, such as `canvas.school.edu`.
2. Ask your Canvas administrator to create or enable a **Developer Key** for
   Momentum. You can copy this request and send it to them:

   ```text
   I want to connect the open-source Momentum planner to our Canvas site for
   read-only calendar import. Please create or enable an OAuth Developer Key
   for Momentum, and send me its Client ID and Client Secret securely.

   Canvas site hostname: canvas.school.edu
   Local callback URL: http://localhost:8787/api/canvas/oauth/callback

   Please allow these read-only scopes:
   url:GET|/api/v1/courses
   url:GET|/api/v1/calendar_events
   url:GET|/api/v1/users/self/profile
   ```

   Replace `canvas.school.edu` in the request with your school's hostname.
   The administrator must enable the key for your school's Canvas site.
   Canvas may show a different admin page at each school. If your administrator
   cannot find Developer Keys, ask the school's Canvas support team.

3. When the administrator gives you the Client ID and Client Secret, open
   `worker/.dev.vars` and replace the Canvas example lines with the real
   values. Keep the quotation marks:

   ```text
   CANVAS_CLIENT_ID="paste-client-id-here"
   CANVAS_CLIENT_SECRET="paste-client-secret-here"
   CANVAS_REDIRECT_URI="http://localhost:8787/api/canvas/oauth/callback"
   ```

4. Open `worker/wrangler.toml`. In the `[vars]` section, change
   `ALLOWED_CANVAS_HOST` to your hostname. Do not include `https://`, a slash,
   or anything after the hostname:

   ```toml
   ALLOWED_CANVAS_HOST = "canvas.school.edu"
   ```

   This Worker supports one Canvas institution at a time.

5. Save both files. Later, when you run Momentum, enter the full address in
   the Canvas site field, for example `https://canvas.school.edu`.

More help: [Canvas OAuth guide](https://canvas.instructure.com/doc/api/file.oauth.html) and [Canvas Developer Keys guide](https://canvas.instructure.com/doc/api/file.developer_keys.html).

### B. Google Calendar

These steps create Google's app settings so Momentum can ask you to approve
read-only access to your calendar.

1. Open [Google Cloud Console](https://console.cloud.google.com/) and sign in.
2. At the top of the page, open the project menu and choose **New Project**.
   Name it `Momentum test`, then select **Create**. When the project is ready,
   make sure it is selected at the top of the page.
3. Turn on the Calendar API:
   - Open **APIs & Services**, then **Library**.
   - Search for **Google Calendar API** and select it.
   - Select **Enable**. If the button says **Manage**, it is already enabled.
4. Set up the permission screen:
   - Open **Google Auth Platform**, then **Branding**. If you see **Get
     started**, select it.
   - Enter `Momentum` as the app name. Choose your email as the user support
     email and contact email, then continue and save.
   - Open **Audience**. Choose **External** if you are using a personal Gmail
     account. If you are only testing inside one school or work Google
     organization, you can choose **Internal** if that option is available.
   - While the app is in testing, open **Test users**, select **Add users**,
     enter the Google email address you will use to sign in, and save. If you
     skip this, Google may refuse the sign-in.
   - If Google asks which permissions Momentum needs, add the scopes below.
     These are the exact permissions the code requests. They allow calendar
     viewing and basic sign-in information, but do not allow calendar edits:

     ```text
     openid
     email
     profile
     https://www.googleapis.com/auth/calendar.events.readonly
     https://www.googleapis.com/auth/calendar.calendarlist.readonly
     ```

     Do not add broader Calendar permissions such as edit access.
5. Create the app's ID and secret:
   - Open **Google Auth Platform**, then **Clients**.
   - Select **Create Client**. Choose **Web application**.
   - Name it `Momentum local`.
   - Under **Authorized redirect URIs**, select **Add URI** and paste exactly:

     ```text
     http://localhost:8787/api/google/oauth/callback
     ```

     Do not put this under **Authorized JavaScript origins**.
   - Select **Create**. Copy the Client ID and Client Secret from the box that
     appears. The secret is private; do not paste it into a public chat or
     GitHub.
6. Open `worker/.dev.vars`. Replace the Google example lines. Keep the quotes:

   ```text
   GOOGLE_CLIENT_ID="paste-client-id-here"
   GOOGLE_CLIENT_SECRET="paste-client-secret-here"
   GOOGLE_REDIRECT_URI="http://localhost:8787/api/google/oauth/callback"
   ```

7. Save the file. When you sign in later, use an email address you added under
   Google **Test users**. If Google says the app is unverified, make sure you
   are signing in with a listed test user. A public app for other people may
   need Google's review before testing restrictions can be removed.

More help: Google's [OAuth consent screen guide](https://developers.google.com/workspace/guides/configure-oauth-consent) and [web server sign-in guide](https://developers.google.com/identity/protocols/oauth2/web-server).

### C. Outlook

These steps create a Microsoft app registration. The registration lets
Momentum request read-only access after you sign in.

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com/) and
   sign in with your Microsoft account.
2. Open **Identity**, then **Applications**, then **App registrations**.
   Select **New registration**.
3. Enter `Momentum local` as the name.
4. Under **Supported account types**, choose the option that allows both
   accounts in any organization and personal Microsoft accounts. This matches
   the Worker's default setting.
5. Under **Redirect URI**, choose **Web** and enter:

   ```text
   http://localhost:8787/api/outlook/oauth/callback
   ```

   Select **Register**.
6. On the app's **Overview** page, copy **Application (client) ID**. Do not
   copy **Object ID**; Momentum needs the Application ID.
7. Add read-only calendar permission:
   - Open **API permissions**, then select **Add a permission**.
   - Choose **Microsoft Graph**, then **Delegated permissions**.
   - Search for and check `Calendars.Read`, then select **Add permissions**.
   - If your school or workplace says admin approval is required, ask its
     Microsoft 365 administrator to approve this permission.
8. Create the client secret:
   - Open **Certificates & secrets**, then **Client secrets**.
   - Select **New client secret**, enter a description such as `Momentum local`,
     choose an expiration, and select **Add**.
   - Copy the secret's **Value** immediately. Do not copy **Secret ID**. The
     Value is only shown once; if you lose it, create a new secret.
9. Open `worker/.dev.vars`. Replace the Outlook example lines and keep the
   quotation marks:

   ```text
   MICROSOFT_CLIENT_ID="paste-Application-client-ID-here"
   MICROSOFT_CLIENT_SECRET="paste-secret-Value-here"
   MICROSOFT_REDIRECT_URI="http://localhost:8787/api/outlook/oauth/callback"
   ```

10. Save the file.

More help: Microsoft's [app registration guide](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret), [callback URL guide](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-redirect-uri), and [client secret guide](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-credentials).

## Part 5: Run and test it on your computer

You should now have a database, a `.dev.vars` file, and settings for one
provider.

1. In your terminal, go back to the main project folder. If your terminal is
   still in `worker`, run:

   ```sh
   cd ..
   ```

2. Build the web version of Momentum:

   ```sh
   flutter build web
   ```

   Wait for Flutter to finish. If it reports an error, fix that before
   continuing.

3. Go into the `worker` folder and start the local web server:

   ```sh
   cd worker
   npx wrangler dev
   ```

   Leave this terminal open. It must keep running while you use the app.
   Wrangler may print `http://127.0.0.1:8787`.

4. In Chrome, open `http://localhost:8787` even if Wrangler printed
   `http://127.0.0.1:8787`. This setup registers the Google callback and
   session cookie for `localhost`; the browser treats `127.0.0.1` as a
   different address. Do not start the app with
   `flutter run -d chrome` for this sign-in test; that command does not run the
   Worker. The Worker must serve both Momentum and the `/api` sign-in routes
   from the same address.
5. In Momentum, choose **Add calendars**, choose the provider you configured,
   and select **Connect with ...**. Sign in on the provider's own website and
   approve access.
6. After returning to Momentum, select **Sync now**. Check the Calendar or
   To-Do screen for imported items.

If this works locally, the provider setup is complete. You do not need Part 6
unless you want to publish the app online.

## Part 6: Publish the official app (maintainer only)

The repository's GitHub Actions workflow now builds Flutter and deploys the
website and OAuth API together to a Cloudflare custom domain. It also applies
D1 updates. Do not use the old manual `wrangler deploy` steps for the official
site. Follow the **Publish the official app** section at the top of the main
[README](../README.md). That section explains the domain, GitHub settings,
provider callbacks, Worker secrets, first deploy, and user smoke check.

Local values in `.dev.vars` are never copied to the hosted Worker. After the
first deploy, add the production credentials in the Cloudflare dashboard under
the `momentum-canvas` Worker settings. Use `TOKEN_ENCRYPTION_KEY` and only the
providers you enabled:

```text
Canvas:    CANVAS_CLIENT_ID, CANVAS_CLIENT_SECRET, CANVAS_REDIRECT_URI
Google:    GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI
Microsoft: MICROSOFT_CLIENT_ID, MICROSOFT_CLIENT_SECRET, MICROSOFT_REDIRECT_URI
```

Set `APP_ORIGIN` and `ALLOWED_CANVAS_HOST` as GitHub Actions **variables**.
Never add provider secrets to GitHub Actions or Flutter build settings. When
adding or changing Worker secrets, rerun the production workflow so the site
and Worker version are redeployed together.

## Part 7: Fix common problems

- **The sign-in screen never opens or Momentum reports "provider not
  configured":** check that all three provider values are filled in. For
  local testing, check `worker/.dev.vars`. For the online app, check the
  `momentum-canvas` Worker's **Settings → Variables and Secrets** in Cloudflare.
- **The provider says the callback or redirect URL is wrong:** compare the
  whole address character by character. Check `http` versus `https`, the
  hostname, the `/api/.../oauth/callback` path, and any trailing slash. Local
  uses `localhost:8787`; the official app uses the custom domain in the main
  README.
- **Google says the app is blocked or you are not allowed:** open Google Auth
  Platform, then **Audience**, and add the email you are signing in with under
  **Test users**. The app owner may also need to submit the app for Google's
  review before unrestricted public use.
- **Canvas says `unauthorized_client` or `invalid_scope`:** the administrator
  must enable the developer key for your Canvas site and allow all three
  scopes listed in the Canvas section. Check that `ALLOWED_CANVAS_HOST` is
  only the hostname (no `https://`).
- **Microsoft says admin approval is needed:** your school or workplace
  controls app permissions. Ask its Microsoft 365 administrator to approve
  delegated `Calendars.Read`.
- **Wrangler says it cannot find the database:** check that the ID in
  `worker/wrangler.toml` is the one Wrangler printed when you created
  `momentum-canvas`. Make sure you applied migrations with `--local` for local
  testing or `--remote` for the deployed app.
- **The app opens on `localhost:xxxx` but sign-in returns to the app without
  connecting:** use `http://localhost:8787`, start the Worker with
  `npx wrangler dev`, and keep its terminal open. Do not use the separate
  Flutter web server for calendar sign-in.
- **The log says an `/api/...` request used `not_found_handling` and returned
  the app page:** check that `worker/wrangler.toml` has
  `run_worker_first = ["/api/*"]` under `[assets]`. Otherwise, the SPA fallback
  can answer a browser navigation to an OAuth route before the Worker sees it.
- **You lost the encryption key:** create a new key and connect the calendar
  again. Previously stored sign-in tokens cannot be recovered without the old
  key.

## What is saved where

- Momentum saves tasks, events, categories, and focus totals in its local
  database on your device or browser.
- The Worker saves calendar connections in Cloudflare's database. Provider
  sign-in tokens are encrypted with `TOKEN_ENCRYPTION_KEY`.
- Calendar import is one-way. Disconnecting removes the connection but leaves
  items already imported into Momentum. Changes made in Momentum are not sent
  back to Canvas, Google, or Microsoft.

## Official setup guides

- [Cloudflare D1 database commands](https://developers.cloudflare.com/d1/wrangler-commands/)
- [Canvas OAuth and developer keys](https://canvas.instructure.com/doc/api/file.oauth.html)
- [Google OAuth consent screen](https://developers.google.com/workspace/guides/configure-oauth-consent)
- [Microsoft app registration](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret)
