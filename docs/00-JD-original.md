# GoalFlow Hackathon — Original Job Description (verbatim)

> Source: shared JD text. Kept unedited for reference.

## Overview

Build a polished cross-platform mobile application that helps users define personal goals, organize them into smaller actions, personalize how they want to work toward those goals, and understand their progress over time.

The application should feel like a modern consumer mobile product rather than a traditional project-management or task-management application.

The primary focus of this task is not simply creating CRUD functionality. The application should demonstrate strong thinking around:

* Personalization
* Goal setting
* Action planning
* Progress tracking
* Consistency
* User experience
* Data organization
* Meaningful feedback
* Scalable application architecture

The final application should have a clean, intuitive, modern UI/UX and a properly structured backend.

## 1. Platform & Technology

### Mobile Application

The mobile application should be developed using:
Preferred: Flutter

The application should be structured so that it can support both Android and iOS.
The UI should be responsive across common mobile screen sizes.

### Backend

Use a proper backend rather than storing application logic entirely inside the mobile application.
Preferred:

* Node.js
* TypeScript
* Express.js or NestJS

Alternative backend technologies may be used only if there is a strong architectural reason.

### Database

Use a proper persistent database.
Preferred options:

* PostgreSQL
* MongoDB

The database architecture should be designed properly rather than relying on hardcoded or locally stored application data.

### API

The mobile application should communicate with the backend through REST APIs or another clearly documented API architecture.
Authentication, authorization, validation and error handling should be implemented on the backend.

## 2. Core Product Objective

A user should be able to come into the application and answer a simple question:

"What do I want to achieve, and how am I going to work toward it?"

The application should then allow the user to:

1. Create a goal
2. Define why the goal matters
3. Set a timeframe
4. Define how they want to approach it
5. Break the goal into smaller milestones
6. Create actionable steps
7. Define their preferred routine
8. Track completed actions
9. Understand whether they are on track
10. Review their progress over time

The experience should remain simple even though the underlying data model may be more sophisticated.

## 3. User Onboarding

Create a short and polished onboarding flow.
The onboarding should collect enough information to personalize the experience without making the user complete a long questionnaire.

### Required onboarding information

The user should be able to provide:

* Name
* Optional profile image
* Main objective
* One or more personal goals
* Goal timeframe
* Preferred schedule
* Preferred days
* Preferred working frequency
* Optional personal constraints
* Preferred progress style

For example:
A user might create:
Goal: Improve physical fitness
Target: Exercise 4 times per week
Preferred time: Evening
Duration: 45 minutes
Preferred days: Monday, Wednesday, Friday, Sunday

The exact example is not important. The system should support different categories of goals.

## 4. Goal Management

Users must be able to create, edit, pause, resume and complete goals.

Each goal should contain at minimum:

* Goal title
* Description
* Category
* Priority
* Start date
* Target date
* Frequency
* Preferred days
* Preferred time
* Status
* Progress
* Milestones
* Actions

### Goal Categories

The application should support general categories such as:

* Health
* Learning
* Career
* Personal
* Finance
* Relationships
* Productivity
* Custom

Users should also be able to create a custom category.

## 5. Goal Breakdown

A goal should not simply exist as one large task.
Users should be able to divide a goal into:

Goal → Milestones → Actions

Example:

Goal: Learn a new language

Milestone 1: Build basic vocabulary
Actions

* Learn 20 words
* Complete one lesson
* Practice for 20 minutes

Milestone 2: Improve conversation
Actions

* Practice speaking
* Complete conversation exercise
* Review previous vocabulary

The hierarchy should be represented clearly in the UI.

## 6. Action / Task System

Users should be able to create actionable items associated with a goal or milestone.

Each action can contain:

* Title
* Description
* Goal
* Milestone
* Due date
* Preferred time
* Estimated duration
* Frequency
* Priority
* Status

### Action states

At minimum:

* Upcoming
* In progress
* Completed
* Missed
* Skipped

The system should preserve historical records rather than simply deleting completed actions.

## 7. Personalization

Personalization is a core requirement of this task.
The application should not assume that every user follows the same schedule.

Users should be able to customize:

* Preferred days
* Preferred times
* Frequency
* Goal priority
* Action difficulty
* Target duration
* Reminder preference
* Progress preferences
* Weekly targets

The system should use these preferences throughout the application.
For example, if one user prefers working in the morning and another prefers evenings, their experience should reflect those preferences.

## 8. Personal Routine

Create a lightweight routine configuration system.
Users should be able to define recurring patterns related to their goals.

For example:
Goal: Reading
Routine:

* Monday
* Wednesday
* Friday
* 8:00 PM
* 30 minutes

Another user could have:
Goal: Reading
Routine:

* Every day
* 7:00 AM
* 15 minutes

The application should support both frequency-based and day-based routines where appropriate.

## 9. Home Dashboard

The home screen is one of the most important parts of the application.
It should immediately answer: "What should I focus on today?"

The dashboard should include some combination of:

* Today's actions
* Active goals
* Progress summary
* Upcoming actions
* Current consistency
* Goal status
* Recently completed items
* Important milestones

Do not overload the screen.
The UI should prioritize the most useful information.

## 10. Progress Tracking

Users should be able to clearly understand how they are progressing.
The application should provide:

Goal-level progress — Example: Learn Spanish, 65% complete
Milestone progress — Example: Vocabulary, 18 / 30 actions completed
Weekly progress — Example: This week, 4 / 5 planned actions completed
Long-term progress — The user should be able to see progress across multiple weeks.

Visualizations can include:

* Progress bars
* Circular indicators
* Simple charts
* Calendar views
* Completion history

Use visualizations only where they improve understanding.

## 11. Progress Status

