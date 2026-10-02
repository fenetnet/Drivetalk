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
- No call recording, no transcription, no AI over call content.
- Never auto-start a call. Every connection requires consent from both sides.
  Automatic availability ≠ automatic call consent.
- Automatic driving availability is **opt-in, off by default**.
- Never claim the user is "the driver" — only "the device is probably in a vehicle".
- No continuous GPS for driving detection. No background GPS without explaining
  why there is no alternative and getting explicit owner approval.
- Never expose location, route, or speed to other users. Server knows at most:
  available / mode / expires_at.
- Availability always has an automatic expiry.
- Do not read the phone Call Log. Do not request full contacts access in early phases.
- No infinite-scroll feed. No anonymous random chat as a core feature.
- Driver mode: huge buttons, minimal text, no typing, no scrolling lists.
- Match explanations must only use data we actually have — never invent reasons.
- Matching weights live in configuration, not hard-coded in logic.
- Block / Report / Unmatch / Don't-suggest-again exist from day one.
- Public release targets adults only (18+) unless the owner decides otherwise.

## Tech stack

- Flutter (Dart), Android first.
- State management: Riverpod (see decisions log).
- Hebrew + RTL first, all strings via localization (ARB files) so English can be added.
- Phase 1 uses fake/mock services only. Later: Supabase (Postgres + Auth +
  Realtime + RLS + server functions), LiveKit (audio only) — both need owner approval.
- Android driving detection: official Activity Recognition Transition API
  (IN_VEHICLE ENTER/EXIT) via a small Kotlin platform bridge if no reliable,
  maintained Flutter package exists. Optional car Bluetooth as extra signal.
- iPhone: App Intents (Start/Stop/Start Driving/Pause Availability) for
  Shortcuts automations (Driving Focus, CarPlay). Core Motion only as a
  foreground signal.

## Code layout (planned)

```
lib/
  app/            app shell, routing, theme, localization setup
  features/       UI per feature (home, availability, match, driver, call, ...)
  domain/         models + business logic (pure Dart, no Flutter imports)
  matching/       matching engine + config (pure Dart, unit-tested)
  services/       abstract service interfaces (auth, availability, social graph, calls, ...)
  services/fake/  Phase 1 fake implementations
  platform/       device signals (vehicle detection, bluetooth) behind interfaces
  debug/          developer/debug screen — excluded from release builds
```

UI depends only on service **interfaces**; fake → real swap happens in one
provider wiring file.

## Commands

(Filled in once the Flutter project exists.)

```
flutter pub get
flutter analyze
flutter test
flutter run
```

## Git

- Develop on the assigned feature branch; merge to `main` only after checks pass
  and with owner approval.
- Clear commit messages. Never commit secrets, `.env`, keystores, or `google-services.json` with real keys.

## Work phases

1. Interactive local prototype, fake data only  ← **current**
2. Auth + users + social graph + backend
3. Realtime availability + matchmaking
4. Android automatic driving detection
5. Real audio calls
6. Notifications + Availability Beacon
7. iPhone + App Intents + Driving Focus/CarPlay
8. Friends-of-friends + serendipity improvements
9. Safety, moderation, analytics, store readiness

Each phase ends with something the owner can test before moving on.
