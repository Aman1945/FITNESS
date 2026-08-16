# GoalFlow — Features & Functionality

A personal goal-tracking mobile app. Define what you want to achieve, break it into
milestones and actions, and see honestly whether you are on track.

**Flutter** (Android + iOS) · **Node.js + TypeScript + Express** · **MongoDB Atlas** ·
**FCM** (push) · **Email** (OTP, reset, digests)

| | |
|---|---|
| Demo login | `demo@goalflow.app` / `Demo1234` |
| Screens | 20 |
| API endpoints | 53 |
| Collections | 7 |

---

## 1. The product idea

Most goal apps are a to-do list with a due date. They tell you *what* you wrote down,
never whether you are actually going to get there.

GoalFlow answers one question every time you open it: **"What should I focus on today,
and am I on track?"** Everything in the product exists to answer that honestly — which
means it will tell you when you are behind, and why, in a sentence you can act on.

The structure is three levels deep, because a goal you cannot start today is not a plan:

```
Goal          Learn Spanish                      35% · On track
  Milestone     Build basic vocabulary           60%
    Action        Learn 20 new words             25 min · Mon–Fri · 07:30
    Action        Complete one lesson            25 min · Mon–Fri · 07:30
  Milestone     Improve conversation              0%
    Action        Practise speaking aloud
    Action        Review past vocabulary
```

---

## 2. Onboarding

Five short steps, then one atomic commit. A user can never end up half-onboarded with a
profile but no goal.

| Step | Collected |
|---|---|
| 1 | Name, optional profile photo |
| 2 | Main objective — the one thing this year is about |
| 3 | First goal: title, why it matters, category, target date |
| 4 | Preferred days and time of day |
| 5 | Session length and weekly target |

**Those answers are not stored and forgotten.** They become:

- the default routine for every goal created later
- the default duration on every action
- the time reminders are scheduled for
- the tone of the home greeting — a morning person who opens the app at 4pm is told
  *"Your usual morning slot has passed — a short version still counts"*

Each new goal also arrives pre-filled with a **starter breakdown** for its category
(Health, Learning, Career, Finance, Personal, Relationships, Productivity, Custom), so
the user edits a plan rather than inventing one from a blank screen.

---

## 3. Goal management

Create, edit, **pause, resume, complete** and archive.

| Field | Notes |
|---|---|
| Title, description | |
| Why it matters | Motivation is part of the product, not decoration |
| Category | 8 built-in + custom |
| Priority | Low / Medium / High |
| Start and target date | |
| Routine | Daily, specific days, N times per week, or one-off |
| Preferred time, duration | Inherited from onboarding, editable per goal |
| Colour | Used across cards, calendar and charts |

Two behaviours worth calling out:

- **Pausing stops future noise without touching history.** Upcoming actions are removed;
  everything already completed or missed stays exactly as it was.
- **Deleting archives rather than destroys.** Progress you made does not disappear
  because you tidied up.

---

## 4. The plan/log split

This is the decision the whole app rests on, and the reason it is not a CRUD app.

| | Role | Example |
|---|---|---|
| **Action** | the **rule** | "Practise Spanish, 25 min, Mon–Fri, 07:30" |
| **ActionOccurrence** | one **dated instance** | "Wed 13 Aug, completed at 07:52" |

A recurring action has no single status. "Gym on Mon/Wed/Fri" cannot answer *"did I miss
Monday?"* if it is one row. Splitting the rule from the log makes it a lookup:

| Feature | Becomes |
|---|---|
| Today's actions | one indexed query on today's date |
| Missed detection | a job flips `upcoming → missed` when the user's day ends |
| History | occurrences are never deleted, only status-changed |
| Calendar | occurrences already carry a date |
| Weekly progress | count planned vs completed in the week |
| Consistency streak | walk occurrence days backwards |
| Reminders | every occurrence has a scheduled time — that *is* the queue |

Each occurrence carries one of five states: **upcoming, in progress, completed, missed,
skipped**. A *skip* is treated as a decision, a *miss* as a failure — they are counted
differently, because counting them the same punishes honesty.

---

## 5. Home dashboard

One screen, one question. Served by a **single API call** so the app opens instantly
rather than chaining five requests.

- Personalised greeting with what is left today
- Today's actions with one-tap completion
- **Yesterday's misses carried over for one day**, so catching up is easy
- 7-day consistency strip and current streak
- Active goals with progress ring and status chip
- Goals needing attention, with the reason spelled out
- Next milestone, recently completed items, unread notification count
- One-tap theme switch and notification bell in the header

---

## 6. Progress tracking

Four levels, each shown where it is useful:

| Level | Example |
|---|---|
| Goal | *Learn Spanish — 35% complete* |
| Milestone | *Vocabulary — 18 / 30 actions completed* |
| Weekly | *This week — 22 / 33 planned actions* |
| Long-term | 8-week trend, minutes invested, split by category |

Visualisations are used only where they add understanding: a **ring** for goal progress,
a **7-dot strip** for the week, a **thin bar** for milestones. Charts are confined to the
Progress screen so the rest of the app stays calm.

---

## 7. Progress status — the part that is not a percentage

Every active goal is graded **Ahead / On track / Needs attention / Behind / Completed**
from four independent signals:

```
timeRatio  =  how much of the goal's window has elapsed
workRatio  =  completed occurrences / all planned occurrences
adherence  =  last 14 days: completed / (completed + missed)   [skips excluded]
delta      =  workRatio − timeRatio
```

| Condition (first match wins) | Status |
|---|---|
| `workRatio >= 1` | **Completed** |
| goal younger than 7 days | **On track** — grace period, new goals are never shamed |
| `delta >= +0.10` | **Ahead** |
| `delta >= −0.05` and `adherence >= 0.60` | **On track** |
| `delta >= −0.20` or `adherence >= 0.40` | **Needs attention** |
| otherwise | **Behind** |

Every status ships with a plain-language reason the UI shows verbatim:

> *"You've completed 4 of 6 planned sessions this week."*
> *"Only 2 of your planned actions are done with 60 days left. Consider easing the
> routine rather than dropping the goal."*

A coloured chip on its own explains nothing. The sentence is the feature.

---

## 8. Consistency, without gamification

```
Current streak    20 days
This week         22 / 33 planned
Last 30 days      71%
```

A day counts **only if something was planned for it**. Days with nothing planned are
neutral — they neither break nor extend a streak. A rest day you scheduled yourself is
not a failure.

There are no points, badges, levels or leaderboards. The number is there to be true, not
to be maximised.

---

## 9. Calendar & schedule

A month grid showing planned, completed and missed actions plus upcoming milestones. Tap
a day to see its actions, and complete, skip or **reschedule** from there.

It deliberately does not try to be Google Calendar. It exists only to make your
goal-related schedule legible.

---

## 10. Weekly reflection

A dedicated screen, generated automatically each week:

- Goals worked on, actions completed and missed, completion rate
- Strongest area and the area needing attention
- Time invested, and next week's upcoming priorities
- Three optional prompts: **what went well · what was difficult · what to improve**

Reflections are saved per week and kept as history, so you can read back what you said
three weeks ago and see whether you did anything about it.

---

## 11. Notifications

Everything is scheduled by the backend from the user's saved preferences. Nothing is
hardcoded in the UI.

| Type | Channel | When |
|---|---|---|
| Action reminder | push | N minutes before, N is user-set |
| Daily summary | push | at the user's chosen morning time |
| Weekly digest | push + email | user-chosen weekday and time |
| Milestone reached | push + email | on completion |
| **Login greeting** | push | on sign-in — see below |
| Verify email, password reset | email | transactional |

### The login greeting

The same "Welcome back" every time makes an app feel like it is not paying attention, so
the message is chosen from how long you were away:

| Gap | Message |
|---|---|
| First ever sign-in | *Welcome to GoalFlow, Priya* — set your first goal and we will turn it into something you can actually do each day |
| Same day | *Hey again, Sam* — 4 things still open today |
| 1–3 days | *Welcome back, Sam* — 3 actions planned today, starting with Learn Spanish |
| 4–14 days | *Good to see you, Sam* — it has been 9 days, pick one and you are moving again |
| 15+ days | *Welcome back, Sam* — 40 days away, no catching up needed, just start from today |

Copy for a long absence is written to remove guilt rather than add it. Shaming someone on
the day they came back is how you lose them again.

### Preferences

Push and email toggles, reminder lead time, daily summary time, weekly digest day and
time, milestone alerts, and a **quiet hours** window that correctly handles overnight
ranges. Reminders and digests respect quiet hours; a greeting you triggered by signing in
does not, because you are demonstrably awake.

---

## 12. Appearance

**Light / Dark / System**, switchable from the home header in one tap or picked directly
in Settings. The choice is stored on the device, survives sign-out, and applies instantly.

---

## 13. Authentication

Sign up, email verification by 6-digit code, login, logout, password reset by emailed
link, password change, and optional Google sign-in.

| Concern | Approach |
|---|---|
| Passwords | bcrypt, cost 12, never returned or logged |
| Access token | JWT, 15 minutes |
| Refresh token | Random, stored only as a SHA-256 hash, rotated on every use |
| Password change | Signs out every device |
| Account enumeration | Identical responses for known and unknown emails |
| Brute force | Rate limiting on every credential route |
| Authorization | Ownership checked per resource |

---

## 14. Personalisation summary

Everything the brief asks to be customisable is, and is used downstream:

preferred days · preferred time of day · exact start time · frequency
(daily / specific days / N per week / one-off) · goal priority · action difficulty ·
estimated duration · weekly target · reminder lead time · progress style ·
quiet hours · personal constraints · theme

Two users with the same goal get genuinely different schedules, reminders and dashboards.

---

## 15. Screens

| Group | Screens |
|---|---|
| Auth | Splash · Register · Verify email · Login · Forgot password |
| Setup | Onboarding (5 steps) |
| Core | Home · Today · Goals · Goal detail · Calendar · Progress · Weekly reflection |
| Editors | Create/edit goal · Create milestone · Create action |
| Account | Profile · Settings · Notification preferences · Notifications feed |

---

## 16. End-to-end journey

```
Open app → Create account → Verify email → Onboarding
  → Goal created with routine and starter breakdown
  → Personalised dashboard
  → Complete actions, watch progress and status update live
  → Calendar and Progress views
  → Weekly reflection
  → Adjust the goal or routine, schedule rebuilds
```

Every step runs against the deployed backend with no placeholder screens.