The system should calculate a meaningful status for each active goal.

At minimum:

* On Track
* Needs Attention
* Behind
* Ahead
* Completed

The exact calculation logic should be documented by the developer.
The status should be based on factors such as:

* Planned actions
* Completed actions
* Missed actions
* Goal timeframe
* Expected progress
* User-defined frequency

Avoid making this a simple percentage-only system.

## 12. Consistency

Introduce a lightweight consistency system.
For example, users may see:

Current consistency: 7 days
This week: 5 / 6 planned
Monthly: 82%

However, do not make the application feel like a game unless the implementation has a clear reason.
The purpose is to help the user understand their progress rather than simply maximize numbers.

## 13. Weekly Reflection

Create a dedicated weekly progress/reflection screen.

The user should be able to see:

This Week

* Goals worked on
* Actions completed
* Actions missed
* Overall progress
* Strongest area
* Area needing attention
* Upcoming priorities

The application may also allow the user to add an optional reflection:

"What went well this week?"
"What made things difficult?"
"What would you like to improve next week?"

This should feel lightweight and optional.

## 14. Goal Details Screen

Each goal should have a dedicated detail screen.

The screen should contain:

* Goal title
* Goal description
* Current status
* Overall progress
* Target date
* Routine
* Milestones
* Actions
* Historical progress
* Reflection/history

The user should be able to edit the goal from this screen.

## 15. Calendar / Schedule

Include a simple calendar or schedule view.

Users should be able to see:

* Planned actions
* Completed actions
* Missed actions
* Upcoming milestones

The calendar should not attempt to replace Google Calendar or other professional calendar products.
It should exist specifically to help the user understand their personal goal-related schedule.

## 16. Notifications

Implement a notification architecture.

Notifications may be used for:

* Upcoming actions
* Due actions
* Goal milestones
* Progress summaries
* Weekly reflection

Notifications should respect user preferences.
The backend should support notification configuration rather than hardcoding notification behavior inside the UI.

## 17. Authentication

Implement a proper authentication system.

At minimum:

* Sign up
* Login
* Logout
* Password reset
* Session/token handling

Optional:

* Google authentication
* Apple authentication

Authentication should be securely implemented.
Do not store passwords in plaintext.

The exact architecture is flexible.
The important requirement is that the code should be modular and maintainable.

## UI/UX Expectations

This is a mobile-first consumer application.

The UI should feel: Modern, Clean, Premium, Simple, Calm, Intuitive, Fast

Avoid making the application look like: Jira, Trello, ClickUp, Enterprise project management software

The experience should feel personal rather than corporate.

### Important UX principle

The user should not need to understand the application's internal architecture.
Complexity should remain behind the interface.

## Required Screens

At minimum, implement:

1. Splash screen
2. Onboarding
3. Login
4. Registration
5. Home dashboard
6. Goals list
7. Create goal
8. Goal details
9. Create milestone
10. Create action
11. Today's actions
12. Calendar/schedule
13. Progress
14. Weekly reflection
15. Profile
16. Settings
17. Notification preferences

The candidate may add additional screens where useful.

The application should demonstrate:

* Clean code
* Reusable components
* Proper state management
* API abstraction
* Error handling
* Form validation
* Secure authentication
* Database relationships
* Proper backend validation
* Meaningful API responses
* Environment configuration
* Logging
* Maintainable folder structure

Do not hardcode business logic throughout UI components.

## Primary User Journey

```
Open App
    ↓
Create Account
    ↓
Complete Onboarding
    ↓
Create Personal Goal
    ↓
Define Goal Preferences
    ↓
Create Milestones
    ↓
Create Actions
    ↓
View Personalized Dashboard
    ↓
Complete Actions
    ↓
View Progress
    ↓
Review Weekly Progress
    ↓
Adjust Goal / Routine
```

This is the minimum end-to-end experience expected.

## What We Will Evaluate

The evaluation will not be based solely on whether the application technically works.

We will evaluate:

**Product Thinking - 20%**
Does the candidate understand how to make goals actionable?
Does the experience feel useful rather than simply being a CRUD application?

**UI/UX - 25%**
Is the application intuitive?
Does it feel polished?
Is information presented without overwhelming the user?

**Frontend Engineering - 20%**
Is the Flutter implementation clean, reusable and maintainable?

**Backend Engineering - 20%**
Is the API properly structured?
Is the database modeled correctly?
Is authentication and authorization handled correctly?

**Documentation & Deployment - 5%**
Can another developer run the project easily?

## Bonus Features

Optional, only if core experience is already strong:

* AI-assisted goal breakdown
* Smart goal suggestions
* Goal templates
* Multiple progress measurement types
* Habit streaks
* Custom metrics
* Calendar integration
* Export progress
* Data visualization
* Offline-first synchronization
* Deep linking
* Push notification scheduling
* Accessibility improvements
* Dark mode

Bonus features should not be prioritized over completing the core requirements.

## Submission Instructions

Required Submission

1. **Demo Video** — Walk through your entire product.
2. **Functional Mobile Application** — Provide a demo video showing the complete user journey.

Source Code: submission strictly not required.

Submission Group (Telegram): https://t.me/+bqJtJI33t-0yOTFl

## Prizes and Opportunities

* Hackathon Winner: full-time job offer as a founding member with a high CTC and base pay.
* Certificates: participants with functional MVPs receive certificates of appreciation if liked by the founders.
* Prizes: may be distributed to the top 3 winners; depends on team, shared later.

## Closing Note

This hackathon is more than a challenge — it's a chance to shape your future while working on one of the most advanced projects out there. It's a test for dedication and obsession towards the role — not just how much you know, but how much you're willing to figure out. You're free to use any AI tool; what matters is how smartly you use it and how much ownership you show.
