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
`lib/app/providers.dart` (service locator via Riverpod overrides).

## Service interfaces (Phase 1 has fake impls of all)

| Interface | Responsibility |
|---|---|
| `ClockService` | "Now" — fakeable so Debug can fast-forward time |
| `ProfileService` | Current user profile, preferences, openness levels |
| `SocialGraphService` | Connections, relationship types, mutual friends, groups, block/unmatch/don't-suggest |
| `AvailabilityService` | Start/stop/pause availability, mode, expiry; stream of who is available |
| `MatchService` | Requests a suggestion (uses matching engine), handles accept/skip/decline, mutual consent |
| `InvitationService` | Incoming/outgoing invitations (Beacon in Phase 6) |
| `CallService` | Start/end/mute an audio call (simulated in Phase 1, LiveKit in Phase 5) |
| `FeedbackService` | Post-call feedback |
| `SafetyService` | Report, block |
| `AnalyticsService` | Privacy-respecting event counters (local log in Phase 1) |
| `VehicleSignalSource` (platform) | Stream of `VehicleEvent.enter/exit` with confidence |

## Domain model (initial)

- `UserProfile` — id, displayName, avatar, languages, interests, ageVerified flag, openness settings.
- `Connection` — otherUserId, relationshipType? (optional), lastInAppInteraction?,
  callCount, feedbackHistory, doNotSuggestUntil?, blocked, source (invite/QR/search/group/fof).
- `RelationshipType` — family, closeFriend, friend, childhoodFriend, colleague,
  formerColleague, acquaintance, friendOfFriend, sharedGroup.
- `Availability` — userId, status (unavailable/available/paused), mode
  (driving/walking/break/free), startedAt, expiresAt, untilTripEnds flag, source (manual/auto).
- `MatchTier` — familiar, reconnect, widenCircle, surpriseMe.
- `Suggestion` — candidate, tier, score, reasons[] (typed, see below), isExploration.
- `MatchReason` — typed enum + data, e.g. `availableFor(minutes)`,
  `dormantFor(days)`, `mutualFriends(count)`, `sharedGroup(name)`,
  `bothOpenToFof`, `relationship(type)`. UI renders text from these via localization —
  reasons can only come from real fields, so they cannot be invented.
- `CallSession`, `Feedback`, `Report`, `Block`.

## Matching engine

Pure function: `rank(me, candidates, context, config) → List<Suggestion>`.

1. **Filters** (hard): blocked either way · unmatched · doNotSuggestUntil · tier not allowed
   by either side · not available · no shared language · safety flags · cooldown
   (suggested in the last N minutes / declined recently).
2. **Score** = Σ weight × feature, each feature normalized 0..1:
   closeness, dormancy bonus (capped, zeroed if user declined recently), both available now,
   overlap minutes, shared interests, shared group, mutual friends, recently-suggested penalty,
   past feedback.
3. **Select**: with probability `explorationRate` pick randomly from top-K instead of #1.
   Random seed injectable for deterministic tests.
4. **Explain**: top reasons by contribution, only from present data.

All weights, caps, cooldowns, `explorationRate`, top-K, and Beacon limits live in
`MatchingConfig` (loaded from `assets/config/matching.json` in Phase 1; server-side later).

## Driver mode

Driver mode is a UI state derived from: availability mode == driving **or** vehicle
signal active. When on, routes swap to minimal screens (max 3 huge actions, no lists,
no text input). Feedback prompts are deferred until driving ends.

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

`flutter_localizations` + ARB files (`app_he.arb` default, `app_en.arb` later).
`Directionality` from locale; layout uses `start/end` (never left/right).

## Debug tools

`lib/debug/` screen reachable only when `kDebugMode` (or a dev flavor). Controls the
fake services: vehicle enter/exit, who is available, fast-forward clock, force match /
no-match, simulate incoming invitation.
