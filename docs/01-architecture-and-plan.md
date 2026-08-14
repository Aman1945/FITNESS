# GoalFlow — Architecture & Build Plan

Stack decided: **Flutter (mobile) + Node.js/TypeScript/Express (API) + MongoDB Atlas (DB) + Firebase Cloud Messaging (push) + Resend (email).**

---

## 1. The one idea that wins this hackathon

The JD says twice: *"not simply CRUD"*. Almost every submission will build
`Goal → Milestone → Action` as three collections and call it done. That breaks the
moment you ask *"what should I do today?"* and *"did I miss Monday's workout?"* —
because a recurring action has no single status.

**Our differentiator: separate the *plan* from the *log*.**

- `Action` = the **template/rule** ("Practice Spanish, 20 min, Mon/Wed/Fri, 8 PM").
- `ActionOccurrence` = one **dated instance** of it ("Wed 13 Aug, status: completed at 20:14").

A nightly scheduler materialises occurrences for the next N days from each user's
routine. This single decision gives us, almost for free:

| Requirement | How occurrences solve it |
|---|---|
| Today's actions (§9) | `find({ user, scheduledDate: today })` — no computation in the UI |
| Missed state (§6) | Cron flips `upcoming → missed` after the day ends |
| History preserved (§6) | Occurrences are never deleted, only status-changed |
| Calendar view (§15) | Occurrences already carry a date — trivial query |
| Weekly progress 4/5 (§10) | `planned = count(occurrences this week)`, `done = count(completed)` |
| Consistency streak (§12) | Walk occurrence days backwards |
| On Track / Behind (§11) | Compare completed vs *planned-so-far*, not vs a guessed number |
| Notifications (§16) | Every occurrence has a `scheduledAt` → that IS the reminder queue |

Everything the JD asks for downstream falls out of this model. Say this line in the
demo video — it is the "product thinking" 20%.

---

## 2. Why this exact tech stack

| Layer | Choice | Reason |
|---|---|---|
| Mobile | Flutter 3.x | JD preferred; one codebase → Android + iOS |
| State | Riverpod 2 (+ `freezed`) | Compile-safe DI, easy to keep business logic out of widgets (JD explicitly forbids logic in UI) |
| Routing | `go_router` | Declarative, auth redirect guard, deep-linking bonus for free |
| Networking | `dio` + interceptors | One place for auth header, refresh-token retry, error mapping |
| Local | `flutter_secure_storage` (tokens), `hive` (cache) | Secure tokens; cache enables "offline read" bonus |
| Backend | Node 20 + TypeScript + Express 5 | JD preferred; Express keeps the layering visible for reviewers |
| Validation | `zod` | Schema at the edge, types inferred — proves "backend validation" |
| DB | MongoDB Atlas + Mongoose | JD preferred; flexible for varied goal categories/metrics |
| Jobs | `node-cron` (+ BullMQ/Redis if time) | Materialise occurrences, mark missed, send reminders |
| Push | **Firebase Cloud Messaging** (`firebase-admin`) | Free, works on both platforms, backend-driven sends |
| Email | **Resend** (`resend` SDK + React Email) | Beautiful transactional email in minutes; verification, password reset, weekly digest |
| Logging | `pino` + `pino-http` + request id | JD asks for logging explicitly |
| Docs | `swagger-ui-express` from OpenAPI | JD asks for "clearly documented API" |
| Deploy | Railway/Render (API), Atlas (DB), APK via GitHub Release | Judge should be able to install and run |

### Firebase vs our own auth — important decision

**We do NOT use Firebase Auth as the source of truth.** The JD grades
"is authentication and authorization handled correctly" on *our* backend. So:

- Email/password auth = **our** backend (argon2id hash, JWT access + rotating refresh).
- Firebase is used **only for FCM push messaging** (and optionally to *verify* a
  Google sign-in ID token server-side, then issue **our** JWT).

That way we own the session logic (the graded part) and still get free push.

### Resend — what it's actually used for

1. **Verify email** on signup (6-digit code, 10-min TTL).
2. **Password reset** — single-use token, hashed in DB, 15-min TTL. (JD §17 requirement.)
3. **Weekly reflection digest** — Sunday evening "Your week in 30 seconds" email that
   deep-links into the app's Weekly Reflection screen. This is the demo-video moment:
   push notification + a genuinely nice email, both driven by backend preferences.
4. **Milestone achieved** — celebratory email, only if the user enabled it.

All four are React Email templates in `src/emails/`, rendered server-side. Every send
goes through one `NotificationService` that checks `NotificationPreference` first —
never called directly from a controller.

---

## 3. System diagram

