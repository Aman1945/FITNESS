# GoalFlow App

Flutter mobile app for GoalFlow. Android + iOS from one codebase.

---

## Quickstart

```bash
cd goalflow_app
flutter pub get
flutter run
```

The backend must be running first — see [`../goalflow-api/README.md`](../goalflow-api/README.md).

### Demo login

```
email:    demo@goalflow.app
password: Demo1234
```

---

## Pointing the app at your backend

The API base URL is resolved automatically per platform, so the common cases need no flags:

| Device | Resolved URL | Flag needed |
|---|---|---|
| iOS simulator | `http://localhost:4000/api/v1` | none |
| Android emulator | `http://10.0.2.2:4000/api/v1` | none |
| Physical phone | — | yes, see below |
| Deployed backend | — | yes, see below |

```bash
# real device on the same WiFi (use your machine's LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1

# deployed backend
flutter run --dart-define=API_BASE_URL=https://your-api.up.railway.app/api/v1
```

Same flag works for builds:

```bash
flutter build apk --release   # uses the deployed default
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

---

## Builds

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Play Store
flutter build ios --release          # iOS (needs Xcode signing)
```

Android release currently signs with debug keys so `flutter run --release` and demo builds
work out of the box. Replace the signing config in
[`android/app/build.gradle.kts`](android/app/build.gradle.kts) before publishing.

---

## Push notifications (optional)

The app runs fine without Firebase — `Firebase.initializeApp()` failure is caught and push is
simply unavailable. To enable it:

1. Create a Firebase project.
2. **Android** — download `google-services.json` → `android/app/`, then uncomment
   `id("com.google.gms.google-services")` in `android/app/build.gradle.kts`.
3. **iOS** — download `GoogleService-Info.plist` → `ios/Runner/` via Xcode, and add an APNs
   key in the Firebase console.
4. Add the matching service-account keys to the backend `.env`.

What gets sent and when is decided entirely by the backend from the user's saved preferences.
There is no notification logic in the UI — the app only asks permission, registers its device
token, and renders foreground messages.

---

## Architecture

```
presentation  →  application  →  domain / data  →  network
  screens         Riverpod        models            ApiClient (dio)
  widgets         notifiers       repositories      TokenStorage (keychain)
```

```
lib/
  core/
    theme/         app_colors.dart  app_theme.dart   (all design tokens)
    network/       api_client.dart  api_exception.dart
    storage/       token_storage.dart               (flutter_secure_storage)
    router/        app_router.dart                  (go_router + auth guard)
    notifications/ push_service.dart                (FCM)
  data/
    models/        user goal action_item dashboard progress
    repositories/  auth_repository goal_repository app_repository
  application/
    providers.dart                                  (Riverpod: state + all mutations)
  presentation/
    screens/       21 screens
    widgets/       common.dart  goal_widgets.dart    (reusable pieces)
```

### Rules the codebase follows

- **A widget never calls `dio`.** Screens read providers; providers call repositories.
- **A widget never computes a status or a percentage.** The backend returns
  `computedStatus` plus a human-readable `statusReason`, and the UI shows it verbatim.
- **Every gap, radius and colour comes from `Gap` / `AppColors`** — no magic numbers.
- **One mutation path.** `OccurrenceActions` in `providers.dart` owns complete / skip / undo /
  reschedule and invalidates every affected screen, so ticking an action on Today updates
  Home, Progress, Calendar and Reflection at once.
- **No codegen.** Models use hand-written `fromJson`, so `flutter run` works with no
  `build_runner` step.

---

## Screens

| Screen | Route | Notes |
|---|---|---|
| Splash | `/splash` | restores the stored session |
| Register | `/register` | backend field errors surfaced inline |
| Verify email | `/verify-email` | 6-digit code, auto-submits, skippable |
| Login | `/login` | |
| Forgot password | `/forgot-password` | request, then reset in one screen |
| Onboarding | `/onboarding` | 5 steps, one atomic commit |
| Home | `/home` | one `GET /dashboard` call |
| Today | `/today` | grouped by time of day |
| Goals | `/goals` | status filters |
| Create / edit goal | `/goals/new`, `/goals/:id/edit` | defaults from user preferences |
| Goal detail | `/goals/:id` | status + reason, milestone tree |
| Create milestone | `/goals/:id/milestones/new` | |
| Create action | `/goals/:id/actions/new` | |
| Schedule | `/calendar` | colour-coded day dots |
| Progress | `/progress` | 4 / 8 / 12-week trend |
| Reflection | `/reflection` | week stats + 3 optional prompts |
| Profile | `/profile` | |
| Settings | `/settings` | writes straight to the backend |
| Notification prefs | `/settings/notifications` | |
| Notifications | `/notifications` | in-app feed |

Auth routing lives in a single `redirect` in
[`lib/core/router/app_router.dart`](lib/core/router/app_router.dart) — no screen checks
"am I signed in?" for itself. Three stages drive it: `signedOut` → `needsOnboarding` → `ready`.

---

## Design system

| Token | Value |
|---|---|
| Accent | `#5B5BD6` indigo |
| Canvas | `#FAFAFC` light · `#0F0F17` dark |
| Radius | 18 cards · 14 inputs and buttons |
| Spacing | 4 / 8 / 12 / 16 / 20 / 28, page padding 20 |
| Type scale | 30 / 26 / 21 / 17 / 15.5 / 14 / 12.5 |
| Motion | 180–250 ms `easeOut` |

Dark mode is complete and follows the system setting. Status colours are consistent
everywhere: Ahead teal · On track green · Needs attention amber · Behind red · Completed indigo.

---

## Packages

| Package | Why |
|---|---|
| `flutter_riverpod` | state + DI, keeps logic out of widgets |
| `go_router` | declarative routing with one auth guard |
| `dio` | HTTP with an auth interceptor and transparent token refresh |
| `flutter_secure_storage` | tokens in the keychain / keystore |
| `firebase_core`, `firebase_messaging` | push |
| `flutter_local_notifications` | rendering foreground pushes |
| `fl_chart` | weekly trend chart |
| `table_calendar` | schedule grid |
| `image_picker` | profile photo |
| `intl` | date and time formatting |

---

## Checks

```bash
flutter analyze     # expected: No issues found!
flutter pub outdated
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Cannot reach the server" | Backend not running, or wrong `API_BASE_URL` for your device |
| Android emulator can't connect | Use `10.0.2.2`, not `localhost` |
| Real device can't connect | Same WiFi, and pass your LAN IP via `--dart-define` |
| App hits localhost unexpectedly | You passed `USE_LOCAL_API=true`; drop it to use the deployed API |
| Session expires immediately | Backend JWT secrets changed — sign out and back in |
| Android build: core library desugaring | Already enabled in `android/app/build.gradle.kts` |
| Push never arrives | Firebase config missing on the app **and** the backend |
| Today's list empty | Settings → "Rebuild my schedule" |
