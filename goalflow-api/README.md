# GoalFlow API

Node.js + TypeScript + Express + MongoDB backend for GoalFlow.

Runs on Node (`node dist/server.js`). TypeScript is a build-time step only — nothing
TypeScript-related exists at runtime.

---

## Quickstart (60 seconds)

```bash
cd goalflow-api
npm install
cp .env.example .env          # then edit the two JWT secrets
npm run seed                  # demo account + 3 weeks of history
npm run dev                   # http://localhost:4000
```

Health check:

```bash
curl http://localhost:4000/health
```

### Demo login

```
email:    demo@goalflow.app
password: Demo1234
```

The seed creates three goals whose progress deliberately differs — one **Ahead**, one
**On track**, one **Behind** — so every branch of the status algorithm is visible in a demo.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Node.js 20+ | `node --version` |
| MongoDB | Local `mongod`, or a free MongoDB Atlas cluster |

Nothing else is mandatory. Firebase and Resend are optional — see below.

---

## Environment variables

Every key is documented in [`.env.example`](.env.example). The server validates the whole
environment with zod at boot and **exits immediately** if something is missing or malformed,
so a misconfigured deploy never starts silently.

| Key | Required | Purpose |
|---|---|---|
| `PORT` | no (4000) | HTTP port |
| `MONGODB_URI` | **yes** | Local or Atlas connection string |
| `JWT_ACCESS_SECRET` | **yes** | Signs 15-minute access tokens (min 16 chars) |
| `JWT_REFRESH_SECRET` | **yes** | Signs rotating refresh tokens |
| `ACCESS_TOKEN_TTL` | no (15m) | Access token lifetime |
| `REFRESH_TOKEN_TTL_DAYS` | no (30) | Refresh token lifetime |
| `RESEND_API_KEY` | no | Transactional email. Omit → emails log to console |
| `EMAIL_DRY_RUN` | no (true) | `true` prints emails instead of sending |
| `FIREBASE_PROJECT_ID` / `_CLIENT_EMAIL` / `_PRIVATE_KEY` | no | FCM push. Omit → push payloads are logged |
| `ENABLE_CRON` | no (true) | Background jobs |
| `MATERIALISE_DAYS_AHEAD` | no (7) | How far ahead the scheduler generates actions |

**The app is fully usable with none of the optional keys set.** Email and push degrade to
logging so the whole product can be demoed without a verified sending domain or a Firebase
project.

---

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Watch mode via tsx |
| `npm run build` | Compile TypeScript → `dist/` (plain JS) |
| `npm start` | `node dist/server.js` — production |
| `npm run seed` | Reset and reseed the demo account |
| `npm run typecheck` | Types only, no emit |

---

## Architecture

```
routes  →  validate(zod)  →  controller  →  service  →  Mongoose
                                    ↑
             authGuard · ownershipGuard · errorHandler · pino · rate-limit
```

Business logic lives in services. Controllers only translate HTTP. Validation happens once
at the edge, so nothing downstream re-checks its inputs.

```
src/
  config/      env.ts (zod-validated) db.ts logger.ts firebase.ts resend.ts
  models/      User Goal Milestone Action ActionOccurrence WeeklyReflection Notification
  middleware/  auth.ts validate.ts error.ts
  modules/     auth/ users/ goals/ milestones/ actions/ occurrences/
               dashboard/ progress/ reflections/ notifications/
  jobs/        6 cron jobs (materialise, mark-missed, reminders, digests, recompute)
  emails/      Resend HTML templates
  utils/       ApiError http date
```

### The core idea: plan vs log

- **`Action`** is a *rule* — "Practise Spanish, 25 min, Mon–Fri, 07:30".
- **`ActionOccurrence`** is one *dated instance* — "Wed 13 Aug, completed at 07:52".

A nightly job materialises occurrences from each user's routine. Because occurrences are real
documents, "today", missed-detection, streaks, the calendar, weekly targets and reminders are
all one indexed range query instead of recurrence maths in the UI.

Occurrences are never deleted, only status-changed. That is how history is preserved.

---

## Data model

```
User ─┬─< Goal ─┬─< Milestone ─< Action ─< ActionOccurrence
      │         └─< Action  (goal-level, milestone optional)
      ├─< WeeklyReflection
      ├─< Notification
      ├── preferences            (embedded)
      ├── notificationPreference (embedded)
      └── deviceTokens[]         (FCM)
```

Indexes that matter:

| Collection | Index | Why |
|---|---|---|
| `actionoccurrences` | `{action, scheduledDate}` **unique** | Makes the cron idempotent |
| `actionoccurrences` | `{user, scheduledDate, status}` | Today feed, calendar |
| `actionoccurrences` | `{status, scheduledAt}` | Reminder sweep |
| `goals` | `{user, status, targetDate}` | Goals list |
| `weeklyreflections` | `{user, weekStart}` **unique** | One reflection per week |

---

## Progress status algorithm

