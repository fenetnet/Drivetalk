# CLAUDE.md — DriveTalk

Guidance for Claude (and any developer) working in this repository.

## What this project is

DriveTalk is a voice-first social app that turns "dead time" (commutes, traffic,
walks, breaks) into real human connection through audio calls with the *right*
person for right now — close friends, dormant connections, colleagues, and
controlled friends-of-friends. Android first (Flutter), iPhone later.

Full vision: `docs/product.md`. Architecture: `docs/architecture.md`.
Decisions log: `docs/decisions.md`. Current status: `docs/handoff.md`.

## Working with the owner

- The owner is **not a programmer**. Explain results and decisions in simple
  Hebrew, from the user's point of view. Do not explain code unless asked.
- **Big change** → short plan → owner approves → then implement.
  **Small change** → implement directly.
- If the owner must open an account, install software, connect a phone, or click
  somewhere → stop and guide step by step.
- Before any paid service / account creation (Supabase, LiveKit, etc.) →
  present: what it does, what to open, cost, free tier, alternatives. Wait for approval.
- After every significant step: update `docs/handoff.md`; record meaningful
  decisions in `docs/decisions.md`.

## Hard rules (never break)

- No secrets / service keys in the app or in git. Ever.
- No call recording, no transcription, no AI over call content. Voice notes
  ("leave a message") are a separate, user-initiated feature (simulated now).
- A call starts only with consent from both sides: either the other side says
  yes to "talk now", or BOTH sides pre-approved each other for "quick connect"
  (owner decision D-026) — and even then with a visible/spoken cancellable
  countdown (5s), max 1 per availability window and 1 per person per day.
  Automatic availability ≠ automatic call consent.
- Calls go through the phone's regular dialer when numbers may be shared
  (connections; friends-of-friends/groups only if BOTH allow it). Otherwise the
  call stays inside the app so numbers remain private. Never read the call log.
- Voice in the car: read aloud + "yes"/"no" via the phone's speech recognizer.
  Nothing recorded or stored. Buttons always work as a fallback.
- Fake people's numbers are never dialed. Real dialing in the prototype only
  to a test number the owner enters in the developer screen.
- Automatic driving availability is **opt-in, off by default**.
- Never claim the user is "the driver" — only "the device is probably in a vehicle".
- No continuous GPS for driving detection. No background GPS without explaining
  why there is no alternative and getting explicit owner approval.
- Never expose location, route, or speed to other users. Server knows at most:
  available / mode / expires_at.
- Availability always has an automatic expiry.
- Do not read the phone Call Log. Contacts (owner decision D-047): only
  phone NUMBERS are read, hashed (SHA-256 of +972… form) on the phone; names
  never leave it. People who have EACH OTHER's number connect automatically.
- No infinite-scroll feed. No anonymous random chat as a core feature.
- Driver mode: huge buttons, minimal text, no typing, no scrolling lists,
  one person at a time (normal mode shows up to 3 options).
- Match explanations must only use data we actually have — never invent reasons.
- Matching weights live in configuration, not hard-coded in logic.
- Block / Report / Unmatch / Don't-suggest-again exist from day one.
- No age gate in the prototype (owner decision D-035). Revisit before a
  public store release (store requirements, Phase 9).

## Tech stack

- Flutter (Dart), Android first.
- State management: Riverpod 3 (see decisions log).
- Hebrew + RTL first, all strings via localization (ARB files) so English can be added.
- Phase 1 uses fake/mock services only. Later: Supabase (Postgres + Auth +
  Realtime + RLS + server functions), LiveKit (audio only) — both need owner approval.
- Android driving detection: official Activity Recognition Transition API
  (IN_VEHICLE ENTER/EXIT) via a small Kotlin platform bridge if no reliable,
  maintained Flutter package exists. Optional car Bluetooth as extra signal.
- iPhone: App Intents (Start/Stop/Start Driving/Pause Availability) for
  Shortcuts automations (Driving Focus, CarPlay). Core Motion only as a
  foreground signal.

## Code layout

```
lib/
  app/            providers (THE fake↔real wiring file), session controller,
                  root gate, theme, dev-tools flag
  features/       UI per feature (home, availability, match, driver, call,
                  feedback, invitation, connections, discover, settings, onboarding)
  domain/         models (pure Dart, no Flutter imports)
  matching/       matching engine + config + reasons (pure Dart, unit-tested)
  services/       abstract service interfaces
  services/fake/  Phase 1 in-memory implementations + seed data
  real/           Phase 2 real mode: backend interface, Supabase + in-memory
                  backends, RealController, deep links, local store
  features/real/  real-mode screens (onboarding, home, people, offer,
                  waiting, call, feedback, invite, test, settings)
  platform/       device signals (vehicle detection) behind interfaces
  debug/          developer screen + matching inspector (kDevTools only)
  l10n/           app_he.arb (template) + generated localizations
assets/config/matching.json   all matching weights / limits / cooldowns
supabase/migrations/          the whole server schema (RLS, functions, realtime)
invite_site/                  static invitation page (published to gh-pages)
tool/e2e/                     backend end-to-end check against a local Supabase
test/             engine unit tests, session-flow tests, app smoke test
```

UI depends only on service **interfaces**; fake → real swap happens in
`lib/app/providers.dart`. All user-facing text lives in `lib/l10n/app_he.arb`.

## Commands

Flutter 3.47.x stable. In the cloud container Flutter is installed at
`/opt/sdk/flutter/bin` (add to PATH; not persisted between sessions — reinstall
from storage.googleapis.com/flutter_infra_release if missing).

```
flutter pub get
flutter gen-l10n            # after editing lib/l10n/app_he.arb
dart format lib test
flutter analyze             # must be clean
flutter test                # must pass
flutter run --dart-define=DEV_TOOLS=true
flutter build web --release --dart-define=DEV_TOOLS=true --no-web-resources-cdn
```

Real mode is configured only by CI repository variables `SUPABASE_URL`,
`SUPABASE_ANON_KEY` (public anon/publishable key), `INVITE_BASE_URL`
(→ `--dart-define`). Never the service_role / secret key.
Local backend: `supabase start` (docker) + `tool/e2e` and
`SUPABASE_LIVE_URL=… SUPABASE_LIVE_KEY=… flutter test test/supabase_live_test.dart`.

The Android SDK cannot be downloaded in the cloud container (dl.google.com is
blocked), so APKs are built by GitHub Actions (`.github/workflows/android.yml`).

`DEV_TOOLS=true` compiles in the developer screen. Store builds must not pass it.

## Git

- Develop on the assigned feature branch; merge to `main` only after checks pass
  and with owner approval.
- Clear commit messages. Never commit secrets, `.env`, keystores, or `google-services.json` with real keys.

## Work phases

1. Interactive local prototype, fake data only  ✅
2. Auth + users + social graph + backend  ← **current** (built; owner must
   set up Supabase + variables — `docs/setup-guide.md`)
3. Realtime availability + matchmaking
4. Android automatic driving detection  ✅ built (D-045): Kotlin
   `Driving*.kt` (Activity Recognition, foreground service, device-token
   RPCs in `supabase/migrations/20261003000000_auto_driving.sql`)
5. Real audio calls
6. Notifications + Availability Beacon
7. iPhone + App Intents + Driving Focus/CarPlay
8. Friends-of-friends + serendipity improvements
9. Safety, moderation, analytics, store readiness

Each phase ends with something the owner can test before moving on.
