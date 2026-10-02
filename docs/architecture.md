# DriveTalk — Architecture

> **בקצרה בעברית:** האפליקציה בנויה בשכבות נפרדות — מסכים, לוגיקה, מנוע התאמה,
> שירותים (שרת/שיחות) ושירותי מכשיר (זיהוי נסיעה). בשלב הראשון כל השירותים "מזויפים"
> ורצים בטלפון בלבד. בהמשך נחליף אותם ב-Supabase ו-LiveKit בלי לכתוב מחדש את המסכים.

## Layers

```
┌───────────────────────────────────────────────┐
│ UI (lib/features/*)        Flutter widgets    │  depends on ↓ only via providers
├───────────────────────────────────────────────┤
│ Application state (Riverpod controllers)      │  orchestrates flows
├───────────────────────────────────────────────┤
│ Domain (lib/domain)        pure Dart models   │
│ Matching (lib/matching)    pure Dart engine   │  no Flutter, fully unit-tested
├───────────────────────────────────────────────┤
│ Service interfaces (lib/services/*.dart)      │  abstract classes
│   ├─ fake/   (Phase 1, in-memory)             │
│   ├─ supabase/ (Phase 2+)                     │
│   └─ livekit/  (Phase 5)                      │
├───────────────────────────────────────────────┤
│ Platform (lib/platform)                       │
│   VehicleSignalSource → fake | Android bridge │
│   | iOS App Intents / Core Motion             │
└───────────────────────────────────────────────┘
```

The single place where fake vs real implementations are chosen is
`lib/app/providers.dart`.

## Service interfaces (Phase 1: all fake, in `lib/services/fake/`)

| Interface | Responsibility |
|---|---|
| `ClockService` | "Now" — fakeable so Debug can fast-forward time |
| `ProfileService` | Current user profile (name, Hebrew form of address, interests, languages, openness tiers, FoF opt-in) and preferences |
| `SocialGraphService` | People, connections, relationship types, mutual-friend counts, shared groups, block/unblock, unmatch, suggestion pauses, call/feedback history, search |
| `AvailabilityService` | My availability (mode + expiry) and others' availability |
| `MatchService` | Suggestion history + mutual-consent handshake (`requestCall` → accepted/declined) |
| `InvitationService` | Availability Beacon: send to a few people, receive invitations, answers, per-recipient daily counts |
| `CallService` | In-app audio call (simulated now, LiveKit in Phase 5). Regular calls use `PhoneDialer` |
| `NetworkService` | Online / weak signal (debug can simulate offline) |
| `VoiceMessageService` | Short voice notes (simulated — nothing recorded) |
| `SafetyService` | Reports |
| `AnalyticsService` | Privacy-respecting event log (local only in Phase 1) |
| `VehicleSignalSource` (platform) | `VehicleEvent.enter/exit` + confidence (normal / high with car Bluetooth) |
| `PhoneDialer` (platform) | Regular phone call: Kotlin bridge in `MainActivity.kt` (ACTION_CALL with CALL_PHONE permission, else ACTION_DIAL) |
| `VoiceService` (platform) | Read aloud (`flutter_tts`) + "yes"/"no" (`speech_to_text`), `SilentVoiceService` in tests |

Services keep a synchronous cached state plus a `changes` stream (like a local
cache kept fresh by Supabase Realtime later). `dataVersionProvider` bumps on any
change; widgets watch it and read services synchronously. `nowProvider` ticks
every second for countdowns.

All fake services share one in-memory `FakeWorld` (seed data in
`fake_seed.dart`: 15 people — close friend, sister, father, army friend,
childhood friend, university friend not talked to for 6 months, two colleagues,
former colleague, English-only colleague, acquaintance from a running group,
three friends-of-friends (one did not opt in) and one person from a shared group).

## Domain model

- `Person` — id, name, generated avatar color, `Gender` (for Hebrew grammar only),
  languages, interests, groups, friend ids (for mutual counts only), open tiers,
  FoF opt-in, adult-verified, safety-restricted.
