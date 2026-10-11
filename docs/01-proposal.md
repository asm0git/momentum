# Momentum: Final Project Proposal
## The problem, in one sentence

Students often manage coursework, deadlines, activities, and personal plans in
separate tools, making it harder to see what needs attention and protect time
for focused work.

## Who it is for

Momentum is designed primarily for students balancing classes, assignments,
extracurricular activities, personal projects, and other commitments. Its
local-first planner can also be useful to anyone who wants a simple place to
organize tasks, events, and focus time.

## What users do today instead

Students may keep deadlines in a learning platform, schedules in one or more
calendar apps, and personal reminders in notes or task lists. Moving between
those tools makes it easy to miss a commitment or lose track of how time is
being used. Momentum brings the user's planner items together and can import
calendar information where a provider connection is available.

## Core features

| Area | What the final version provides |
| --- | --- |
| Dashboard | A daily overview of planner items and shortcuts to common actions. |
| To-Do | Create, edit, complete, and remove tasks; group work by category; set due dates, times, estimated durations, priorities, and recurrence. |
| Calendar | Review tasks and events by date. Items appear in time order, events can span multiple dates, and recurring items appear on their scheduled dates. The calendar can be resized between month and compact week views, with a selected-day agenda. |
| Focus timer | Run timed focus and break sessions associated with a selected task. Focus time is recorded for later review. |
| Insights | Review weekly focus totals and how recorded focus time is distributed across categories, with longer-term activity shown in a calendar view. |
| Calendar imports | Connect supported calendar providers through the calendar service and import items into Momentum. Imports are read-only; changes made in Momentum are not written back to provider calendars. |

The main navigation consists of Dashboard, To-Do, Calendar, Timer, and Insights.
Calendar connections are managed in a separate flow. The app does not require a
planner login to use its local task, event, timer, or insights features.

Calendar sign-in uses a Cloudflare Worker. Google Calendar, Canvas, and Microsoft
Outlook connection flows are represented in the project. Google Calendar can
be used when valid OAuth credentials are configured. Canvas is unavailable in
the current university setup because administrator approval to register the app
on `hau.instructure.com` has not been obtained. Microsoft Outlook is likewise
unavailable because the university-managed Microsoft Entra tenant does not
permit the required OAuth app registration.

## Out of scope, and why

- **AI-generated daily planning:** The original plan included an AI Planner.
  That feature is not part of this version; the Insights screen provides a
  review of recorded focus activity instead. An AI Planner may be considered
  for a future version when time allows.
- **Location-based reminders:** The app does not monitor a user's location or
  send a notification when it is time to leave. That would require location,
  mapping, and background-notification work beyond the current web-first scope.
- **Automatic cross-device planner sync and shared accounts:** Tasks, events,
  categories, and focus records remain in the user's local database. The
  calendar Worker supports provider sign-in, but it is not a cloud account or
  sync service for planner data. This keeps the current app simpler, with the
  tradeoff that planner data is not automatically shared or synchronized across
  devices.
- **Writing back to external calendars:** Provider access is intended for
  read-only import. This avoids granting calendar-edit permissions and keeps
  changes in Momentum separate from the original provider calendar.

## Data the app remembers, and where it is saved

Momentum uses SQLite for planner data. In the web build, the SQLite database is
stored in the browser's IndexedDB using the `sqflite_common_ffi_web` adapter.
The database belongs to that browser profile and site origin; clearing that
site's browser data removes it. Planner data is not automatically backed up or
synchronized to another device.

| Data | Examples | Where it is saved |
| --- | --- | --- |
| Categories | Category name and icon | Local SQLite database; browser IndexedDB on Web |
| Tasks | Title, description, due date and time, estimated duration, priority, completion state, recurrence, and import source identifiers when applicable | Local SQLite database; browser IndexedDB on Web |
| Events | Title, start and end dates/times, all-day state, location, notes, recurrence, and import source identifiers when applicable | Local SQLite database; browser IndexedDB on Web |
| Focus totals | Daily focus seconds and totals by category | Local SQLite database; browser IndexedDB on Web |
| Linked-calendar details | Provider, display name, account email when supplied, provider address, associated category, and last sync time | Local SQLite database; browser IndexedDB on Web |
| Calendar display preference | Selected calendar view mode | Local app preferences |
| OAuth tokens | Provider access and refresh tokens used to sync a connected calendar | The Cloudflare Worker stores encrypted tokens in D1. The encryption key is kept in Worker secrets, not in the Flutter app or planner database. |

Calendar imports are one-way. Disconnecting a provider removes its Worker-side
connection and tokens; items already imported into the local planner remain
there. No provider password is stored by Momentum.

## Risks

The external-calendar risk identified in the earlier proposal proved greater
than expected: the OAuth flows could be implemented, but provider registration
depends on university administrators. A separate risk became clearer during
the Web implementation: locally stored data are tied to a browser and site
origin. The status and next steps below are assessed as of **2026-10-11**.

| Risk | Status and first step |
| --- | --- |
| Provider sign-in depends on external approval and credentials. | Google Calendar requires valid OAuth configuration. Canvas and Outlook remain unavailable in the current university setup. **First step:** keep those providers clearly marked unavailable and request registration approval only if the university permits it. **Review point:** 2026-10-11; no approval has been obtained. |
| Local planner data can be lost or appear missing when browser data are cleared or the site origin changes. | IndexedDB is scoped to the browser profile and origin, including the port, and planner data do not have app-level encryption or automatic cloud backup. **First step:** explain the storage limit and advise use of the same browser and address. **Review point:** 2026-10-11; consider backup/export as future work. |
| The Web database adapter adds a browser compatibility dependency. | The project uses `sqflite_common_ffi_web`. **First step:** check persistence in supported browsers when the app or adapter is updated. |
| Calendar tokens require careful server-side handling. | OAuth tokens are encrypted before storage in Worker-side D1. **First step:** keep provider secrets and the encryption key in Worker secret settings or ignored local configuration, never in public source files or Flutter build arguments. |

## Changes since the last version

| Date | Section | Earlier plan | Final version and reason |
| --- | --- | --- | --- |
| 2026-10-09 | Core features | The AI Daily Planner was listed as an MVP feature. | The AI Planner was removed from this version and replaced with Insights, which summarizes focus activity recorded by the app. This gives the finished release a feature grounded in data Momentum already collects, while leaving AI planning as a possible future addition when time allows. |
| 2026-10-07 | Data storage | The plan selected `sqflite` for a local database, with web support still undecided. | Planner records use SQLite, with the web database stored in IndexedDB. The Worker and D1 are used for calendar connections and encrypted OAuth tokens, not for syncing planner records. IndexedDB makes the SQLite approach usable in the browser while keeping planner data separate from the calendar sign-in service. |
| 2026-09-20 | Stretch goals | Location-based reminders were proposed as a stretch goal. | Location-based reminders remain out of scope because they require location and background-notification support beyond the current web-first version. Keeping them out of the final feature list avoids promising behavior that has not been built or validated. |
