# Momentum

Momentum is a study-planning app that helps students organize tasks, events, focus sessions, and calendar imports in one place.

**Live demo:** [momentum-canvas.aerith-catap.workers.dev](https://momentum-canvas.aerith-catap.workers.dev)<br>
**Demo video:** [Watch the 4-minute, 32-second demo](https://drive.google.com/drive/folders/1MwIXI-WKYCeKETUISc-WlHO22oYcv9nz?usp=drive_link)<br>
**Repository:** [github.com/asm0git/momentum](https://github.com/asm0git/momentum)<br>
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Aerith Claude V. Catap

---

## Screenshots

Add two or three current screenshots under `docs/assets/` and replace these placeholders:

| Dashboard | Calendar | To-Do |
| --- | --- | --- |
| [Add screenshot] | [Add screenshot] | [Add screenshot] |

## What it does

- Keep classes, deadlines, and personal plans together with tasks and events organized by category and schedule.
- See what is coming up in the calendar, with timed items in order and multi-day events shown across their dates.
- Start a focus session with the built-in Pomodoro timer.
- Review weekly focus totals and see how focus time is distributed across task categories.
- Import supported calendar items from Canvas, Google Calendar, and Outlook.

## Built with

| Part | Technology | What it does |
| --- | --- | --- |
| Framework | Flutter and Dart | Builds the web app. |
| App state | Provider | Shares planner state across screens. |
| Local storage | SQLite and IndexedDB | Saves planner data locally; the web build stores the database in browser IndexedDB. |
| Calendar backend | Cloudflare Workers and D1 | Handles calendar sign-in and stores encrypted provider tokens. |

## Running it yourself

### Use the hosted app

If you just want to use Momentum, open the [hosted app](https://momentum-canvas.aerith-catap.workers.dev). You do not need to download the project or install Flutter, Node.js, or Cloudflare tools. To try a calendar, choose **Add calendars** in the app and sign in with the provider. Your planner data stays in the browser you use for this site.

### Set up your own copy

Use this path if you want to run Momentum on your computer, change the code, use your own calendar credentials, or publish your own version. You need Git, Flutter with a Dart SDK version satisfying `pubspec.yaml` (`>=3.12.0 <4.0.0`), and Node.js with npm.

Clone the project and install its Flutter packages from the project root:

```sh
git clone https://github.com/asm0git/momentum.git
cd momentum
flutter pub get
dart run sqflite_common_ffi_web:setup
```

To run the planner on your computer without calendar sign-in, start Flutter's web server:

```sh
flutter run -d web-server --web-port 8080
```

Open `http://localhost:8080`. Browser data is tied to the origin, including its port, so use the same address on later runs.

#### Add calendar sign-in to your local copy

Calendar sign-in needs the Worker to serve both the app and its `/api` routes. A separate `flutter run` server does not provide those routes.

1. Install Worker packages and create the local D1 tables:

   ```sh
   cd worker
   npm ci
   npx wrangler d1 migrations apply momentum-canvas --local
   ```

   On Windows PowerShell, if script execution blocks `npm` or `npx`, use `npm.cmd` and `npx.cmd` for those commands.

2. Copy `worker/.dev.vars.example` to `worker/.dev.vars`. In PowerShell, use `Copy-Item .dev.vars.example .dev.vars`; on macOS or Linux, use `cp .dev.vars.example .dev.vars`.

3. In `worker/.dev.vars`, add the client ID, client secret, and callback URL for the provider you plan to use, plus `TOKEN_ENCRYPTION_KEY`. Generate a 32-byte base64 key with:

   ```sh
   node -e "console.log(require('node:crypto').randomBytes(32).toString('base64'))"
   ```

   Register the matching local callback URL with your provider:

   | Provider | Callback URL |
   | --- | --- |
   | Canvas | `http://localhost:8787/api/canvas/oauth/callback` |
   | Google Calendar | `http://localhost:8787/api/google/oauth/callback` |
   | Outlook | `http://localhost:8787/api/outlook/oauth/callback` |

   Set `APP_ORIGIN = "http://localhost:8787"` in `worker/wrangler.toml` while testing locally. For Canvas, set `ALLOWED_CANVAS_HOST` to your school's Canvas hostname. The [Worker guide](worker/README.md) explains how to create the provider credentials.

4. Return to the project root, build the app, and start Wrangler from the `worker` folder:

   ```sh
   cd ..
   flutter build web
   cd worker
   npx wrangler dev
   ```

   Keep Wrangler running and open `http://localhost:8787`. Use `localhost` consistently for the app and callback URLs.

#### Publish your own version

To host your copy, use your own Cloudflare account and D1 database. Put your database ID in `worker/wrangler.toml`, use your hosted app address for `APP_ORIGIN`, and register each provider's callback URL with that same address. In GitHub Actions, set `CLOUDFLARE_ACCOUNT_ID`, `APP_ORIGIN`, and `ALLOWED_CANVAS_HOST` as variables, and `CLOUDFLARE_API_TOKEN` as a secret. Add provider credentials and `TOKEN_ENCRYPTION_KEY` to your Cloudflare Worker settings. The deployment workflow builds and publishes the app and Worker and applies the D1 migrations. See the [Worker guide](worker/README.md) for provider-specific setup details.

## Environment variables

The Flutter app does **not** read a `.env` file. Settings are declared in different places: the optional Flutter setting is passed when building the app; Worker settings go in `worker/wrangler.toml`; local private credentials go in `worker/.dev.vars`; and deployment settings go in GitHub Actions or Cloudflare. Copy `worker/.dev.vars.example` to `worker/.dev.vars` to see the local credential names. You only need credentials for the provider you plan to connect. Git ignores `.dev.vars` files, so do not commit private values.

| **Variable** | **What it is** | **Where to get one** |
| ------------ | -------------- | -------------------- |
| `CANVAS_BACKEND_URL` | Optional address of the calendar Worker. A web build normally uses the app's own address, so you can leave this unset. | Use your Worker address if it is hosted separately. Pass it when building, for example: `flutter build web --dart-define=CANVAS_BACKEND_URL=https://your-worker.example`. |
| `APP_ORIGIN` | The address of the Momentum app. The Worker uses it when returning from calendar sign-in. | For local testing, use `http://localhost:8787` in `worker/wrangler.toml`. For deployment, set your app address as a GitHub Actions variable. |
| `ALLOWED_CANVAS_HOST` | The hostname of the Canvas site allowed to connect, such as `canvas.school.edu`. Do not include `https://` or a path. | Get the Canvas address from your school. Set it in `worker/wrangler.toml` for local testing or as a GitHub Actions variable for deployment. |
| `CANVAS_CLIENT_ID`, `CANVAS_CLIENT_SECRET`, `CANVAS_REDIRECT_URI` | The app details Canvas needs to sign in and return to Momentum. | Ask your school's Canvas administrator for an approved Developer Key. The local callback URL is in the setup steps above. Put the values in `worker/.dev.vars`; for a hosted Worker, add them in Cloudflare. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` | The app details Google Calendar needs to sign in and return to Momentum. | Create a Web OAuth client in Google Cloud Console. The local callback URL is in the setup steps above. Put the values in `worker/.dev.vars`; for a hosted Worker, add them in Cloudflare. |
| `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_REDIRECT_URI` | The app details Outlook needs to sign in and return to Momentum. | Register an app in Microsoft Entra. The local callback URL is in the setup steps above. Put the values in `worker/.dev.vars`; for a hosted Worker, add them in Cloudflare. |
| `MICROSOFT_TENANT_ID` | Tells Microsoft which account group to use. The default, `common`, allows personal and work or school accounts. | Usually keep the default in `worker/wrangler.toml`. An organization may provide its own tenant ID. |
| `TOKEN_ENCRYPTION_KEY` | A private key the Worker uses to encrypt calendar sign-in tokens it saves. Keep it the same after setup. | Generate it with the command in the setup steps. Store it in `worker/.dev.vars` for local testing or as a Cloudflare Worker secret for deployment. |
| `CLOUDFLARE_ACCOUNT_ID` | Identifies the Cloudflare account that will host your Worker. | Find it in your Cloudflare account. Add it to GitHub under **Settings > Secrets and variables > Actions > Variables**. |
| `CLOUDFLARE_API_TOKEN` | Lets GitHub publish the app and Worker to Cloudflare. | Create a Cloudflare API token for deployment. Add it to GitHub under **Settings > Secrets and variables > Actions > Secrets**. |

Provider client secrets and `TOKEN_ENCRYPTION_KEY` are private. Keep them out of Flutter build commands, GitHub Actions variables, and source control. For a hosted Worker, save them as Cloudflare Worker secrets.

## Privacy and secrets

Tasks, events, categories, focus totals, plans, and local linked-account records live in Momentum's SQLite database. On the web, that database is stored in IndexedDB in the browser and is scoped to the site's origin. Clearing that site's browser data removes the local database.

Calendar sign-in happens on the provider's website; Momentum does not receive your provider password. Calendar imports are read-only. The Worker stores connection details and encrypted provider tokens in D1, with `TOKEN_ENCRYPTION_KEY` used for encryption. Disconnecting deletes the Worker connection and its stored tokens; items already imported into Momentum remain in the local planner. Changes made in Momentum are not written back to the provider calendar.

**Screenshots and demo:** [Confirm whether these include any real personal information before publishing.]

## Project documentation

| Document | What it covers |
| --- | --- |
| [Proposal](docs/01-proposal.md) | Project idea and scope; complete this document as needed. |
| [Mockup and wireframes](docs/02-mockup.md) | Screen designs and app flow. |
| [Design system](docs/03-design-system.md) | Colors, typography, spacing, and components. |
| [Weekly reports](docs/04-weekly-reports.md) | Project progress by week. |
| [Demo video notes](docs/05-demo-video.md) | Video link and timestamps. |
| [Start here](START-HERE.md) | An introduction to the repository. |
| [Security and privacy](docs/06-security-and-privacy.md) | Security and privacy checklist; complete it as needed. |
| [Local database](docs/local-database.md) | Local storage and browser database details. |
| [Calendar Worker guide](worker/README.md) | Local calendar setup and provider instructions. |

## Status and what is next

- The Canvas integration is currently unavailable because administrator approval to register the app on `hau.instructure.com` has not been obtained.
- The Microsoft integration is also unavailable because the university does not permit OAuth app registration through its Microsoft Entra account.
- The AI Planner from the original plan was removed from this version and replaced with the Insights screen. It may be added in a future version when time allows.

## Credits

- Packages: see [`pubspec.yaml`](pubspec.yaml).
- Assets, icons, images, and fonts: [Add creators and license details.]
- People who helped: [Add names and contributions, if applicable.]

## AI use

[Fill in which AI tools were used, what they helped with, and how much of the project they affected. Add a link to `AI-USAGE.md` after that file contains the full details.]

## Licence

MIT. See [LICENSE](LICENSE).
