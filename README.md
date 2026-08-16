# GoalFlow

Define a goal, break it into milestones and actions, and see honestly whether you
are on track. Built for the GoalFlow Hackathon.

**Flutter** · **Node.js + TypeScript + Express** · **MongoDB** · **FCM** · **Email**

| | |
|---|---|
| **Live API** | https://fitness-lgaw.onrender.com |
| **Database** | Managed MongoDB cluster, hosted separately from the API |
| **Android APK** | `GoalFlow-v1.apk` |
| **Demo login** | `demo@goalflow.app` / `Demo1234` |

> Render's free tier sleeps after ~15 min idle. The first request wakes it and takes
> up to a minute — hit `/health` once before a demo.

---

## Run it

Node 20+, Flutter 3.9+, MongoDB (local or Atlas).

```bash
# backend
cd goalflow-api && npm install
cp .env.example .env        # set the two JWT secrets
npm run seed                # demo account + 3 weeks of history
npm run dev                 # http://localhost:4000

# app (new terminal)
cd goalflow_app && flutter pub get
flutter run --dart-define=USE_LOCAL_API=true
```

The app targets the **deployed** API by default, so a plain `flutter run` and the APK
both work with no flags. `USE_LOCAL_API=true` points it at your machine instead.

The seed creates three goals with deliberately different progress — one **Ahead**, one
**On track**, one **Behind** — so no screen starts empty.

---

## Features

**Onboarding** — five steps (name, objective, first goal, preferred days/time, session
length), committed in one atomic call. The answers become the default routine for every
goal, the default duration on every action, and the tone of the home greeting.

**Goal → Milestone → Action** — a goal is never one large task. Eight categories plus
custom, priority, target date, and a full lifecycle: create, edit, pause, resume,
complete, archive. New goals arrive with a starter breakdown to edit rather than a blank
screen.

**Plan vs log** — the idea the whole app rests on. An `Action` is a *rule*
("Spanish, 25 min, Mon–Fri, 07:30"); an `ActionOccurrence` is one *dated instance*
("Wed 13 Aug, completed 07:52"). A nightly job turns rules into instances, which is why
today's list, missed detection, streaks, the calendar and reminders are all one indexed
query instead of recurrence maths in the UI.

**Dashboard** — a single `GET /dashboard` powers the whole home screen: personalised
greeting, today's actions, yesterday's misses carried over, 7-day consistency strip,
active goals with status, and what needs attention.

**Progress** — goal, milestone, weekly and multi-week views. Status is **not** a
percentage: it weighs elapsed time, completed work, and 14-day adherence, then explains
itself in a sentence — *"You've completed 4 of 6 planned sessions this week."*

**Consistency** — a day only counts if something was planned for it. Days with nothing
planned are neutral, so a rest day you scheduled yourself never breaks a streak. No
points, badges or levels.

**Calendar** — month grid of planned, completed and missed actions. Complete, skip or
reschedule from any day.

**Weekly reflection** — auto-generated stats plus three optional prompts: what went
well, what was difficult, what to improve.

**Notifications** — action reminders, daily summaries, weekly digests, milestone alerts,
and a **login greeting that changes with context**: first-ever sign-in, same-day return,
a few days away, and a long absence each say something different. Push via FCM and email
both go through one service that checks preferences and quiet hours first.

**Appearance** — Light / Dark / System, persisted on the device and applied instantly.

**Auth** — sign up, email verification, login, password reset, logout, optional Google.
bcrypt hashing, 15-minute JWTs, rotating refresh tokens stored only as hashes.

---

## Screens

20 in total.

**Auth** splash · register · verify email · login · forgot password
**Setup** onboarding
**Core** home · today · goals · goal detail · calendar · progress · weekly reflection
**Editors** create/edit goal · create milestone · create action
**Account** profile · settings · notification preferences · notifications feed

---

## Documentation

| Doc | What's in it |
|---|---|
| **[GoalFlow-Features-and-Functionality.pdf](docs/GoalFlow-Features-and-Functionality.pdf)** | Features and functionality, as a shareable PDF |
| **[GoalFlow-Technical-Architecture.pdf](docs/GoalFlow-Technical-Architecture.pdf)** | Architecture and implementation, as a shareable PDF |
| [docs/04-features-and-functionality.md](docs/04-features-and-functionality.md) | Source for the features PDF |
| [docs/03-tech-doc.md](docs/03-tech-doc.md) | **How everything works** — every library and why, request lifecycle, data model, algorithms, notification pipeline, state management |
| [docs/02-deployment.md](docs/02-deployment.md) | Atlas + Render + APK distribution, with a troubleshooting table |
| [docs/01-architecture-and-plan.md](docs/01-architecture-and-plan.md) | Original design decisions and build order |
| [docs/00-JD-original.md](docs/00-JD-original.md) | The hackathon brief, verbatim |
| [goalflow-api/README.md](goalflow-api/README.md) | Env vars, endpoints, jobs |
| [goalflow_app/README.md](goalflow_app/README.md) | Screens, folder layout, design tokens |

---

## Checks

```bash
cd goalflow-api && npm run typecheck   # clean
cd goalflow_app && flutter analyze     # No issues found
cd goalflow_app && flutter test        # 12 passing
```

---

## Layout

```
GoalFlow/
├── docs/              design, deployment and technical docs
├── render.yaml        Render blueprint
├── goalflow-api/      Node + TypeScript + Express + Mongoose
└── goalflow_app/      Flutter
```
