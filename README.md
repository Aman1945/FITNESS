# GoalFlow

A personal goal-tracking mobile app. Define what you want to achieve, break it into
milestones and actions, and see honestly whether you are on track.

Built for the GoalFlow Hackathon.

**Flutter** (mobile) · **Node.js + TypeScript + Express** (API) · **MongoDB** (database)
· **Firebase Cloud Messaging** (push) · **Resend** (email)

---

## Run it in 60 seconds

You need Node 20+, Flutter 3.9+, and MongoDB (local or Atlas).

```bash
# 1. backend
cd goalflow-api
npm install
cp .env.example .env          # set the two JWT secrets
npm run seed                  # demo account + 3 weeks of history
npm run dev                   # http://localhost:4000

# 2. app (new terminal)
cd goalflow_app
flutter pub get
flutter run
```

### Demo login

```
email:    demo@goalflow.app
password: Demo1234
```

The seed creates three goals whose progress deliberately differs — one **Ahead**, one
**On track**, one **Behind** — so every branch of the status logic is visible immediately.

---

## The idea behind the data model

Most goal apps model an action as a to-do row. That breaks the moment an action
recurs: "Gym on Mon/Wed/Fri" has no single status, so "did I miss Monday?" becomes
unanswerable.

GoalFlow separates the **plan** from the **log**:

| | |
|---|---|
| **`Action`** | the rule — *"Practise Spanish, 25 min, Mon–Fri, 07:30"* |
| **`ActionOccurrence`** | one dated instance — *"Wed 13 Aug, completed at 07:52"* |

A nightly job materialises occurrences from each user's routine. Because they are real
documents, almost everything else becomes a single indexed query rather than recurrence
maths inside the UI:

| Feature | How it falls out |
|---|---|
| Today's actions | `find({ user, scheduledDate: today })` |
| Missed detection | cron flips `upcoming` → `missed` once the user's day ends |
| History preserved | occurrences are never deleted, only status-changed |
| Calendar | occurrences already carry a date |
| Weekly progress (4/5) | count planned vs completed in the week |
| Consistency streak | walk occurrence days backwards |
| On track / Behind | compare completed against *planned so far* |
| Reminders | every occurrence has a `scheduledAt` — that is the queue |

---

## Progress status

Not a percentage. Four independent signals:

```
timeRatio = how much of the goal's window has elapsed
workRatio = completed occurrences / all planned occurrences
adherence = last 14 days: completed / (completed + missed)   [skips excluded]
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

Every status ships with a plain-language reason the UI shows verbatim —
*"You've completed 4 of 6 planned sessions this week."* A coloured chip on its own
explains nothing.

**Consistency** counts a day only if something was planned for it. Days with nothing
planned are neutral: they neither break nor extend a streak. A rest day the user
scheduled themselves is not a failure.

---

## Repository layout

```
GoalFlow/
├── docs/
│   ├── 00-JD-original.md            the hackathon brief, verbatim
│   ├── 01-architecture-and-plan.md  stack rationale, data model, API, build order
│   └── 02-deployment.md             Atlas + Render + APK distribution
├── goalflow-api/                    Node + TypeScript + Express + Mongoose
│   └── README.md                    env vars, endpoints, jobs, security
└── goalflow_app/                    Flutter
    └── README.md                    screens, architecture, design tokens
```

---

## What is implemented

**21 screens** — splash, register, verify email, login, forgot password, onboarding
(5 steps), home, today, goals, create/edit goal, goal detail, create milestone,
create action, schedule, progress, weekly reflection, profile, settings, notification
preferences, notifications feed.

**Backend** — 45+ REST endpoints, JWT with rotating refresh tokens, zod validation at
the edge with human-readable errors, ownership guards, 6 timezone-aware cron jobs,
FCM push and Resend email behind one preference-checking service, pino logging,
zod-validated environment.

**App** — Riverpod state, go_router with a single auth guard, dio with transparent
token refresh, secure keychain storage, dark mode, skeleton loaders, drawn empty
states. No business logic in widgets: a widget never calls the network and never
computes a status.

---

## Checks

```bash
cd goalflow-api  && npm run typecheck   # clean
cd goalflow_app  && flutter analyze     # No issues found
cd goalflow_app  && flutter test        # all pass
```

---

## Deployment

See [docs/02-deployment.md](docs/02-deployment.md). Summary: MongoDB Atlas for the
database, Render for the API (`render.yaml` blueprint included), and a release APK
built with `--dart-define=API_BASE_URL=...` for distribution.
