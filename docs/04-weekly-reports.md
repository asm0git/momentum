# Weekly reports

One entry per week, newest at the top, written **during** that week. Five minutes
each. They are the record of how the project actually went, and they make your
final reflection almost write itself.

# Week of: October 4, 2026

## My goal this week
This week, I wanted to move Momentum from a mostly visual prototype into an app that could actually be used. My main goals were to finish the main screens, make tasks and events save properly, and get the timer working beyond its appearance. I also wanted to begin connecting external calendars and prepare the app to run on the web.

## What I did
I polished the To-Do screen, completed the main Dashboard and Timer layouts, and built out the calendar. I also added a shared popup for creating and editing tasks and events, then connected the planner to SQLite so it could save real data instead of relying on mock data. Getting the database to work in the browser took another round of fixes, but I eventually got web storage working through IndexedDB.

I added recurring tasks and events and connected the focus timer to shared state so it could keep running when moving between screens. I also worked on category management, task editing and deletion, and the date and time pickers. Toward the end of the week, I started the Google Calendar, Canvas, and Microsoft calendar connection flows using a Cloudflare Worker, and worked on the deployment configuration. These integrations were still only partly functional. Alongside development, I organized the mockup and design system assets and updated the related documentation.

## What blocked me
The biggest technical problem was getting SQLite to work on the web. The initial database setup did not work the same way in the browser as it would on a mobile device, so I had to work through the web adapter and its supporting files. Recurrence and timer behavior also required more attention because changes needed to stay consistent across several screens.

Calendar integration introduced a different kind of blocker. Canvas required administrator permission to register the app on the university's platform, while Microsoft registration was restricted by the university-managed Entra tenant. These were permissions I could not fix through the app's code. I also encountered Cloudflare build and configuration errors, which took time away from polishing the remaining features.

## What I learned
I learned that completing a screen visually is only one part of making it work. Saving data, handling recurring items, and keeping a timer active across navigation required separating the app's state and database logic from its widgets. Having shared logic made it easier to keep the Dashboard, To-Do, Calendar, and Timer screens consistent.

I also learned that external integrations depend on more than writing the connection flow. Provider permissions, OAuth registration, and deployment settings can prevent a feature from working even when its interface is already built. This helped me become more realistic about the project's scope and more careful about describing which features were ready and which still had limitations.

# Week of: September 27, 2026

## My goal this week
This week, I aimed to generally complete 1-2 screens and a decent amount of core widgets, especially those repeated across different screens like tasks, events, checklists, and cards.

## What I did
I focused on building core reusable UI components, including a dynamic bottom navigation bar and an animated floating action button. On the backend, I established the foundational data models for tasks and events, populating them with mock data for testing. I also structured the main layout for the To-Do screen using collapsible category sections. Finally, I developed the primary task widget, programming it to visually update and automatically move to the bottom of the list when checked off.

## What blocked me
While I did not encounter major technical setbacks, I struggled with time constraints due to my other responsibilities. Within the project itself, I spent a significant amount of time coding the collapsible accordion section widgets for the To-Do screen. Specifically, managing the state of the dropdown toggle while getting the nested ListView.builder to size correctly inside a vertical Column—which required figuring out the shrinkWrap: true behavior—took much longer than expected to prevent unbounded height errors.

## What I learned
Technically, with the help of AI I learned how to conditionally recolor PNGs and SVGs based on active states. Furthermore, I learned how to "vibe code" efficiently through proper prompt engineering. By explicitly defining layout constraints first—such as 16px margins, exact typography, and precise row-by-row widget structures—I was able to guide the AI to generate much better code, which drastically reduced the time I spent debugging layout issues.

# Week of: September 22, 2026

## What changed this week
I had modest progress this week. First, I created and determined the scaffold and file structure of my application. Second, I set up my AI agents that will aid me in creating the projects, and provided them enough context with what I'm working with. Then, I also imported the lines of code I have already started with, such as app_theme.dart. Last, I also used AI to draft the bottom navigation pill, along with other important files.

## Why
These changes are intended to kick-start my project and establish a proper foundation for the development process. Having the project structure, design system, and initial components in place should make it easier to develop the application's main features in the coming weeks.

## What broke or what I got stuck on
I am still in the early stages of development, so I have not encountered any major technical issues yet. However, I am still figuring out how to properly organize the project files and how the different components should work together. I also need to make sure that the code generated with AI fits the structure and requirements of my project rather than relying on it without understanding how it works.

## What is left
Finalize the application's overall UI and reusable components.
Complete the dashboard and bottom navigation.
Implement manual task creation and management.
Implement the calendar and event features.
Connect the application to external calendars.
Develop the AI-powered task prioritization and daily planner.
Implement location-based reminders.
Test, debug, and refine the application.
Complete documentation and prepare the final presentation.