```
┌──────────────────────────────┐
│      Flutter App             │
│  presentation → application  │
│  → domain → data (repos)     │
└───────────┬──────────────────┘
            │ HTTPS  REST /api/v1  (JWT Bearer)
            ▼
┌──────────────────────────────────────────────┐
│  Express API (TypeScript)                    │
│  routes → validate(zod) → controller         │
│         → service (ALL business logic)       │
│         → repository → Mongoose              │
│                                              │
│  cross-cutting: authGuard, ownershipGuard,   │
│  errorHandler, pino logger, rate-limit       │
└───┬──────────────┬───────────────┬───────────┘
    │              │               │
    ▼              ▼               ▼
┌────────┐   ┌───────────┐   ┌──────────────┐
│MongoDB │   │ Scheduler │   │Notification  │
│ Atlas  │   │ node-cron │──▶│  Service     │
└────────┘   └───────────┘   └──┬────────┬──┘
                                │        │
                          FCM ◀─┘        └─▶ Resend
                       (push)              (email)
```

**Cron jobs**
| Job | Cadence | Does |
|---|---|---|
| `materialiseOccurrences` | 00:10 daily (per-tz) | Create next 7 days of occurrences from routines |
| `markMissed` | 00:20 daily | `upcoming` → `missed` for yesterday |
| `sendReminders` | every 15 min | Occurrences due in the next 30 min, honouring quiet hours |
| `weeklyDigest` | Sun 19:00 local | Build week summary → FCM push + Resend email |
| `recomputeGoalStatus` | 01:00 daily | Cache `status` + `progress` on each goal |

---

## 4. Data model (MongoDB / Mongoose)

```
User ─┬─< Goal ─┬─< Milestone ─< Action ─< ActionOccurrence
      │         └─< Action (goal-level, milestone optional)
      ├─< Routine        (attached to a goal)
      ├─< WeeklyReflection
      ├─< DeviceToken    (FCM)
      ├── UserPreferences   (embedded)
      └── NotificationPreference (embedded)
```

### User
`name, email(unique, lower), passwordHash(argon2id, select:false), avatarUrl,
emailVerifiedAt, mainObjective, timezone, preferences{}, notificationPreference{},
refreshTokenHashes[], createdAt`

`preferences` (drives personalisation everywhere — §7):
`preferredDays[0-6], preferredTimeOfDay(morning|afternoon|evening|night),
preferredStartTime("19:00"), defaultSessionMinutes, weeklyTargetActions,
progressStyle(percentage|streak|minimal), constraints[]`

### Goal
`user, title, description, why (§2.2 "why it matters"), category(enum|custom),
customCategory, priority(low|medium|high), startDate, targetDate,
frequency{type: daily|weekly_count|specific_days, timesPerWeek, days[]},
preferredTime, status(active|paused|completed|archived),
progressPercent(cached), computedStatus(cached), lastEvaluatedAt`

### Milestone
`goal, title, description, order, targetDate, status, progressPercent`

### Action (the template)
`goal, milestone?, title, description, estimatedMinutes, difficulty(easy|medium|hard),
priority, isRecurring, recurrence{days[], timesPerWeek, endDate}, dueDate (one-off),
preferredTime, targetCount (e.g. "learn 20 words"), isActive`

### ActionOccurrence (the log — the important one)
`action, goal, milestone?, user, scheduledDate(Date, indexed),
scheduledAt(DateTime for reminder), status(upcoming|in_progress|completed|missed|skipped),
completedAt, actualMinutes, note, reminderSentAt`

Indexes: `{user:1, scheduledDate:1}`, `{user:1, status:1, scheduledDate:1}`,
`{goal:1, scheduledDate:1}`, unique `{action:1, scheduledDate:1}` (idempotent cron).

### WeeklyReflection
`user, weekStart, weekEnd, stats{planned, completed, missed, skipped,
goalsWorkedOn[], strongestGoal, weakestGoal}, wentWell, wasDifficult, improveNext`

### NotificationPreference (embedded in User)
`pushEnabled, emailEnabled, actionReminders{enabled, minutesBefore},
dailySummary{enabled, time}, weeklyDigest{enabled, weekday, time},
milestoneAlerts, quietHours{start, end}, timezone`

---

## 5. Progress status algorithm (JD §11 — "must be documented")

Not a plain percentage. Four signals, evaluated per active goal.

```ts
// 1. Time elapsed through the goal window
timeRatio = clamp01((today - startDate) / (targetDate - startDate))

// 2. Work actually done, weighted by milestone completion
workRatio = completedOccurrences / totalPlannedOccurrences   // to targetDate

// 3. Recent adherence (last 14 days) — catches "was great, now stalled"
adherence = completed14 / (completed14 + missed14)           // skipped excluded

// 4. Pace delta
delta = workRatio - timeRatio
```

