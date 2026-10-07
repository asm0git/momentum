<!--
  This is your project's front page. Replace every placeholder below.
  It is the first thing your instructor and any future employer will read, and
  the live link in it is how your project gets opened for grading.

  New here? Read START-HERE.md first. Delete this comment when you are done.
-->

# App Name

> Momentum is a personal study-planning app built for myself — a student balancing academics, extracurricular activities, personal projects, fitness, and everything else competing for my time. Instead of managing schedules, tasks, deadlines, and errands separately across a handful of different apps, Momentum brings everything into one place and intelligently plans my day and sets priorities for me, so I can stay productive and organized without juggling tools.


**Live demo:** https://YOURUSERNAME.github.io/YOUR-REPO/ 
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Aerith Claude Catap

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
| Storage | sqflite |
| Other packages | list the ones that matter, with a word on why |

## Running it yourself

```bash
flutter pub get
cp .env.example .env      # only if your app needs keys, see below
flutter run -d web-server --web-port 8080
```

Then open http://localhost:8080. Requires Flutter (run `flutter --version` and
put yours here).

For Web database asset setup and the same-origin/port requirement for persistent
browser data, see [Local database](docs/local-database.md).

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
