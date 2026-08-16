# Deployment — MongoDB Atlas + Render + shareable APK

Target setup:

| Piece | Where | Cost |
|---|---|---|
| Database | MongoDB Atlas, M0 cluster | free |
| Backend (Node) | Render web service | free, or $7/mo starter |
| Mobile app | Android APK you share directly | free |

**There is no web build.** GoalFlow is a Flutter mobile app, so Vercel and Netlify
are not part of this — they host static sites, not APKs. You share the app as an
APK (or through Play Store internal testing).

---

## Step 1 — MongoDB Atlas

1. [cloud.mongodb.com](https://cloud.mongodb.com) → **Create** → **M0 free**.
   Pick a region near your users (Mumbai `ap-south-1` for India).
2. **Database Access** → Add New Database User.
   Username + a generated password. Role: *Read and write to any database*.
   Copy the password now — Atlas will not show it again.
3. **Network Access** → Add IP Address → **Allow access from anywhere**
   (`0.0.0.0/0`).
   Render's free plan has no static outbound IP, so an allowlist would break.
4. **Connect** → *Drivers* → copy the string and append the database name:

```
mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/goalflow?retryWrites=true&w=majority
```

> If the password contains `@ : / ? # [ ] %`, URL-encode it, or the connection
> string will parse wrongly.

### Seed the demo data into Atlas

Run this from your machine — much easier than seeding on Render:

```bash
cd goalflow-api
MONGODB_URI="mongodb+srv://...your string.../goalflow" npm run seed
```

That creates `demo@goalflow.app` / `Demo1234` with three weeks of history.
Without it, your first screens are empty — which is a bad first impression when
you share the app.

---

## Step 2 — Render

Push the repo to GitHub first. Then either use the blueprint or set it up by hand.

### Option A — blueprint (fewer clicks)

`render.yaml` is already at the repo root.
Render → **New** → **Blueprint** → pick the repo. Render creates the service and
prompts for the secret values.

### Option B — by hand

Render → **New** → **Web Service** → connect the repo, then:

| Setting | Value |
|---|---|
| Root directory | `goalflow-api` |
| Runtime | Node |
| Build command | `npm install && npm run build` |
| Start command | `npm start` |
| Health check path | `/health` |
| Instance type | Free (read the warning below) or Starter |

### Environment variables

| Key | Value |
|---|---|
| `NODE_ENV` | `production` |
| `NODE_VERSION` | `20` |
| `MONGODB_URI` | your Atlas string from step 1 |
| `JWT_ACCESS_SECRET` | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET` | `openssl rand -hex 32` (different value) |
| `API_BASE_URL` | `https://goalflow-api.onrender.com` (your service URL) |
| `APP_DEEP_LINK` | `goalflow://` |
| `ENABLE_CRON` | `true` |
| `EMAIL_DRY_RUN` | `true` until you have a Resend domain |

Optional, add when you want real email and push:
`RESEND_API_KEY`, `EMAIL_FROM`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`,
`FIREBASE_PRIVATE_KEY`.

The server validates every variable at boot with zod and **exits immediately** if
one is missing or malformed. If a deploy fails instantly, read the Render log —
it names the exact key.

### Verify

```bash
curl https://your-service.onrender.com/health
curl https://your-service.onrender.com/
```

The first request after a sleep takes 30–60 seconds on the free plan. That is
Render waking the container, not a bug in the app.

---

## The free-plan warning that actually matters

Render free services **sleep after ~15 minutes of inactivity**. While asleep:

- action reminders do not fire
- the nightly job that generates the next 7 days of actions does not run
- the weekly digest is not sent

The app still works — it regenerates missing days when you open it, and Settings
has a **Rebuild my schedule** button — but scheduled notifications are the part
that quietly breaks.

Two fixes:

1. **Starter plan, $7/mo** — always on, everything works. The right answer if you
   are demoing to someone.
2. **Free + an external ping** — [cron-job.org](https://cron-job.org) (free), hit
   `https://your-service.onrender.com/health` every 10 minutes. Keeps the
   container awake so the internal cron keeps ticking.

---

## Step 3 — point the app at the deployed backend

The API URL is compiled in at build time:

```bash
cd goalflow_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-service.onrender.com/api/v1
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Note the `/api/v1` suffix — the base URL includes it.

Test against the deployed backend before building a release:

```bash
flutter run --dart-define=API_BASE_URL=https://your-service.onrender.com/api/v1
```

---

## Step 4 — share the app

### Easiest: send the APK

Upload `app-release.apk` to Google Drive, WhatsApp or Telegram and share the link.

The person installing needs to allow **Install unknown apps** for whichever app
they downloaded it from. Worth saying so up front — otherwise they hit a scary
warning and give up.

Works on Android only. iOS cannot install an app outside TestFlight or the App
Store, so iPhone users need option 3.

### Better: Firebase App Distribution (free)

Testers get an email invite and install through a proper installer, which looks a
lot less sketchy than a raw APK link.

```bash
npm install -g firebase-tools
firebase login
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_FIREBASE_ANDROID_APP_ID \
  --testers "someone@example.com,another@example.com" \
  --release-notes "GoalFlow first build"
```

Works for iOS too, but iOS builds need a paid Apple Developer account and each
tester's device registered.

### Most polished: Play Store internal testing

One-time $25 Google developer fee. Testers install from the real Play Store.

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-service.onrender.com/api/v1
```

Upload the `.aab` to Play Console → Testing → Internal testing.
You need a real signing key for this — see below.

---

## Release signing (before any real distribution)

Right now Android release builds sign with debug keys so demo builds work with no
setup. That is fine for an APK you hand to a friend, and **not** fine for the
Play Store.

```bash
keytool -genkey -v -keystore ~/goalflow-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias goalflow
```

Create `goalflow_app/android/key.properties` (add it to `.gitignore`):

```properties
storePassword=...
keyPassword=...
keyAlias=goalflow
storeFile=/Users/you/goalflow-release.jks
```

Then wire it into `android/app/build.gradle.kts` in place of the debug
`signingConfig`. Keep the keystore backed up — losing it means you can never
update the app on Play again.

---

## Checklist before you share

- [ ] Atlas cluster live, `0.0.0.0/0` allowed, connection string works
- [ ] `npm run seed` run against Atlas so screens are not empty
- [ ] Render deploy green, `/health` returns `{"status":"ok"}`
- [ ] Both JWT secrets set to fresh random values, not the `.env.example` ones
- [ ] Keep-awake ping set up, or on the Starter plan
- [ ] APK built with `--dart-define=API_BASE_URL=...` pointing at Render
- [ ] Installed the APK on a phone that is **not** on your WiFi and logged in
- [ ] Told testers to allow "install unknown apps"

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Render deploy dies in seconds | A required env var is missing — the log names it |
| `MongooseServerSelectionError` | Atlas Network Access is not `0.0.0.0/0`, or the password needs URL-encoding |
| App says "Cannot reach the server" | Wrong `API_BASE_URL`, or missing the `/api/v1` suffix, or Render is waking up (wait 60s) |
| First load takes a minute | Free-plan cold start. Expected |
| Reminders never arrive | Service was asleep, or Firebase keys are not set on both app and backend |
| Today's list is empty on a fresh account | Open Settings → Rebuild my schedule |
| Avatar disappears after redeploy | Fixed — avatars are stored in Mongo, not on Render's disk |
| Login works, everything else 401 | JWT secrets changed between deploys. Sign out and back in |
