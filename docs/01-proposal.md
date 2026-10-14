# Proposal


## The problem, in one sentence

Students often manage coursework, deadlines, activities, and personal plans in
separate tools, making it harder to see what needs attention and protect time
for focused work.


## Who it is for

Momentum is designed primarily for students balancing classes, assignments,
extracurricular activities, personal projects, and other commitments. Its
local-first planner can also be useful to anyone who wants a simple place to
organize tasks, events, and focus time.

## Core features

| Area | Feature |
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
  calendar Worker stores the encrypted feed links used for calendar imports,
  but it is not a user account or a sync service for planner data. This keeps
  the current app simpler, with the tradeoff that planner data is not
  automatically shared or synchronized across devices.
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
| Published calendar feed links | Read-only `.ics` URLs used to import calendar items | The Cloudflare Worker encrypts each link with `TOKEN_ENCRYPTION_KEY` before storing it in D1. The key is kept in Worker secrets, not in the Flutter app or planner database. |


## Risks

The earlier proposal considered OAuth flows, but those required provider app
registration. The implemented connection flow instead uses published calendar
feeds. A separate risk became clearer during the Web implementation: locally
stored data are tied to a browser and site origin. The status and next steps
below are assessed as of **2026-10-14**.

| Risk | Status and first step |
| --- | --- |
| Anyone with a published calendar feed link may be able to read that calendar. | Treat the link like a password. The Worker validates feed URLs and encrypts stored links in D1. Disconnecting removes Momentum's stored copy but does not revoke the provider-issued link. **First step:** remind users to keep links private and revoke or regenerate a link through the provider if it is exposed. |
| Local planner data can be lost or appear missing when browser data are cleared or the site origin changes. | IndexedDB is scoped to the browser profile and origin, including the port, and planner data do not have app-level encryption or automatic cloud backup. **First step:** explain the storage limit and advise use of the same browser and address. **Review point:** 2026-10-14; consider backup/export as future work. |
| The Web database adapter adds a browser compatibility dependency. | The project uses `sqflite_common_ffi_web`. **First step:** check persistence in supported browsers when the app or adapter is updated. |


## Changes since the last version

| Date | Section | Earlier plan | Final version and reason |
| --- | --- | --- | --- |
| 2026-10-09 | Core features | The AI Daily Planner was listed as an MVP feature. | The AI Planner was removed from this version and replaced with Insights, which summarizes focus activity recorded by the app. This gives the finished release a feature grounded in data Momentum already collects, while leaving AI planning as a possible future addition when time allows. |
| 2026-10-07 | Data storage | The plan selected `sqflite` for a local database, with web support still undecided. | Planner records use SQLite, with the web database stored in IndexedDB. The earlier OAuth proposal was superseded by published `.ics` feed links; the Worker encrypts those links in D1 and does not sync planner records. IndexedDB makes the SQLite approach usable in the browser while keeping planner data separate from calendar connections. |
| 2026-10-01 | MVP features | A Pomodoro timer was considered as a simpler alternative to more complex planned features. | The Pomodoro timer was added to the MVP because it was more practical to implement and directly supports focused work through structured work and break sessions. It remains in the final app as the Timer screen, with focus time also informing Insights. |
| 2026-09-20 | Stretch goals | Location-based reminders were proposed as a stretch goal. | Location-based reminders remain out of scope because they require location and background-notification support beyond the current web-first version. Keeping them out of the final feature list avoids promising behavior that has not been built or validated. |

