<!--
  This is your project's front page. Replace every placeholder below.
  It is the first thing your instructor and any future employer will read, and
  the live link in it is how your project gets opened for grading.

  New here? Read START-HERE.md first. Delete this comment when you are done.
-->

# App Name

> One sentence: what this app does, and who it is for.

**Live demo:** https://YOURUSERNAME.github.io/YOUR-REPO/ <!-- GitHub Pages is set up already; replace if you host elsewhere -->
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Your Name

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
`docs/06-security-and-privacy.md` for what a public repo means for secrets and
personal data.

---

## Screenshots

Put two or three real screenshots at phone size in `docs/assets/`, then replace
this paragraph with them:

```markdown
| Home | Detail | Add |
| --- | --- | --- |
| ![Home](docs/assets/screen-home.png) | ![Detail](docs/assets/screen-detail.png) | ![Add](docs/assets/screen-add.png) |
```

A repo without screenshots reads as abandoned, whatever the code says.

## What it does

Three to five bullets. What can a user actually do?

- ...
- ...
- ...

## Built with

| | |
| --- | --- |
| Framework | Flutter (Dart) |
| State | `setState` / provider / riverpod (say which) |
| Storage | shared_preferences / Hive / Drift / Firebase / Supabase / other |
| Other packages | list the ones that matter, with a word on why |

## Running it yourself

```bash
flutter pub get
cp .env.example .env      # only if your app needs keys, see below
flutter run -d web-server --web-port 8080
```

Then open http://localhost:8080. Requires Flutter (run `flutter --version` and
put yours here).

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in your own values, and never commit the
result.

| Variable | What it is | Where to get one |
| --- | --- | --- |
| `EXAMPLE_API_KEY` | ... | ... |

## Privacy and secrets

Required section. Two or three honest sentences:

- What personal data this app stores, if any, and where it goes.
- Where the secrets live (`.env` locally, repository secrets in the deploy
  workflow) and what protects the data on the service side (Firestore rules,
  Supabase RLS, or "nothing leaves the device").
- Confirm that all sample data, screenshots and the video contain **no real
  personal information**.

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colors, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Start here](START-HERE.md) | how this repo works (delete once you have read it) |
| [Security and privacy](docs/06-security-and-privacy.md) | the checklist, filled in |

## Status and what is next

Be honest. What works, what is half done, what you would build next. An honest
"known issues" section reads better than a claim the reader disproves in thirty
seconds.

## Credits

- Packages: see `pubspec.yaml`
- Assets, icons, 3D models, sounds: name the author and the licence for each
- People who helped, and how

## AI use

If you used AI while building this, say so here. Honest disclosure is the
standard in this course and increasingly outside it, and reporting heavy use
accurately costs you nothing.

This section is the last 10 points of the finals badge, and it wants three
things:

![Built with AI assistance](https://img.shields.io/badge/built%20with-AI%20assistance-0b5fff)

- the badge above, or one you like better
- a line naming which assistant you used and how much of the work it touched
- a link to [AI-USAGE.md](AI-USAGE.md), where the full account lives

Keep the detail in `AI-USAGE.md` rather than here. This section is the summary a
visitor reads; that file is the record the badge is graded from.

## Licence

MIT, see [LICENSE](LICENSE). Change it if you want different terms.

# Documentation guide (what your docs must contain)

Your Documentation Update is graded in week 1 and again in week 2. Documentation
is not an afterthought: a reader who has never seen your app should be able to
understand what it is, get it running, and use it, from your docs alone. Keep
your documentation in your project repository's `README.md` (and link it, or a
copy, from your workspace `project/`).

Your documentation must contain these sections. Aim for clear and complete, not
long.

## 1. Overview

Momentum is a personal study-planning app built for myself — a student balancing academics, extracurricular activities, personal projects, fitness, and everything else competing for my time. Instead of managing schedules, tasks, deadlines, and errands separately across a handful of different apps, Momentum brings everything into one place and intelligently plans my day and sets priorities for me, so I can stay productive and organized without juggling tools.

## 2. Setup and installation
Built with: Flutter (Dart SDK `>=3.0.0 <4.0.0`)

Steps:
1. Open a terminal.

2. Clone the repo:
  ```bash
  git clone https://github.com/asm0git/momentum.git
  cd momentum
  ```

3. Install dependences:
  `flutter pub get`

> PENDING: 4. Configuration: none required yet, as the app is still under development. This section will be updated