Documented in full in [`../docs/01-architecture-and-plan.md`](../docs/01-architecture-and-plan.md#5-progress-status-algorithm-jd-11--must-be-documented).
Summary — four independent signals, not a percentage:

```
timeRatio = elapsed / total goal window
workRatio = completed occurrences / all planned occurrences
adherence = last 14 days: completed / (completed + missed)   [skipped excluded]
delta     = workRatio - timeRatio
```

| Condition (first match wins) | Status |
|---|---|
| `workRatio >= 1` | **Completed** |
| goal younger than 7 days | **On track** *(grace period)* |
| `delta >= +0.10` | **Ahead** |
| `delta >= -0.05` and `adherence >= 0.60` | **On track** |
| `delta >= -0.20` or `adherence >= 0.40` | **Needs attention** |
| otherwise | **Behind** |

Every status is returned with a plain-language reason the UI shows verbatim, e.g.
*"You've completed 4 of 6 planned sessions this week."*

---

## API

Base URL: `/api/v1`. All responses use one envelope:

```jsonc
// success
{ "success": true, "message": "OK", "data": { } }

// failure
{ "success": false, "error": { "code": "BAD_REQUEST", "message": "Validation failed",
                               "details": [{ "field": "title", "message": "..." }] } }
```

### Auth
| Method | Path |
|---|---|
| POST | `/auth/register` |
| POST | `/auth/login` |
| POST | `/auth/refresh` |
| POST | `/auth/logout` |
| POST | `/auth/verify-email` · `/auth/resend-code` |
| POST | `/auth/forgot-password` · `/auth/reset-password` |
| POST | `/auth/change-password` |
| POST | `/auth/google` |

### Profile & preferences
| Method | Path |
|---|---|
| GET / PATCH | `/users/me` |
| POST | `/users/me/avatar` (multipart) |
| GET / PATCH | `/users/me/preferences` |
| GET / PATCH | `/users/me/notification-preferences` |
| POST / DELETE | `/users/me/devices` (FCM token) |
| POST | `/onboarding/complete` — atomic: profile + prefs + goals + routine + schedule |
| GET | `/onboarding/templates` |

### Goals, milestones, actions
| Method | Path |
|---|---|
| GET / POST | `/goals` |
| GET / PATCH / DELETE | `/goals/:id` |
| POST | `/goals/:id/pause` · `/resume` · `/complete` |
| GET | `/goals/:id/progress` · `/goals/:id/history` |
| GET / POST | `/goals/:id/milestones` |
| PATCH / DELETE | `/milestones/:id` · POST `/milestones/:id/complete` |
| GET / POST | `/actions` · PATCH / DELETE `/actions/:id` |

### Schedule, progress, reflection, notifications
| Method | Path |
|---|---|
| GET | `/occurrences?from=&to=&status=` — calendar |
| GET | `/occurrences/today` |
| POST | `/occurrences/:id/complete` · `/start` · `/skip` · `/undo` |
| PATCH | `/occurrences/:id/reschedule` |
| POST | `/occurrences/generate` |
| GET | **`/dashboard`** — the entire home screen in one call |
| GET | `/progress/summary?range=week\|month\|quarter` · `/progress/consistency` |
| GET / POST | `/reflections` · GET `/reflections/current` |
| GET | `/notifications` · PATCH `/:id/read` · POST `/read-all` · POST `/test` |

---

## Background jobs

All jobs compare against each **user's own local clock**, so one server handles every
timezone without per-user cron entries.

| Job | Cadence | Does |
|---|---|---|
| `materialise` | hourly :10 | Generate the next 7 days of occurrences from routines |
| `mark-missed` | hourly :20 | `upcoming` → `missed` once the user's day has ended |
| `action-reminders` | every 15 min | Push, N minutes before, honouring quiet hours |
| `daily-summary` | every 15 min | "3 planned today" at the user's chosen time |
| `weekly-digest` | every 30 min | Push + Resend email, on the user's chosen weekday |
| `recompute-goals` | 01:00 daily | Refresh cached status and progress |

Set `ENABLE_CRON=false` to disable them (useful when seeding or running tests).

---

## Security

- Passwords hashed with bcrypt, cost 12. `passwordHash` is `select: false` — never returned.
- Refresh tokens stored as SHA-256 hashes and **rotated** on every use; a stolen database
  dump cannot be replayed as a session.
- Password change or reset invalidates every existing session.
- Login returns one identical error for unknown email and wrong password (no enumeration).
  `forgot-password` and `resend-code` always resolve successfully for the same reason.
- Ownership guard on every resource — authorization is enforced in middleware, not left to
  each query remembering its `user` filter.
- `helmet`, CORS, and a 20-request / 15-minute rate limit on all credential endpoints.
- Logs redact `authorization` headers and every password field.

---

## Deployment

Railway or Render, plus MongoDB Atlas:

1. Create an Atlas cluster; copy the connection string into `MONGODB_URI`.
2. Set the env vars above. Generate secrets with `openssl rand -hex 32`.
3. Build command `npm run build`, start command `npm start`.
4. Keep the instance always-on so cron keeps running (free tiers that sleep will skip jobs —
   use an external cron ping if you stay on one).
5. `FIREBASE_PRIVATE_KEY` may contain literal `\n` sequences; the config layer converts them.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Invalid environment configuration` on boot | A required key is missing or a secret is under 16 chars |
| `MongoDB error` / boot hangs | `mongod` not running, or Atlas IP allowlist |
| No emails arrive | `EMAIL_DRY_RUN=true` (default) — check the console, or set a `RESEND_API_KEY` |
| Push does nothing | Firebase keys unset — the payload is logged instead. Add them to send for real |
| Today's list is empty | `POST /occurrences/generate`, or check the goal is `active` |