- `Connection` — my view of a person: optional `RelationshipType`, optional
  private context label ("חבר מהצבא"), last **in-app** interaction, call count,
  feedback history, last time I passed on them.
- `SuggestionPause` — "not today" (until midnight) / "don't suggest for a while"
  (30 days, configurable). Works for non-connections too.
- `Availability` — mode, startedAt, **expiresAt (always set)**, untilTripEnds,
  source (manual / automaticVehicle / shortcut).
- `MyPreferences` — auto driving availability (**off by default**), excluded
  relationship types, invitation frequency, invitation mute, onboarding, 18+.
- `MatchReason` (sealed) — `AvailableFor`, `Dormant`, `NeverTalkedInApp`,
  `MutualFriends`, `SharedGroup`, `SharedInterests`, `BothOpenToFriendsOfFriends`,
  `EnjoyedLastTime`, `AnsweredYourInvitation`. Built only from real fields; the UI
  turns them into Hebrew text.

## Matching engine (`lib/matching/`)

`MatchingEngine.rank(request, candidates) → RankResult(ranked, rejected)` then
`pick(result) → Suggestion?`. Pure Dart, random source injectable.

1. **Filters**: blocked · skipped in this window · safety (restricted / not 18+) ·
   paused (not today / don't suggest) · relationship type I excluded · no shared
   language · not available (except when ranking for the Beacon) ·
   non-connections need a shared group or (mutual friends AND both opted in to FoF).
2. **Tier** (both sides must be open to it, most familiar first):
   familiar = close types not dormant · reconnect = known & silent ≥ 60 days ·
   widen circle = colleagues/acquaintances/FoF/groups · surprise me = FoF/groups/acquaintances.
3. **Score** = Σ weight × feature (0..1): closeness, dormancy (0 if I passed on
   them in the last 30 days), available now, overlap minutes, shared interests,
   shared group, mutual friends, recently suggested (penalty), past feedback
   ("don't connect again" = −1).
4. **Pick**: top score, except `explorationRate` (10%) of the time a random one of
   the next best (top-K = 4) — marked "הפתעה קטנה".
5. **Explain**: availability first, then up to `maxReasons` (3) reasons by contribution.

Weights, caps, cooldowns, exploration, beacon limits and snooze lengths are in
`assets/config/matching.json`.

## Session flow (`lib/app/session_controller.dart`)

Phases: `idle → searching → options → waitingForAnswer → inCall → feedback`,
plus `quickConnecting` (mutual pre-approval countdown) and `voiceMessage`.

- Options: `engine.pickOptions(result, optionsShown=3)`; exploration replaces only
  the last slot. Driver mode shows/reads only the first; "no" drops it.
- Quick connect (checked before options): mutual `Connection.quickConnect` +
  `Person.quickConnectIds`, 5s countdown + spoken cancel, limits in config.
- Call method: connection → phone; non-connection → phone only if both
  `sharesNumberWithFriendsOfFriends`, else in-app.
- Call request timeout `callAnswerTimeoutSeconds` (30). While waiting, the
  other side becoming unavailable or blocking me ends the wait (block shown as
  "can't now").
- A call is recorded as an in-app interaction only after feedback says we
  talked ("לא דיברנו בסוף" records nothing).
- Offline: search pauses and retries every 3s; a banner is shown.
- Circles: `Availability.circleId` → `MatchRequest.circle` filter.
- Routines (`MyPreferences.routines`) show a one-tap card on Home when due.


- Start availability → searching (short delay) → engine pick → suggestion.
- "Talk now" → ask the other side (`requestCall`) → only on **yes** → call.
  Declined → notice + next suggestion. No auto-connect anywhere.
- Next / not today / don't suggest / block / report → next suggestion.
- Nobody available → after `waitSecondsBeforeBeacon` (8s) send invitations to at
  most 3 people (not currently available, under their daily limit). A "yes"
  comes back as a suggestion marked already-accepted.
- Incoming invitation → full-screen: talk now / not now / mute 4 hours.
- Expiry checked every second; a call in progress is allowed to finish.
- After a call: feedback, unless in driver mode — then it waits until driving ends.
- Vehicle ENTER: driver mode; if auto availability is ON (opt-in) → driving
  availability "until trip ends" (capped at 3 hours). Never a call.
  Vehicle EXIT: ends trip-bound availability (after the call, if one is running).

## Driver mode

`isDriverMode = probablyInVehicle || (available && mode == driving)`. The root
swaps to `DriverScreen`: dark, max 3 huge buttons (call / next / stop), one short
line of text, no lists, no typing. Calls and invitations also get large layouts.

## Platform: vehicle detection (Phase 4 / 7)

- **Android:** Activity Recognition Transition API (`IN_VEHICLE` ENTER/EXIT) through a
  small Kotlin `MethodChannel`/`EventChannel` bridge unless a maintained package does it
  correctly. Optional user-selected car Bluetooth device → higher confidence. No
  continuous GPS. Detection stays on device; only availability is sent to the server.
- **iOS:** App Intents (`StartAvailability`, `StopAvailability`,
  `StartDrivingAvailability`, `PauseAvailability`) for Shortcuts automations triggered by
  Driving Focus or CarPlay connect/disconnect. Core Motion only as a foreground signal.
  No background GPS without explicit owner approval.

## Backend (Phase 2+, not connected yet)

Supabase: Postgres for the social graph, Auth, Realtime for availability, Row Level
Security on every table, server-side (Edge/RPC) functions for matching, beacon fan-out,
and safety actions. Availability rows have `expires_at`; a scheduled job + query-time
filter guarantee expiry even if the app is killed. Only the anon/public key ever ships
in the app; service keys live only in server environment.

## Calls (Phase 5, not connected yet)

Managed RTC (LiveKit preferred), audio only, no recording, no transcription. Tokens
minted by a server function after both sides consent.

## Localization

`flutter_localizations` + ARB files (`app_he.arb` is the template; add `app_en.arb`
and a locale in `app.dart` for English). Hebrew grammar uses ICU `select` on the
person's form of address. Layout uses `start/end` (never left/right).

## Debug tools

`lib/debug/` — compiled in only when `kDevTools` (`--dart-define=DEV_TOOLS=true`
or a debug build). A small wrench button on the side of every main screen opens it.
Controls: vehicle enter / enter+Bluetooth / exit, clock +5m/+15m/+1h/+1d/+30d,
simulate match, force no-match, everyone unavailable, other side always
accepts/declines, simulate incoming invitation, per-person availability,
matching inspector (scores, reasons, filters), local analytics counts, reset data.

## Testing

- `test/matching_engine_test.dart` — filters, tiers, scoring, reasons-only-from-data,
  exploration.
- `test/session_flow_test.dart` — full flows with fake time: consent before call,
  decline → next, auto-driving opt-in, feedback deferred while driving, beacon
  limits, beacon "yes", expiry, invitation mute, block, not-today.
- `test/app_smoke_test.dart` — onboarding (18+ gate) → RTL home → suggestion.
- CI: `.github/workflows/android.yml` runs analyze + tests and builds the APK.

## Android signing (test builds)

CI signs release APKs with one stable test key (GitHub secrets
`ANDROID_TEST_KEYSTORE_BASE64`, `ANDROID_TEST_KEYSTORE_PASSWORD`, alias
`drivetalk`) so updates install over previous builds. The key is never in git.
Public certificate SHA-256 (needed later for Android App Links `assetlinks.json`):
`BA:B3:22:23:52:5B:14:DA:F4:11:6A:2A:8D:73:76:EA:8D:0E:40:A3:25:3C:24:69:2E:E9:BE:FD:B4:70:A8:AB`
Build number = GitHub run number.