Decision table (first match wins):

| Condition | Status |
|---|---|
| `workRatio >= 1` or goal marked complete | **Completed** |
| goal age < 7 days | **On Track** *(grace period — new goals never shamed)* |
| `delta >= +0.10` | **Ahead** |
| `delta >= -0.05` and `adherence >= 0.6` | **On Track** |
| `delta >= -0.20` or `adherence >= 0.4` | **Needs Attention** |
| otherwise | **Behind** |

Each status ships with a **one-line human reason** the UI shows verbatim —
*"You've completed 4 of 6 planned sessions this week"* — because a coloured chip
without a reason is exactly the "corporate dashboard" feel the JD warns against.

**Consistency** (§12): streak = consecutive days back from today where the user had
≥1 planned occurrence and completed ≥1 (days with nothing planned are *neutral* — they
don't break the streak; that's the anti-gamification choice, and it's honest).
Monthly % = completed / planned over the last 30 days.

---

## 6. API surface (`/api/v1`)

```
POST   /auth/register            POST /auth/login          POST /auth/refresh
POST   /auth/logout              POST /auth/verify-email   POST /auth/resend-code
POST   /auth/forgot-password     POST /auth/reset-password
POST   /auth/google              (verify Firebase ID token → our JWT)

GET/PATCH /users/me              POST /users/me/avatar
GET/PATCH /users/me/preferences
GET/PATCH /users/me/notification-preferences
POST   /users/me/devices         (register FCM token)   DELETE /users/me/devices/:id
POST   /onboarding/complete      (atomic: profile + prefs + first goal + routine)

GET/POST /goals                  GET/PATCH/DELETE /goals/:id
POST   /goals/:id/pause | /resume | /complete
GET    /goals/:id/progress       GET /goals/:id/history

GET/POST /goals/:id/milestones   PATCH/DELETE /milestones/:id
GET/POST /actions                PATCH/DELETE /actions/:id

GET    /occurrences?from=&to=&status=      ← calendar + today feed
GET    /occurrences/today
POST   /occurrences/:id/complete | /skip | /start
PATCH  /occurrences/:id/reschedule

GET    /dashboard                ← ONE call, everything the home screen needs
GET    /progress/summary?range=week|month|quarter
GET    /reflections/current      POST /reflections
GET    /notifications            PATCH /notifications/:id/read
```

Every response is enveloped:
`{ success, data, message }` / `{ success:false, error:{ code, message, details[] } }`

`GET /dashboard` returning the whole home screen in one round-trip is a deliberate
BFF-style choice — the app opens instantly, which is 25% of the grade.

---

## 7. Folder structure

### Backend — `goalflow-api/`
```
src/
  config/        env.ts (zod-validated), db.ts, firebase.ts, resend.ts, logger.ts
  modules/
    auth/        auth.routes|controller|service|schema.ts, tokens.ts
    users/       users.*  (+ preferences)
    goals/       goals.*  + goal.status.service.ts
    milestones/  milestones.*
    actions/     actions.*
    occurrences/ occurrences.*  + materialiser.service.ts
    dashboard/   dashboard.service.ts
    progress/    progress.service.ts, consistency.service.ts
    reflections/ reflections.*
    notifications/ notification.service.ts, push.fcm.ts, email.resend.ts, prefs.ts
  models/        User.ts Goal.ts Milestone.ts Action.ts ActionOccurrence.ts ...
  middleware/    auth.ts ownership.ts validate.ts errorHandler.ts rateLimit.ts
  jobs/          index.ts + the 5 cron jobs
  emails/        VerifyEmail.tsx ResetPassword.tsx WeeklyDigest.tsx Milestone.tsx
  utils/         ApiError.ts asyncHandler.ts date.ts (tz-aware)
  app.ts server.ts
```

### Flutter — `goalflow_app/lib/`
```
core/       theme/ (colors, typography, spacing), network/dio_client.dart,
            router/app_router.dart, errors/, constants/, utils/
data/       models/ (freezed + json_serializable), datasources/ (remote api),
            repositories/ (impl)
domain/     entities/, repositories/ (abstract)
application/ providers + notifiers (Riverpod) — all business logic lives here
presentation/
  screens/  splash onboarding auth home goals goal_detail create_goal
            create_milestone create_action today calendar progress
            reflection profile settings notifications
  widgets/  goal_card, progress_ring, action_tile, status_chip,
            consistency_strip, section_header, empty_state, app_button, app_field
```

Rule: a widget never calls `dio` and never computes a status. Widgets read providers.

---

## 8. UI/UX direction (25% of the grade — highest weight)

- **Feel:** calm consumer app (Headspace / Fitbod / Duolingo), *not* Jira.
- **Palette:** one warm accent (indigo→violet gradient) on a near-white `#FAFAFA`
  canvas; full dark mode from day one (bonus point, cheap with `ThemeExtension`).
- **Type:** Inter / Plus Jakarta Sans. 28/22/16/14 scale. Generous line-height.
- **Home screen copy is personal:** *"Good evening, Sam — 2 things left today."*
  Time-of-day greeting reads from the user's own preferred window. That single touch
  makes personalisation *visible* to a judge in 3 seconds.
- **Cards, not tables.** 16px radius, soft shadow, 20px page padding, 12px gaps.
- **Progress ring** for goal %, **7-dot strip** for the week, **thin bar** for milestones.
  Charts only on the Progress screen.
- **Motion:** 200–250ms ease-out. Check-off animates the ring upward + light haptic.
  One confetti moment, reserved for milestone completion only.
- **Empty states are drawn, never "No data".**
- **Every list has skeleton loaders** — perceived speed is graded.

---

## 9. Build order (recommended 7-day cut)

| Day | Backend | Flutter |
|---|---|---|
| 1 | Repo, config, Mongoose models, auth (register/login/refresh), Resend verify + reset | Project setup, theme, router, dio client, splash/login/register |
| 2 | Goals + milestones + actions CRUD, ownership guard, zod validation | Onboarding flow (5 steps), auth wiring, secure token storage |
| 3 | Occurrence materialiser + cron, `/occurrences/today`, complete/skip | Home dashboard, today's actions, check-off interaction |
| 4 | Status algorithm, `/dashboard`, `/goals/:id/progress` | Goals list, create goal, goal detail with milestone/action tree |
| 5 | Consistency, `/progress/summary`, reflections | Progress screen (ring + charts), calendar/schedule screen |
| 6 | FCM push, notification prefs, reminder cron, weekly digest email | Weekly reflection, profile, settings, notification preferences |
| 7 | Deploy (Railway + Atlas), Swagger, seed script, README | Polish pass, dark mode, empty/error states, build APK |
| — | **Buffer** | Record demo video (script below) |

Ship in that order. If time runs out, cut *bonus* features — never cut the
end-to-end journey in JD §"Primary User Journey".

---

## 10. Deployment & docs (5%, cheapest points available)

- API → Railway/Render, MongoDB → Atlas free tier, Firebase project for FCM,
  Resend with a verified domain (or `onboarding@resend.dev` for the demo).
- `README.md` with: 60-second quickstart, `.env.example` (every key documented),
  `npm run seed` creating a demo user with 3 weeks of realistic history so the
  Progress and Reflection screens look alive in the video, Swagger URL, APK link.
- `docker-compose.yml` (api + mongo) so a reviewer runs it with one command.
- Postman collection exported alongside the OpenAPI spec.

**Seed data matters more than it sounds.** Empty charts kill a demo video.

## 11. Demo video script (~5 min)

1. 0:00 Splash → Register → email verification code from Resend (show the inbox).
2. 0:45 Onboarding: name, avatar, main objective, first goal, days, time, frequency.
3. 1:30 Land on a dashboard that is *already* personalised — greeting, today's list.
4. 2:00 Create a goal → add 2 milestones → add actions → set routine.
5. 2:45 Complete an action; watch the ring, streak and status chip update live.
6. 3:15 Goal detail: status **On Track** *with the reason sentence*, milestone tree.
7. 3:45 Calendar (missed vs completed) → Progress (weekly + multi-week chart).
8. 4:15 Weekly Reflection + the Resend digest email that links into it.
9. 4:40 Notification preferences → change reminder time → show the FCM push arriving.
10. 4:55 Close on the architecture line: *"actions are plans, occurrences are the log."*

Record on a real device, portrait, with the seeded history. Narrate the *why*, not the
*what* — the JD is grading product thinking, not feature count.

---

## 12. Risks & pre-decided answers

| Risk | Decision |
|---|---|
| Timezones | Store UTC + `user.timezone`; all cron work is per-user-local via `luxon`. Never trust device clock. |
| Cron on a sleeping free dyno | Use Railway (always-on) or an external cron ping; note it in the README. |
| iOS push needs an APNs key | Demo push on Android; state it. Do not burn a day on Apple provisioning. |
| Occurrence table growth | Materialise only 7 days ahead + TTL-free archive; indexes listed in §4. |
| Scope creep from bonus list | Bonus only after §"Primary User Journey" runs clean end-to-end. Dark mode + streaks are the two cheapest; AI breakdown is the flashiest if a day is spare. |
