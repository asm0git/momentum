# Proposal:
## App name

Momentum (unchanged)

## The problem, in one sentence
Managing my schedule, tasks, and deadlines across different calendars, notes, and reminders consumes so much mental energy that planning becomes a barrier to efficiently completing my work, and often causes me to overlook smaller goals and tasks.

## Who is this for?
The app is primarily for myself, as someone balancing academics, extracurricular activities, personal projects, fitness, and other commitments.

## What do they do today instead?
Instead managing my schedules, tasks, deadlines, and errands separately across different apps, I am creating this app to bring everything into one place and intelligently plan my day and set priorities for me, allowing me to maintain a more productive and organized workflow.

## Core features (MVP), revised

You have now built m4a4 and m5a5. You know roughly what one screen costs you in
hours. Re-score your own feature list against that.

| # | Feature | Still in the MVP? | Honest estimate |
| - | --- | --- | --- | --- |
| 1 | Unified Calendar | keep | 6 hours|
| 2 | AI Daily Planner | keep | 8 hours |
| 3 | Task Management | keep | 5 hours |
| 4 | Location-Based Reminders | 10 hours |
| 5 | Pomodoro/Countdown Timer | 3 hours |

## NEW: How my app saves data

**Required.** Read [`content/extending-your-app/`](../extending-your-app/README.md)
pages 1 to 6 before answering. Then:

- **The question from page 1:** No. The data is personal and very specific to the user's personal tasks, events, or routine.
- **Roughly how many records:** Per week, the app stores roughly 50-150 records, which will include tasks, events, and AI plan.
- **My choice:** For this project, I plan to use sqflite.
- **Why this one and not the others:** Because the app is a personal productivity tool, saving the data directly on the user's device should be enough. Using a service like Firebase would make the app more complicated by adding latency or requiring an internet connection, which overcomplicates the MVP. The tradeoff I accepted is security and multi-device sync, meaning that my data is not hardware-encrypted and stays on one device.
- **What I save, concretely:** I will set distinct tables for tasks (title, deadline, priority) events (title, time, location), ai_plans (daily schedule), and a settings table (calendar API/s).
- **Have I tried it yet?:** Not yet, but I will try it once I begin on the back end. I will adjust my plan accordingly if sqflite is unfeasible for the project.

## NEW: How my project runs when someone else opens it

- **I am keeping the `device_preview` wrapper:** Yes, to ensure the UI scales correctly.
- **My app runs in a browser with `flutter run -d web-server`, start to finish, with every screen reachable:** Not necessarily, because sqflite is not supported on web. If needed, I will instead implement a dummy data fallback or a platform check so that the web build uses memory lists instead of crashing when opening the database. 
- **Anything that needs real hardware degrades to sample data instead of crashing: **The AI planner will fall back to a hardcoded "sample day" if the API files.
- **My project will live in a public repository in my own GitHub account, not the course org. Does anything I plan to build need an API key, a password, or real personal data?** Yes, as I will need a Gemini API key. These will live in an .env file locally, and will not be pushed in the public repo.

| Thing | Fields | Where it is saved |
| --- | --- | --- |
| Task | id (INT), title (TEXT), description (TEXT), due (TEXT), priority (INT), is_completed (INT 0/1 or BOOL) src_platform (TEXT), external_id (TEXT)| sqflite, tasks table |
| Event | id (INT), title (TEXT), start_time(TEXT), end_time (TEXT), location (TEXT), src_platform (TEXT), external_id (TEXT) | sqflite, events table |
| AI Daily Plan | id (INT), plan_date (TEXT), ordered_task_ids (TEXT/JSON String), generated_timestamp (TEXT) | sqflite, ai_plans table |
| Linked Account | id (INT), platform_name (TEXT), account_email (TEXT), api_token (TEXT), last_sync_time (TEXT) | sqflite, linked_accounts table |

## Screens

Update the list. It should agree with your mockup and your wireframes, exactly.

1. Login Page - App splash/entry screen showing the Momentum logo, wordmark, and tagline ("Get started."). Contains one "Add calendars" button, where it directs to the Add Calendars page.

1a. Add Calendars - Shows the Momentum logo at top, followed by a list of four calendar/LMS integration options the user can connect: Google Calendar, Outlook, Canvas, and iOS Calendar, each row with its icon and a chevron indicating it opens an auth/connection flow. A floating checkmark button (bottom-right) confirms selection and proceeds (likely to Dashboard).

2. Dashboard - Presents a summarized view of all pages. Arranged from top to bottom are the following widgets:
   a. Header with page title ("Dashboard") on the curved purple header
   b. Time and date block — current day/date (e.g. "Mon 17 Sept"), large current time (9:30), and an "Up next" panel showing the next event's time range, title, and category
   c. Categories — horizontal row of category summary cards (e.g. Work, Personal), each showing an icon, category name, pending-item count, and a preview of the next item in that category; each card has a chevron to drill in
   d. To-do — a preview list of upcoming to-do items, each with a checkbox/icon, title, time/date, an "estimated duration" checkmark badge, and duration text
   e. Focus — horizontal scrollable row of Pomodoro preset cards (duration + rest time), linking to the Timer page
   f. Bottom navigation bar (Home/Dashboard, Calendar, Timer, AI Planner, To-Do, plus a floating "+" add button)

