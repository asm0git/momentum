# AI usage

[![Created with GitHub Copilot](https://img.shields.io/badge/Created_with-GitHub_Copilot-000000?logo=githubcopilot&logoColor=white)](https://github.com/features/copilot)
[![Created with OpenAI Codex](docs/assets/openai-codex-badge.svg)](https://openai.com/codex/)

This document records how AI supported Momentum, what was kept or corrected, and which parts were written by the author.

## 1. How I used AI

### 2026-09-22 — Getting started with Momentum

- **Tool:** GitHub Copilot.
- **What I asked for:** I asked AI to create starter screens for Welcome, Add Calendars, Dashboard, Calendar, Timer, AI Planner, To-Do, and the task/event form. I also requested models for categories, tasks, events, and Pomodoro presets, plus shared navigation widgets and placeholder services for Canvas, Google, Outlook, and iOS calendars.
- **What it gave back:** It created feature folders for each screen, model classes, an in-memory sample-data store, a bottom navigation shell, shared cards and category chips, and calendar service files whose connection methods were still marked as unfinished.
- **What I kept, what I changed, and why:** I kept the screen, model, and shared-widget ideas because they identified the main parts the app would need. I later moved the working code into `lib/screens` and `lib/widgets` so it was easier to navigate, discarded the generated theme values, and wrote `app_theme.dart` from my own colors, type scale, spacing, and corner radii.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/a0fb05b07a0ee79e0e7b14b975d773e245a8d1c3
    - https://github.com/asm0git/momentum/commit/141169f32a9a91711e024c3fb89f6ac93190a11e

### 2026-09-23 — Simplifying the starting point and documenting the plan

- **Tool:** GitHub Copilot.
- **What I asked for:** I asked AI to replace the untested feature scaffold with one Flutter screen that ran inside Device Preview. I also asked it to add README sections for the overview, setup, run commands, planned screen behavior, project structure, screenshots, known issues, security checklist, and AI-use record.
- **What it gave back:** It produced a `HomeScreen` with an app bar, icon, tap counter, and button inside an always-enabled Device Preview frame. The README gained clone and run commands, descriptions of every planned screen, the original feature-folder tree, and a list stating that persistence, calendar connections, AI scheduling, exact Figma colors, and tests were still unfinished.
- **What I kept, what I changed, and why:** I kept Device Preview because it let me inspect the app at phone width in a desktop browser, and kept the README's setup commands and explicit list of unfinished features. I removed the generated feature folders, models, and service stubs because they had not been run or checked against my mockup, leaving one runnable screen as the base for rebuilding each feature deliberately.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/08fd5bf7b5f1aea91e084743cac7b08dd75afd62

### 2026-09-25 — Recording the project requirements

- **Tool:** GitHub Copilot.
- **What I asked for:** I asked AI to place my problem statement, target user, five proposed MVP features, time estimates, SQLite choice, proposed database fields, browser limitations, screen descriptions, and design-system values into one project instruction file.
- **What it gave back:** It created `AI-instructions.md` with separate sections for the proposal, local data plan, browser behavior, records for tasks, events, AI plans, and linked accounts, and a screen-by-screen description from Login through the New Task and New Event forms.
- **What I kept, what I changed, and why:** I kept the file as a reference because later AI requests could read the same feature list, data choices, and design details instead of relying on a short prompt. I later changed the AI Planner into Insights and replaced provider login with calendar feed links because those original plans could not be completed reliably within the final version.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/3c6649dc57486b8f2c2ca247f91f72362a764b18

### 2026-09-27 — Building the shared parts of the screens

- **Tool:** GitHub Copilot.
- **What I asked for:** I wrote `navigation_destinations.dart` and `add_task_button.dart`, then asked AI to connect both components to the rounded bottom navigation shell in the same commit. I also asked it to build task rows with a checkbox, category icon, title, due date or time, and estimated duration, using the colors, type styles, spacing, and collapsible Work, Personal, and School groups from my design.
- **What it gave back:** It updated `bottom_navigation_bar.dart` to read its labels, icons, routes, and selected state from my destination enum and placed my animated add button beside the navigation dock. It also created three task-row appearances, expandable category groups, mock categories and tasks, initial versions of the main screens, and screenshots showing the rendered progress.
- **What I kept, what I changed, and why:** I kept the destination enum and add button as separate files I had written because I wanted the shell to consume those definitions instead of owning them. This let me adjust the add button's rotation and open-state color without changing the dock, while the enum gave each destination one title, icon name, and route for the AI-assisted shell to use.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/0b9eae6b11918f1cc6602b06a46397165ea4ffbf
    - https://github.com/asm0git/momentum/commit/d31cf3051043a2ee3b2fd5e5160a4fff02a222b9
    - https://github.com/asm0git/momentum/commit/5e5b27135d7cc5bb50de5bbd5803c3da91a1d0ac

### 2026-09-29 — Making the To-Do screen fit my design

- **Tool:** GitHub Copilot.
- **What I asked for:** I asked AI to remove the separate scrolling area inside each expanded category so the entire To-Do page could scroll as one list. I also asked it to place each task in a rounded surface and align the checkbox, category icon, title, due information, and duration label with the measurements in my mockup.
- **What it gave back:** It changed `collapsible_category.dart` to size expanded lists from their contents and changed `task_widget.dart` to use circular checkboxes, fixed icon areas, rounded row backgrounds, and aligned title and schedule text.
- **What I kept, what I changed, and why:** I kept the layout change that allowed the task list to move with the rest of the page instead of giving each category its own awkward scrolling area. I placed every expanded category inside one rounded surface with 16-pixel padding and 12-pixel gaps between tasks, then fixed each circular checkbox at 24 pixels so it stayed aligned with the category icon, title, and time.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/8f8311d4d0875abdb4edbd776cb589b717e72947

### 2026-09-30 — Starting the Pomodoro timer

- **Tool:** GitHub Copilot.
- **What I asked for:** I had written the first interactive `clock.dart` in the September 29 commit, including the 25-minute countdown, tap-to-start and pause behavior, `MM:SS` formatting, and a standard progress ring. On September 30, I wrote `focus_preset.dart`, revised the clock's presentation, and asked AI to help arrange both widgets on the Timer screen according to my mockup.
- **What it gave back:** It changed `timer_screen.dart` to place my preset card in a horizontal row above my clock, with screen-edge padding, a gap between the two widgets, and full-width layout slots that worked at phone size.
- **What I kept, what I changed, and why:** I kept the preset and clock as separate widgets because the same preset card could later appear on the Dashboard while the clock remained specific to the Timer screen. I replaced the original 220-pixel `CircularProgressIndicator` with a 450-pixel custom-painted ring whose progress arc had rounded ends, which brought the timer much closer to my mockup.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/8f8311d4d0875abdb4edbd776cb589b717e72947
    - https://github.com/asm0git/momentum/commit/f4bb00bab5e12af99f546b4a12e542f7903b7975

### 2026-10-04 — Completing the main screens and updating the design documents

- **Tool:** GitHub Copilot and OpenAI Codex.
- **What I asked for:** I asked AI to make the To-Do categories use full and condensed task rows, place five versions of my work-and-break preset widget above my Timer clock, and build a month calendar with previous and next controls, selectable dates, week rows, and a selected-day task list. For the Dashboard, I requested the current date and time, an Up Next item, category summary cards, a To-Do preview, and the same focus presets, then asked it to embed the mockup and design-system images and update the demo and weekly-report text.
- **What it gave back:** It added `TaskListContainer`, full Calendar, Days, and Week widgets, configured five Timer presets using my `FocusPreset` component, added Dashboard category cards, Up Next selection, task previews, focus shortcuts, and bottom-navigation updates. It also moved the supplied visual assets into labeled folders and expanded `docs/02-mockup.md`, `docs/03-design-system.md`, `docs/04-weekly-reports.md`, and `docs/05-demo-video.md` with the material available at that stage.
- **What I kept, what I changed, and why:** I kept my task-row and preset widgets in use across the Dashboard, Timer, Calendar, and To-Do screens so dates, durations, and focus choices did not change appearance between tabs. On the Dashboard, I fixed each category card at 160 pixels wide and placed the cards in a horizontal scrolling row so several categories remained readable without squeezing them into the phone viewport.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/ee0253239a3e2277d7f4b56dee37048fe445760e
    - https://github.com/asm0git/momentum/commit/fcb0b1516ad508266cfbbe5865e52f1975ef0c04
    - https://github.com/asm0git/momentum/commit/ec5761769aa415efc8f9875ed035e5c3d04f97f2
    - https://github.com/asm0git/momentum/commit/3af91c87629b7ef99cc75d947fb5786344879975

### 2026-10-06 — Adding one form for tasks and events

- **Tool:** OpenAI Codex.
- **What I asked for:** I asked AI to make the floating add button open one rounded popup with an Event/Task segmented selector, a title field, and a category dropdown populated from the mock categories. I also asked it to remove stray borders from the Timer and navigation controls, add a separate all-day icon, and verify the visual differences between event rows and task rows.
- **What it gave back:** It created `add_item_popup.dart` with the selector and form fields, connected the popup to my add button, adjusted borders and spacing in the Timer, navigation, and task-list widgets, added `all-day.png`, and added `event_task_widget_test.dart`.
- **What I kept, what I changed, and why:** I kept the single Event/Task popup because the same add button appears on every main screen and should always open the same entry point. I kept its segmented selector, title field, and category menu, then adjusted the surrounding task rows and controls so the two item types were distinguishable without using a second form design.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/72718ed135b410e5f47ab485a96726d378e1523e

### 2026-10-07 — Getting tasks and events to save

- **Tool:** OpenAI Codex.
- **What I asked for:** I asked AI to replace the temporary planner data with local SQLite storage and connect the existing task and event forms to it. After the first attempt did not save and reload tasks reliably on Flutter Web, I asked it to trace the browser persistence flow and correct the update and reload behavior.
- **What it gave back:** It first added `DatabaseHelper`, model-to-database conversion, `PlannerRepository`, and `PlannerState`, together with the web database factory, SQLite worker, and WASM file. The follow-up removed the task ID from update values, checked the saved row after an update, reloaded the saved task through `PlannerState`, and changed the seed behavior so sample tasks could not be mistaken for records that had actually persisted.
- **What I kept, what I changed, and why:** I kept one repository and planner state for both tasks and events so the To-Do, Calendar, and Dashboard screens read the same saved records. In the same commit, I replaced the inline category dropdown Codex had generated on October 6 with my reusable `Selector` so the category and repeat fields could share the same menu behavior and styling. I kept the web adapter and its worker and WASM files, but revised the database to version 2, cleared the old seeded task rows, stopped inserting sample tasks into new databases, and added checks that failed clearly when a task could not be updated or reloaded.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/ecd4538eb8ceb891c3b1dde3358cafbdbd83d228
    - https://github.com/asm0git/momentum/commit/bf76654c9616752f3354beef42d5d74e0d41f42e

### 2026-10-09 — Adding recurrence and shared focus state

- **Tool:** OpenAI Codex.
- **What I asked for:** I asked AI to add Never, Every day, Every week, Every month, and Every year repeat choices with an optional end date, generate the matching task and event occurrences inside any requested date range, and save those settings in SQLite. I also asked it to move the countdown state out of the `Clock` widget I had written so a focus session would continue after switching tabs.
- **What it gave back:** It added recurrence fields and serialization, date-range occurrence generation in `recurrence.dart`, recurring-item queries in `PlannerRepository` and `PlannerState`, repeat controls in the add-item form, and occurrence-aware lists on the Dashboard, Calendar, and To-Do screens. It also added `FocusTimerState` and connected it to my existing `Clock` and `FocusPreset` widgets for the selected preset, remaining seconds, running state, and completed focus time, together with database, recurrence, navigation, and timer tests.
- **What I kept, what I changed, and why:** I kept recurrence in the data layer because repeating items needed to appear consistently on the Dashboard, Calendar, and To-Do screens without each screen calculating them differently. I kept my clock face and preset components while using the shared timer state so a running session would not reset during navigation, then adjusted the forms and screen connections so both features worked with the planner data already saved locally.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/622b849e56f5c387cf719785d64d0b71519ad076

### 2026-10-10 — Building calendar connections and hosted deployment

- **Tool:** OpenAI Codex.
- **What I asked for:** After writing welcome_screen.dart, I asked AI to build the Add Calendars and provider screens that followed it; send OAuth redirects and callbacks through a Cloudflare Worker; encrypt access and refresh tokens before saving them in D1; and map Canvas assignments, Canvas events, Google events, and Microsoft Graph events into Momentum's planner. My Welcome screen and the AI-assisted calendar flow were committed together in `e09d075`. I also asked AI to deploy the Flutter build and Worker through GitHub Actions at a `workers.dev` address and fix the Add Calendars screen when the first hosted build failed.
- **What it gave back:** It connected my Welcome screen to the Add Calendars flow, added provider-specific connection screens, Flutter backend clients, Worker routes for sessions, OAuth callbacks, connection status, synchronization, and disconnection, and D1 tables for sessions and encrypted credentials. It also added provider logos, environment examples, Worker tests, the web deployment workflow, production Wrangler settings, and the layout and asset changes required by the hosted build.
- **What I kept, what I changed, and why:** I kept the Worker and D1 separation because OAuth secrets and encrypted tokens could remain outside the public Flutter bundle, while the app only called connection, status, sync, and disconnect endpoints. I changed the GitHub deployment workflow and `wrangler.toml` settings to use the `workers.dev` deployment, registered the three provider image assets in `pubspec.yaml`, and centered the Add Calendars content after the first hosted build failed; the OAuth flow was later replaced because university-controlled registration prevented reliable use.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/e09d07521af06a1d1a84fa06876a2becb6a40328
    - https://github.com/asm0git/momentum/commit/eae1665968965fc8bd008a3cbc96d58c8ae295ca
    - https://github.com/asm0git/momentum/commit/13a3c1f8b5a7111fd90a4f17db86bfb40e18781c
    - https://github.com/asm0git/momentum/commit/791a57ca78e11d176086fac5682fcdb080a721b3
    - https://github.com/asm0git/momentum/commit/6f4b96b3286644ca306ec9c6b896a590a4e357b7
    - https://github.com/asm0git/momentum/commit/0b3bb97aea1e301f3e8374037cbd366cf9e70bb0

### 2026-10-11 — Improving the calendar, hosted app, and Insights

- **Tool:** OpenAI Codex.
- **What I asked for:** I asked AI to replace the calendar's category icons and item counts with titles ordered by all-day status and scheduled time, draw multi-day events continuously across week cells, show three bars and `+N more`, and add a one-week date-only resize endpoint while preserving date selection and the agenda. I also asked Codex to replace the unfinished AI Planner with the first version of `insights_screen.dart`, using saved focus sessions for a weekly bar chart, a category summary, and a 52-week heatmap. For the hosted app, I asked it to constrain the layout to a 430 × 900 phone viewport, correct provider connection and disconnection states, and match the Insights week heading and arrow buttons to Calendar.
- **What it gave back:** It added persisted calendar height modes and resize snapping, chronological title lanes, multi-day spans, three-row overflow handling, and the compact one-week grid, plus the responsive viewport and corrected provider-state behavior. Codex generated the Insights screen and connected it to the focus totals exposed by `PlannerState`. I wrote `CircularIconButton` during this work and committed it in `9171473` alongside the AI-assisted calendar changes; Codex then used it for the Calendar controls, and it was later used for the matching Insights controls.
- **What I kept, what I changed, and why:** I kept the calendar's titled, chronological items and multi-day event bars because they showed more useful information than the old icons and counts, but reduced each date from five visible bars to three because the week rows took too much space away from the selected day's agenda. I kept the 430 × 900 hosted viewport and the generated Insights charts, then corrected the provider panel's status and disconnect behavior, made the Insights week begin on Sunday, matched its week-range type and arrow buttons to Calendar, and centered the hover label with enough padding around its text.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/91714737b3b1fa43a3fe067970b85e29af1d59ec
    - https://github.com/asm0git/momentum/commit/602ee65233a859965e3c6d10de8d15aec7daa9f8
    - https://github.com/asm0git/momentum/commit/f88e30cc56424218df9b49c82e8a3b19eda83f6c
    - https://github.com/asm0git/momentum/commit/74c29f43eb6ce1cd59c4a7a6023db3a198ba18d3
    - https://github.com/asm0git/momentum/commit/d03e83e88f59b205fdbb1f6faeef88bfb1123944
    - https://github.com/asm0git/momentum/commit/e496163e66236091a8fcc0a3a001cc04d4311148
    - https://github.com/asm0git/momentum/commit/2d99142f82d554ab38bb64f1ec612c29e0bd3370
    - https://github.com/asm0git/momentum/commit/e30d4468fb1223b12d01fc501c1de4e49896efad

### 2026-10-12 — Replacing OAuth with calendar feeds

- **Tool:** OpenAI Codex.
- **What I asked for:** I asked AI to replace Google, Outlook, and Canvas OAuth buttons with fields for private ICS feed URLs, add connect, manual sync, last-synced, error, and disconnect states, and keep imported calendar records read-only.
- **What it gave back:** It added ICS feed storage and synchronization to the Worker and D1 schema, feed parsing and tests, Flutter connection panels, automatic refresh, imported-item handling, and confirmation actions.
- **What I kept, what I changed, and why:** I kept calendar feeds as the import method because they provided read-only access without requiring university approval for Google, Microsoft, or Canvas OAuth registration. I changed the provider panels from sign-in actions to private URL fields with explicit sync and disconnect controls, while keeping imported items read-only so an external calendar could not be edited accidentally from Momentum.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/fa0cc15ff8f40c43683a606778b4be939c31d27f

## 2. Where the AI got it wrong

AI helped me move forward, but I still had to review its output against my design files, project limits, and intended audience. The links below show the implementations I corrected or the later versions I decided to keep.

### Case 1 — The interface did not consistently follow my design system

- **What it gave me:** This was the most consistent problem I had with AI throughout the project. Whenever I asked it to add or restyle a widget, it tended to make the screen work first and add its own font weights, spacing, heights, and corner radii instead of checking `app_theme.dart`. For example, the first To-Do rows used normal body weights even though my design needed semibold task titles and medium supporting text. The first add-item popup also repeated values such as `height: 44` and `BorderRadius.circular(100)` directly inside the widget.
- **What was wrong with it:** These choices made new widgets look close to the mockup on their own but inconsistent beside the rest of the app. The problem kept returning in task rows, popup fields, calendar controls, provider panels, and Insights, so I could not assume that a working AI-generated widget already followed my design system.
- **What I did instead:** I fixed the shared theme myself and then corrected the affected widgets. I changed `bodyMedium` to semibold and `bodySmall` and `labelSmall` to medium for the To-Do hierarchy, added `popupFieldHeight` and the missing radius values to `app_theme.dart`, and replaced repeated popup measurements with those shared constants. I also wrote `CircularIconButton` so the add button and calendar controls could share the same shape, padding, icon sizing, and color behavior. After every AI UI change, I still compared the result with my mockup and corrected the theme usage by hand.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/8f8311d4d0875abdb4edbd776cb589b717e72947
    - https://github.com/asm0git/momentum/commit/72718ed135b410e5f47ab485a96726d378e1523e
    - https://github.com/asm0git/momentum/commit/ecd4538eb8ceb891c3b1dde3358cafbdbd83d228
    - https://github.com/asm0git/momentum/commit/91714737b3b1fa43a3fe067970b85e29af1d59ec
    - https://github.com/asm0git/momentum/commit/e496163e66236091a8fcc0a3a001cc04d4311148

### Case 2 — The first calendar backend was more complicated than the app needed

- **What it gave me:** When I asked for ways to connect Canvas, Google Calendar, and Microsoft Outlook, AI implemented the full OAuth process. This included provider app registrations, redirect and callback routes, access and refresh tokens, encrypted D1 storage, connection screens, synchronization endpoints, and separate provider settings in the Cloudflare Worker.
- **What was wrong with it:** The approach depended on permissions that were outside my control. Canvas required approval from the administrator of `hau.instructure.com`, while Microsoft registration was restricted by the university's Entra setup; the amount of backend code also made deployment and troubleshooting harder than the read-only calendar feature required.
- **What I did instead:**  I made the decision to replace provider sign-in with private ICS feed links for Canvas, Google Calendar, and Outlook. I changed the Flutter connection flow, Worker routes, D1 schema, provider status handling, and tests so users could add a feed URL, sync read-only events, see the last sync result, and disconnect without completing an OAuth registration. I chose ICS myself, then asked Codex to implement it.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/e09d07521af06a1d1a84fa06876a2becb6a40328
    - https://github.com/asm0git/momentum/commit/fa0cc15ff8f40c43683a606778b4be939c31d27f

### Case 3 — The first Flutter Web SQLite attempt did not reliably save and reload tasks

- **What it gave me:** AI added a conditional database factory for native and Web builds, the `sqflite_common_ffi_web` adapter, the SQLite worker and WASM files, and repository and state classes for tasks and events. The first commit was still marked as only partially integrated because the browser version needed another round of fixes.
- **What was wrong with it:** When I tried the first version on Flutter Web, seeing tasks on screen did not prove that IndexedDB persistence was working because the database inserted sample tasks automatically. Task updates also sent the existing primary-key ID back in the update values and reported success from the affected-row count without reading the record back, while `PlannerState` returned the in-memory task without confirming that it could be reloaded. This made task edits and category changes unreliable to verify in the browser.
- **What I did instead:** I kept the web database factory, worker, and WASM setup, then revised the database to version 2. I removed sample-task seeding, cleared the old seeded task rows during the upgrade, removed the ID from task update values, read the task back to confirm its saved category, and made `PlannerState` report an error when the saved task could not be reloaded. I also kept the added checks for moving a task between categories and reopening the database so persistence was tested against stored records.
- **Commits:**
    - https://github.com/asm0git/momentum/commit/ecd4538eb8ceb891c3b1dde3358cafbdbd83d228
    - https://github.com/asm0git/momentum/commit/bf76654c9616752f3354beef42d5d74e0d41f42e

## 3. Who wrote what

### Written by me

- **File:** `lib/app_theme.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/0b9eae6b11918f1cc6602b06a46397165ea4ffbf
- **What it does and why it is built this way:** I wrote this file to keep Momentum's colors, spacing, corner radii, and text styles in one place. I made that decision after noticing that screens were starting to use slightly different padding and font weights, especially after AI-generated UI changes, so I needed one file I could check and correct myself.

- **File:** `lib/navigation_destinations.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/d31cf3051043a2ee3b2fd5e5160a4fff02a222b9
- **What it does and why it is built this way:** I wrote the `AppDestination` enum before asking AI to connect it to the navigation shell, and both parts were committed together. I kept each destination's title, icon name, and route in the enum so the shell could build its buttons from one list instead of repeating that information in the layout.

- **File:** `lib/widgets/add_task_button.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/d31cf3051043a2ee3b2fd5e5160a4fff02a222b9
- **What it does and why it is built this way:** I wrote this as a separate component before asking AI to connect it beside the bottom navigation dock, and both changes were committed together. I wanted the button to own its rotation and open-state color while the navigation shell controlled when the task or event menu opened.

- **File:** `lib/widgets/circular_icon_button.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/91714737b3b1fa43a3fe067970b85e29af1d59ec
- **What it does and why it is built this way:** I wrote this after the add button and calendar arrows began repeating the same circular container and icon setup, then committed it in `9171473` alongside the AI-assisted calendar changes. The buttons needed different icons and fills, so I exposed only those changing parts and kept the shape, padding, tooltip, and animation behavior in one place.

- **File:** `lib/widgets/primary_app_bar.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/d31cf3051043a2ee3b2fd5e5160a4fff02a222b9
- **What it does and why it is built this way:** I wrote one curved purple app bar because copying an `AppBar` into every screen made it too easy for the title style or bottom curve to change in one place and not another. My first version read its title from `AppDestination`; Codex later added blur, action buttons, and a custom-title option without replacing that shared structure.

- **File:** `lib/widgets/focus_preset.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/f4bb00bab5e12af99f546b4a12e542f7903b7975
- **What it does and why it is built this way:** I wrote the preset card with separate work and break values because hardcoding one 30-minute option would have forced me to copy the whole layout for every duration. Codex later added its tap action and connected it to the shared timer state, but I kept the card itself reusable between the Dashboard and Timer screens.

- **File:** `lib/screens/welcome_screen.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/e09d07521af06a1d1a84fa06876a2becb6a40328
- **What it does and why it is built this way:** I wrote this screen and committed it in `e09d075` together with the Add Calendars and OAuth work produced with Codex. I kept the opening screen limited to the Momentum logo and one Get Started button because adding setup details there made the first step feel crowded, and I used route replacement because a normal push left Welcome in the back stack and allowed the user to return to onboarding by mistake.

- **File:** `lib/widgets/selector.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/ecd4538eb8ceb891c3b1dde3358cafbdbd83d228
- **What it does and why it is built this way:** I wrote this during the October 7 persistence work to replace the inline category dropdown Codex had generated in the add-item popup the day before. I needed the category field to show an icon and allow no category while the repeat field only needed text, so I made those parts optional and reused one dropdown design for both.

- **File:** `lib/widgets/clock.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/8f8311d4d0875abdb4edbd776cb589b717e72947 and https://github.com/asm0git/momentum/commit/f4bb00bab5e12af99f546b4a12e542f7903b7975
- **What it does and why it is built this way:** I wrote the countdown, tap-to-start and pause behavior, and `MM:SS` formatting in `8f8311d`, then revised its presentation in `f4bb00b`. I first used Flutter's standard 220-pixel circular progress indicator, but it could not match the thick rounded ring in my mockup, so I replaced it with a 450-pixel custom painter; Codex later moved the countdown state out of the widget so it could continue when I changed screens.

### The AI-written part I understand best

- **File:** `lib/screens/insights_screen.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/2d99142f82d554ab38bb64f1ec612c29e0bd3370
- **What it does and why I kept it:** Codex generated this screen as the replacement for AI Planner. It asks `PlannerState` for focus totals grouped by day and category, displays them as a weekly bar chart, category ring, and 52-week heatmap, and listens to `focusHistoryRevision` so it reloads after a focus session is saved. I had to keep revisiting the week heading, Sunday-first order, arrow buttons, and hover label because the first versions did not line up with Calendar or center correctly, but I kept the screen because it made the Pomodoro history useful.

- **File:** `lib/widgets/dashboard_category_card.dart`
- **Commit:** https://github.com/asm0git/momentum/commit/fcb0b1516ad508266cfbbe5865e52f1975ef0c04
- **What it does and why I kept it:** This card gives each category a small Dashboard preview with its pending count and next item. The difficult part was keeping long task titles readable inside a horizontal list at phone width, so I kept a fixed card size and limited the text instead of letting one category stretch the whole row.
