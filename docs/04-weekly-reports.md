# Weekly reports

One entry per week, newest at the top, written **during** that week. Five minutes
each. They are the record of how the project actually went, and they make your
final reflection almost write itself.

# Week of: September 27, 2026

## My goal this week
This week, I aimed to generally complete 1-2 screens and a decent amount of core widgets, especially those repeated across different screens like tasks, events, checklists, and cards.

## What I did
I focused on building core reusable UI components, including a dynamic bottom navigation bar and an animated floating action button. On the backend, I established the foundational data models for tasks and events, populating them with mock data for testing. I also structured the main layout for the To-Do screen using collapsible category sections. Finally, I developed the primary task widget, programming it to visually update and automatically move to the bottom of the list when checked off.

## What blocked me
While I did not encounter major technical setbacks, I struggled with time constraints due to my other responsibilities. Within the project itself, I spent a significant amount of time coding the collapsible accordion section widgets for the To-Do screen. Specifically, managing the state of the dropdown toggle while getting the nested ListView.builder to size correctly inside a vertical Column—which required figuring out the shrinkWrap: true behavior—took much longer than expected to prevent unbounded height errors.

## What I learned
Technically, with the help of AI I learned how to conditionally recolor PNGs and SVGs based on active states. Furthermore, I learned how to "vibe code" efficiently through proper prompt engineering. By explicitly defining layout constraints first—such as 16px margins, exact typography, and precise row-by-row widget structures—I was able to guide the AI to generate much better code, which drastically reduced the time I spent debugging layout issues.

## Week of: September 22, 2026

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

