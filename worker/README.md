# Connect a calendar to Momentum

This guide walks through the calendar setup from the beginning. Follow the
steps in order. You only need to set up the provider you want to try.

Calendar connections use a small service running beside Momentum, called a
Cloudflare **Worker**. Canvas, Google Calendar, and Outlook all use published
`.ics` feed links. No provider app registration or OAuth credentials are
needed. The Worker encrypts feed links before saving them. When testing
locally, Wrangler keeps a test database on your computer. When you deploy, the
Worker uses Cloudflare's online database.

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
- A [Cloudflare account](https://dash.cloudflare.com/sign-up) for the calendar
  service and its database.
- A text editor for changing settings files. [Visual Studio Code](https://code.visualstudio.com/download)
  is free and works on Windows, macOS, and Linux.
- An account with the calendar provider you plan to connect.
- For Canvas, the calendar feed must be enabled by your school. Ask its Canvas
  administrator if the Calendar page does not show a feed link.

## Words used in this guide

- **Worker:** the Cloudflare service that fetches calendar feeds.
- **D1 database:** Cloudflare's database. Wrangler uses a local test copy on
  your computer while you are developing.
- **Published `.ics` link:** a read-only calendar feed URL. Treat it like a
  password because anyone who has it may be able to read the calendar.

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

The Worker needs a database for calendar connection information. Do these steps
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

   Migrations run in order. Migration `0004` removes the unused Google and
   Outlook OAuth token tables. The old Canvas OAuth tables remain in the
   schema for migration compatibility, but the Worker no longer uses that
   connection flow. Calendar connections use published feed links.

   The `--local` option creates a database for testing on your computer. The
   separate Cloudflare database is used only when you deploy the app online.

## Part 3: Make a private settings file

This file holds the private encryption key. It stays on your computer. Git is
set up to ignore it so you do not accidentally upload it.

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

2. Open `worker/.dev.vars` in a text editor. The only required private value
   is the encryption key described below.

3. Make a local encryption key. Run this in the same terminal:

   ```sh
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
   ```

   The terminal prints a long string. Copy the entire string and replace the
   example after `TOKEN_ENCRYPTION_KEY=` in `.dev.vars`. Keep the quotation
   marks around it. Do not share the key. Keep it unchanged; if you lose or
   replace it, you will have to connect your calendars again.

4. Save `.dev.vars`. No provider credentials are needed; the feed links are
   entered in Momentum.

## Part 4: Set up one calendar provider

Choose the provider you want to connect. If a provider's website looks
different, use its calendar settings or ask the account administrator for help.

### A. Canvas

Momentum reads the calendar feed published by your Canvas site. You do not
need a Developer Key or Canvas app registration.

1. Open the **Calendar** in Canvas and copy its **Calendar Feed** link. This
   is usually shown near the bottom of the calendar page.
2. Keep the feed link private. It grants read access to the calendar.
3. If your Canvas site uses a custom hostname outside `instructure.com`, set
   `ALLOWED_CANVAS_HOST` to that hostname in `worker/wrangler.toml` locally
   and in the GitHub Actions variable for your hosted Worker. Do not include
   `https://` or a path. Canvas sites on `instructure.com` are accepted
   automatically.
4. In Momentum, open **Add calendars**, choose **Canvas**, paste the feed link,
   and select **Connect Canvas calendar**. The feed syncs when you connect,
   when Momentum opens, and every five minutes while the app is open.

If your school has disabled calendar feeds, ask its Canvas administrator to
enable them.

### B. Google Calendar

Momentum reads a published iCalendar feed. You do not need a Google Cloud
project or OAuth client.

1. Open Google Calendar settings and select the calendar you want to connect.
2. Under **Integrate calendar**, copy **Secret address in iCal format**. Do
   not use the public address unless you intentionally made the calendar public.
3. Keep the secret address private. Anyone who has it can read that calendar.
4. In Momentum, open **Add calendars**, choose **Google Calendar**, paste the
   secret iCal address, and select **Connect Google Calendar**. The feed syncs
   when you connect, when Momentum opens, and every five minutes while the app
   is open.

### C. Outlook

Outlook connects through a published calendar link. You do not need Microsoft
Entra, an app registration, or a Microsoft client secret.

1. Open Outlook on the web and open **Settings**.
2. Go to **Calendar**, then **Shared calendars**.
3. Under **Publish a calendar**, select the calendar and choose the detail
   level you want to share. Choose **Can view all details** if you want event
   titles, times, locations, and descriptions in Momentum.
4. Select **Publish**, then copy the **ICS** link. Keep this link private:
   anyone who has it can view the published calendar.
5. In Momentum, open **Add calendars**, choose **Outlook**, paste the link, and
   select **Connect Outlook calendar**. The calendar syncs when you connect,
   when Momentum opens, and every five minutes while the app is open.

To revoke the link, return to **Shared calendars** and unpublish the calendar.
That invalidates the link stored by Momentum.

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
   `http://127.0.0.1:8787`. Use the same address for the app and API. Do not
   start the app with `flutter run -d chrome` for this feed test; that command
   does not run the Worker. The Worker must serve both Momentum and the `/api`
   routes from the same address.
5. In Momentum, choose **Add calendars**, paste a published `.ics` link, and
   connect the provider.
6. Check the Calendar or To-Do screen for imported items. All connected feeds
   refresh when Momentum opens and every five minutes while it is open.

If this works locally, the provider setup is complete. You do not need Part 6
unless you want to publish the app online.

## Part 6: Publish the official app (maintainer only)

The repository's GitHub Actions workflow now builds Flutter and deploys the
website and calendar API together to a Cloudflare custom domain. It also applies
D1 updates. Do not use the old manual `wrangler deploy` steps for the official
site. Follow the **Publish the official app** section at the top of the main
[README](../README.md). That section explains the domain, GitHub settings,
Worker secret, first deploy, and user smoke check.

Local values in `.dev.vars` are never copied to the hosted Worker. After the
first deploy, add `TOKEN_ENCRYPTION_KEY` in the Cloudflare dashboard under the
`momentum-canvas` Worker's **Settings → Variables and Secrets**. Users paste
their own published feed links in Momentum; do not put those links in GitHub
Actions or Worker configuration.

Set `APP_ORIGIN` and `ALLOWED_CANVAS_HOST` as GitHub Actions **variables**.
Never add provider secrets to GitHub Actions or Flutter build settings. When
adding or changing Worker secrets, rerun the production workflow so the site
and Worker version are redeployed together.

## Part 7: Fix common problems

- **Momentum says it cannot read the calendar:** check that the link is the
  provider's `.ics` feed URL and that it is still published. Google links must
  use the **Secret address in iCal format**; Outlook links come from **Shared
  calendars → Publish a calendar**. Canvas feeds may be disabled by the
  school. Keep feed links private; anyone who gets one may be able to read the
  calendar.
- **Canvas reports that the link is not allowed:** if the Canvas site uses a
  custom hostname outside `instructure.com`, set `ALLOWED_CANVAS_HOST` to its
  hostname only (no `https://` or path) in Wrangler or the GitHub Actions
  variable, then redeploy.
- **Wrangler says it cannot find the database:** check that the ID in
  `worker/wrangler.toml` is the one Wrangler printed when you created
  `momentum-canvas`. Make sure you applied migrations with `--local` for local
  testing or `--remote` for the deployed app.
- **The app opens on `localhost:xxxx` but calendar requests fail:** use
  `http://localhost:8787`, start the Worker with `npx wrangler dev`, and keep
  its terminal open. Do not use the separate Flutter web server for calendar
  feeds.
- **The log says an `/api/...` request used `not_found_handling` and returned
  the app page:** check that `worker/wrangler.toml` has
  `run_worker_first = ["/api/*"]` under `[assets]`. Otherwise, the SPA fallback
  can answer an API request before the Worker sees it.
- **You lost the encryption key:** previously stored feed links cannot be
  recovered without the old key. Generate a new key, save it in the Worker
  settings, then reconnect the calendars.

## What is saved where

- Momentum saves tasks, events, categories, and focus totals in its local
  database on your device or browser.
- The Worker saves calendar connections in Cloudflare's database. Published
  Canvas, Google Calendar, and Outlook feed links are encrypted with
  `TOKEN_ENCRYPTION_KEY`.
- Calendar import is one-way. Disconnecting removes the connection but leaves
  items already imported into Momentum. Changes made in Momentum are not sent
  back to Canvas, Google, or Outlook.

## Official setup guides

- [Cloudflare D1 database commands](https://developers.cloudflare.com/d1/wrangler-commands/)
- [Google Calendar sharing settings](https://support.google.com/calendar/answer/37082)
- [Publish your Outlook calendar](https://support.microsoft.com/office/share-your-calendar-in-outlook-on-the-web-3fc8d1e4-6c42-4b80-9c5e-6a5d848f6332)