## 3. How to run it
To run it on web, enter this command in your terminal:

  ```bash
  flutter pub get              # fetch packages
  flutter run -d chrome        # launches Chrome
  ```

If no errors show, a Chrome tab should open to preview the app.

## 4. Features and usage

- **Get started → Add Calendars**: on first launch, tap "Get started," then optionally connect Google Calendar, Outlook, Canvas, or iOS Calendar (tap the checkmark to skip/continue either way). This is a one-time flow.
- **Dashboard** (home icon): shows the current date/time, your two main categories with pending-item counts, today's to-do items (tap the checkbox to mark done), and quick-access focus/pomodoro presets.
- **Calendar** (calendar icon): month grid — tap any day to see what's due that day below the grid. Use the arrows to move between months.
- **Timer** (timer icon): pick a pomodoro preset (30/45/60 min), tap play to start the countdown, pause any time. Today's due items are listed below for reference while you work.
- **AI Planner** (sparkle icon): lists today's tasks in time order as a simple starter timeline. (This is a placeholder — see Known Issues.)
- **To-Do** (checkmark icon): tasks grouped by category (Work/Personal/School). Tap a group header to expand/collapse it, tap the top-right icon to switch between the full view (with due date/time/estimate) and a condensed view (titles only).
- **New Event / New Task** (pink "+" button, available on every tab): opens a bottom sheet with an Event/Task toggle at the top. Fill in the title, category, and timing, then save — it appears immediately in the relevant screens.

## 5. Project structure
```bash
lib/
├── main.dart / app.dart # entry point, root MaterialApp
├── core/
│ ├── theme/ # app_theme.dart — colors + ThemeData
│ ├── widgets/ # bottom_nav_shell.dart (persistent nav + FAB),
│ │ category_chip.dart, section_card.dart
│ └── utils/date_utils.dart # small date/time formatting helpers
├── models/ # Category, Task, Event, PomodoroPreset
├── data/app_data.dart # single in-memory data store + seed data;
│ all screens read/write through this
├── services/ # stub adapters for calendar sync + AI planner
└── features/
├── auth/ # Get Started, Add Calendars
├── dashboard/
├── calendar/
├── timer/ # Pomodoro
├── ai_planner/
├── todo/ # To-Do + condensed toggle, one widget
└── task_entry/ # shared New Event/Task bottom sheet
```

## 6. Screenshots

> PENDING: No screens were configured yet

## 7. Known issues and next steps

As of writing, here are the following things that are pending:

1. There are no screens yet. The code exists as a scaffold only — it has never been run on a device or emulator, and hasn't been checked with `flutter analyze`, so nothing is confirmed to actually render or compile cleanly yet.
2. No persistence. All data lives in memory (`lib/data/app_data.dart`) and resets every time the app restarts.
3. Calendar integrations are unimplemented stubs. The Google/Outlook/Canvas/ iOS tiles on the Add Calendars screen don't connect to anything yet — the adapter files exist (`lib/services/calendar_integrations/`) but each `connect()` method is a TODO.
4. The AI Planner isn't AI yet. It currently just sorts today's tasks by time. `lib/services/ai_planner_service.dart` is stubbed for a real scheduling call but not implemented.
5. State management is `setState`-only by design for this version. It's fine at this size, but if more screens/features get added, consider migrating to Provider or Riverpod to avoid deeply threading callbacks through constructors.
6. Colors are approximate, not pulled exactly from Figma's hex values yet.
7. No automated tests.

## How it is graded

See `rubrics.md` in this unit for the exact point breakdown. In short: your setup
and run steps must actually work (that is the largest share), your feature and
usage docs must match what the app really does, and screenshots plus clear
writing carry the rest.

## Security checklist (from week 2)

From week 2 your documentation also includes a completed `SECURITY-CHECKLIST.md`
in your workspace `project/` folder. Copy `security-checklist-template.md` from
this unit and fill it in.

Every row is answered Yes, No or N/A, with one line of evidence in your own
words. "N/A" is a correct answer when it is true, and it needs its reason
written next to it. Fill it in **before** you make your repository public, not
after, because that is the point of it. It is worth 3 of the 15 points in
week 2.

## AI usage

Your repository must also carry an `AI-USAGE.md` and a credit line in the
README. That file is graded separately, as your finals badge, and it is worth
100 points; see the `finals-badge` unit for what goes in it. For your weekly
Documentation Update all that is checked is that the file **exists and is
current**, so start it in week 1 and keep it up as you go.