3. Calendar - Header ("Calendar") with a month/year selector (prev/next arrows), followed by a full month grid with days of the week; the current/selected day is highlighted in a filled circle. Below the grid is a "Today" (or selected-day) agenda list showing that day's items — each with a category icon, title, and, for tasks/events, a time, an estimated-duration badge, and duration text. Special/all-day items (e.g. "birthday event") are styled distinctly (pink text, no checkbox). Ends with the same bottom navigation bar, with the Calendar icon active.

4. Timer (Pomodoro) - Header ("Pomodoro") followed by a horizontal row of preset cards ("Presets": duration + rest time — same widget as the Dashboard's Focus row). Below that is a large circular timer dial (tap to start/pause) showing countdown time, total focus time accumulated, and a progress ring. Beneath the timer is a "Due Today" list of tasks with checkboxes, icons, titles, times, and duration badges (same list-item style as To-Do/Calendar/Dashboard). Bottom navigation bar, Timer icon active.

5. AI Planner - Header ("AI Planner") with a horizontal date strip (days of the week, selectable dates, current day highlighted). Below is an "AI Planner" section label with a sparkle/generate icon, followed by a vertical timetable/schedule view — a time-axis (9 AM, 10 AM, 11 AM...) with colored event blocks (pink for personal/breakfast, dark purple for school/task blocks) showing time range and title, plus a small icon per block. Below the generated schedule is a "Due Today" list (same list-item style as other pages). Bottom navigation bar, AI Planner (sparkle) icon active.

6. To-Do List - Header ("To-Do") followed by collapsible category sections (School, Personal, Work, ...), each with an icon, category name, pending count (in pink/red), and a collapse/expand chevron. Expanded sections show their list of items in the same list-item style (checkbox/status icon, category icon, title, time/date, duration badge). Bottom navigation bar, To-Do (checkmark) icon active.

6a. To-Do Condensed - Same header ("To-Do") but with all categories collapsed by default, showing only each category's icon, name, and pending count with a chevron to expand. Includes an "Add a category" row at the bottom of the list. This is the collapsed/default state of the To-Do page (screen 6 is the expanded state).

7. New Event / New Task - A modal/bottom sheet that overlays the previous page (background page, e.g. To-Do, shown blurred behind it). Contains a segmented toggle at the top ("Event" / "Task") to switch forms. Both share a "Title" field and a "Category" picker (defaults "None").
   - Event form adds: All-day toggle, Start Time (date + time), End Time (date + time), Repeat every (recurrence picker).
   - Task form adds: Deadline (date + time) instead of start/end times.
   Bottom navigation bar remains visible (blurred) behind the sheet, with the "+" add button now shown in pink/active state.

Recurring components/widgets across screens:

Component	Appears on
Curved purple header with white page title	Dashboard, Calendar, Pomodoro, AI Planner, To-Do
Bottom navigation bar (Home, Calendar, Timer, AI Planner sparkle, To-Do checkmark, floating "+" button)	Dashboard, Calendar, Timer, AI Planner, To-Do, To-Do Condensed, New Event/Task
List item row (leading category icon + status icon/checkbox, title, time/date subtext, "~duration" badge with checkmark icon)	Dashboard (To-do widget), Calendar (day agenda), Timer (Due Today), AI Planner (Due Today), To-Do
Category icon set (graduation cap = School, person = Personal, briefcase = Work, crossed-arrows = Gym/Push Day)	Dashboard, Calendar, Timer, AI Planner, To-Do, To-Do Condensed
Pomodoro preset card (timer icon, duration, rest time)	Dashboard (Focus row), Timer (Presets row)
Category summary card (icon, name, pending count, next-item preview, chevron)	Dashboard (Categories), To-Do Condensed (category rows, without preview)
Pending-count badge (pink/red text, e.g. "8 pending")	Dashboard, To-Do, To-Do Condensed
Date strip / month grid with highlighted current day	Calendar (full month grid), AI Planner (week strip)
Modal bottom sheet with Event/Task segmented toggle	New Event, New Task (same component, different active segment)
Floating "+" add button (bottom-right of nav bar)	Dashboard, Calendar, Timer, AI Planner, To-Do — opens the New Event/Task modal
Checkmark confirm FAB	Add Calendars

A few things worth flagging for your AI-instructions doc: the list item row is clearly your most reused widget (5 screens) and should probably be a single shared component with variants (with/without checkbox, with/without status color for special events like birthdays). The New Event/New Task sheet is one component with a toggle, not two separate screens. And To-Do / To-Do Condensed are two states of one screen (expanded vs. collapsed), not distinct pages.

# Tech Stack:
Flutter and sqflite
