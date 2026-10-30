# DriveBond — full briefing for an AI reviewer

> **לבעלים:** את הקובץ הזה מעלים או מדביקים לכלי בינה מלאכותית אחר (ChatGPT, Gemini וכו'), ומבקשים ממנו משוב. הכלי יענה בעברית פשוטה. ההוראות בשבילו נמצאות בסוף הקובץ.

_Last updated: 2026-10-29 · Android build ~186 · server schema 66 · live on Google Play (Israel)_

---

## 0. Who is asking, and what we want from you

- **Owner:** one non-programmer in Israel (Hebrew speaker). All code is written by an AI coding assistant.
- **Budget:** free tiers only for now. The owner has decided not to pay for a server plan yet.
- **What we want from you:** problems, risks and missed opportunities we have **not** seen. Cover product, user experience, retention and growth, privacy and legal (Israel and Google Play), safety in the car, and technical reliability.
- **Answer format:** concrete, prioritized, in **simple Hebrew**, from the user's point of view. Full instructions are in §12.

---

## 1. The product in one paragraph

**DriveBond** turns "dead time" (driving, traffic, walks, breaks) into a phone call with someone you already know.

- **Availability:** you mark yourself available. It always has an end time, at most 3 hours.
- **Matching:** when a friend is available too, the app asks "X has time now — talk?".
- **The call:** it starts only when both said yes, or one side switched on a standing "yes" (see §4). One phone dials the other through the phone's **regular dialer**. It is a normal phone call: nothing is recorded, and there is no in-app chat.
- **What it is not:** no feed, no likes, no strangers, no random chat.
- **Platforms and language:** Android only (Flutter); iPhone is planned. Hebrew and RTL first.

---

## 2. Current status (end of October 2026)

- **Google Play:**
  - **Production access was granted** after a closed test with about 20 testers.
  - The first production release went out with a staged rollout. Package `app.drivetalk.drivetalk`, name DriveBond, target audience 18+.
  - Every build is uploaded automatically to internal testing. The owner promotes a tested build to production by hand.
- **Users:** the owner, testers, and their friends. The real cold start is just beginning.
- **Public pages:** invitation, privacy policy and account deletion pages at `https://fenetnet.github.io/Drivetalk/…`.
- **A competitor exists:** an app called "DriveTalk" ("patent pending"), with similar onboarding imagery. Our package id still contains "drivetalk"; that can't be changed on Play.

---

## 3. Users and the core loop

1. **Join.**
   - **"Continue with Google"** (recommended; the account comes back on a new phone), or a display name only (anonymous account).
   - The phone number is optional but encouraged. It is used for the real call, and so friends can find you in their contacts.
   - Then: an optional photo, then all permissions on one screen, each with a full "why".
2. **Get friends.**
   - **Invitation link**, or **contacts search**.
   - Contacts search: only numbers are read, hashed on the phone, and the server answers which contacts use DriveBond. The user picks whom to add, and they are connected at once.
   - Names never leave the phone.
3. **Become available** (Home, one tap):
   - **"🚗 I'm driving"** (big) or **"☕ I have time"** (small). Each is 30 minutes in one tap.
   - **The time:** tap it to choose 15 minutes to 3 hours, or "until 18:30". It can also be shortened.
   - **"Available to…":** only the groups I tick, or everyone except the groups I tick. The app remembers the choice.
   - Other ways to start: a home-screen widget, a quick-settings tile, routines (e.g. Sun–Thu 07:30).
   - **Automatic driving detection** (opt-in, off by default): Android Activity Recognition "in vehicle", double-checked about once a minute, or the car's Bluetooth. **No GPS.** The first 5 minutes of a trip are quiet ("ready now" / "not this trip").
4. **Matching.** The server matches two available friends (rules in §5).
   - The question arrives full screen, or as a notification.
   - **While driving** it is read aloud with a beep, and the user can answer "כן"/"לא" by voice. With a locked screen the app opens like an incoming call.
5. **The call.** When both said yes, exactly **one** phone dials. The rule: **whoever tapped the other calls**; otherwise the last one to say yes. The other phone simply rings.
6. **After the call:** "how was it?" (good / not again soon / didn't talk). While driving this question waits until the trip ends.

---

## 4. All current features (user's view)

**Home (top to bottom)**
- **"Now":** faces of available friends (🚗 driving / ☕ free, minutes left), friends in a call, and me.
- **Start buttons**, or **my card** ("you're driving · 29 min left ✎ · available to: …" + End).
- **One card with both automatic switches:** "available automatically while driving", then "yes automatically while driving".
- **One tip card at a time.** Examples: a pending friend, a new contact joined, an update, a routine idea, the widget tip.
- **Small extras:** "your week" (number of calls), a health line when a phone setting blocks the app (with a fix), and a one-time "what's new".
- **There is no separate driver screen any more** (owner decision D-156): while driving, the regular Home shows "you're driving".

**Yes automatically while driving (D-153)**
- **The switch:** off by default. You choose who it covers: friends with 3+ stars (unrated friends count as 3), 4+, or only 5.
- **When it applies:** only while you are driving, have a phone number, aren't in a call, and aren't in quiet hours.
- **One side on:** a matching friend who taps you, or who says yes to the app's question about you, is connected at once. **They call; your phone just rings.** You never dial by yourself while driving.
- **Both on for each other, both driving:** the app's suggestion connects by itself, like quick connect. There is a 5-second spoken, cancellable countdown, and whoever starts first calls. No daily limit.
- **How it looks:** friends who would connect at once show a **pulsing gold ring + ⚡**. My own picture gets the same ring when my switch is on.

**Offer, waiting and call**
- **The question:** "לX יש זמן עכשיו — לדבר?", with "talk now" / "not now". It lasts 30 seconds.
- **Waiting for the other side:** up to 30 seconds, then a gentle "no answer".
- **After an unanswered question:** the person who didn't answer gets a push, "X tried to reach you". Tapping it asks X back.
- **Busy friends:** shown as "in a call" (the phone reports yes/no only). The call is over once either side ends it.

**My people**
- A list with status, **stars 0–5** (0 = never suggested, and they can't ask me), and a **heart** ("I'd like to talk": a silent priority).
- **Quick connect per person:** both turn it on for each other. A match then starts a 5-second cancellable countdown. Limited to once per window and once per pair per day.
- **Groups:** just lists of people, used by "available to…". The old per-group "who sees me in each mode" rules are hidden, unless someone already set them.
- **Friend menu:** remove, block, report. "People I removed" can be brought back.

**Settings**
- **Profile:** name, photo, phone number, Google account.
- **Driving:** auto availability, car Bluetooth, yes automatically (and its star level), routines, voice on/off, **test drive** (practice a voice question).
- **Privacy:** free without my name, hide when in a call, quiet hours (several ranges, by weekday), blocked people.
- **Other:** notifications, send feedback, **report a problem** (with technical details, never names or voice), delete my account (also removes the Google link).
- **Hidden owner tools:** numbers, feedback and crash inbox, and "why is X grey?".

**Background (Android)**
- **Push:** Firebase Cloud Messaging. Questions and agreed calls arrive as empty wake-ups; the phone then fetches the details.
- **Other pushes:** "X is on the way" (to mutual quick-connect friends) and "X tried to reach you", each at most once a day.
- **While available:** a foreground service runs, with a persistent notification and Stop. An automatic trip is a 15-minute lease, renewed every 4 minutes.
- **Battery:** the user is asked once for a battery-optimization exemption.
- **Opening the app:** it shows the last saved screen at once (friends greyed out until the server answers).

---

## 5. Matching rules (server: Postgres functions `create_offers_for`, `ask_friend`, `ask_check`)

**Who can be offered**
- Both must be connected, available, and in each other's audience.
- Not blocked, and neither gave the other 0 stars.
- No pause between them. After a call there is an automatic pause, and a pause can also be chosen.
- Neither is in a call, and neither has another open question.

**Order of suggestions**
- Mutual quick-connect friends first.
- Then "I'd like to talk".
- Then friends who show their name.
- Then the sum of both ratings.
- Then the friend you talked with least recently.

**Anti-noise limits**
- One question at a time per person, and each lasts 30 seconds.
- The same pair once per window, unless they talked.
- Not suggested again for 60 minutes after talking.
- 5 quiet minutes after a question that didn't become a call, but only for the person who didn't say yes.
- "Asked enough": after 3 unanswered questions in a window (1 on an automatic trip), stop asking that person. Only questions the person did **not** say yes to count, since their last yes or tap.

**Rules for a tap (ask directly)**
- Tapping a free friend replaces the app's own unanswered question between the two of you.
- The tapper calls.
- An earlier "no" from the other person doesn't block them if they asked you afterwards.

---

## 6. Hard rules the product follows (non-negotiable unless the owner decides)

- **Consent:** a call needs consent from both sides. Accepted forms:
  - both say yes now;
  - mutual quick connect, with a 5-second cancellable countdown and limits;
  - "yes automatically while driving": a person's own opt-in standing yes, limited to friends with enough stars; when both have it on, the countdown stays.
- **Calls:** no recording, no transcription, no AI over call content. The call log is never read.
- **Location:** no GPS. Location, route and speed are never shared. The server knows only available / mode / until when.
- **Driving:** automatic availability is opt-in and off by default. The app never says "you are the driver", only "the phone is probably in a car". No typing while driving; questions come aloud and full screen.
- **Contacts:** numbers only, hashed on the phone. The server keeps only hashes of numbers that belong to users. Nobody is connected automatically. Removed pairs never come back from contacts.
- **Safety basics:** no feed, no anonymous random chat. Block / Report / Remove exist from day one. Match explanations use only real data.
- **Compatibility:** a server change must keep working with the app versions already installed. Once, older builds (< ~131) broke after a privacy change, and the owner chose to ask testers to update.

---

## 7. Data and privacy

**Server (Supabase, EU)**
- **Account:** display name, optional phone number (given to the caller only at call time), optional photo (friends only).
- **Google:** email and account id, only if the user chose Google.
- **Social:** friendships, groups (plus one hidden "available to" group per user), ratings, hearts, blocks, removed pairs.
- **Availability:** mode, until when, in a call yes/no, missed question. Deleted when it ends.
- **Activity:** questions and answers, after-call outcome, settings, quiet hours, push address and app build.
- **Diagnostics:** crash reports and problem reports (technical only), usage events (action name and duration).
- **Contacts:** hashes of contacts that are users.
- **Not stored:** location, call content, call log, contact names, voice.
- **Deleting an account** removes everything, including the Google link. Crash reports and feedback stay, detached from the person.

**Phone:** settings, routines, contact-name map, saved screen (names and photo versions only), photos cache, device token.

**Privacy policy:** https://fenetnet.github.io/Drivetalk/privacy.html

---

## 8. Technology

- **App:** Flutter (Dart), Riverpod 3, Hebrew ARB localization.
  - The logic is in one controller, `lib/real/real_controller.dart` (about 4,000 lines).
  - Screens are in `lib/features/real/`.
  - An in-memory backend mirrors the server rules for tests.
- **Android (Kotlin):**
  - a foreground service; Activity Recognition with a double check; a car Bluetooth receiver;
  - a full-screen-intent "incoming question", text-to-speech, speech recognition with a beep;
  - a home widget, a quick-settings tile, routines (AlarmManager), direct dial (`ACTION_CALL`);
  - a Firebase push service.
- **Server (Supabase):**
  - Postgres with Row Level Security. Logic lives in SECURITY DEFINER SQL functions; policy helpers in a `private` schema.
  - Realtime; anonymous and Google auth; Storage for photos.
  - An edge function sends pushes, driven by a pg_cron tick every minute.
  - 66 SQL migration parts. The owner pastes each new one into the SQL editor from a copy page.
- **Speed:** friend-related requests start from the friends list. With 4,000 test users they take a few milliseconds.
- **Build:** GitHub Actions builds the APK and the AAB and uploads to Play internal testing.
- **Tests:**
  - 197 Flutter tests (two-phone flows on the in-memory server, and screen tests on a small phone with large text);
  - 318 end-to-end checks against a real local Supabase;
  - a live two-phone test.

---

## 9. Known limitations and open risks (honest list)

1. **Cold start:** two friends must be available at the same minute. Automatic driving, routines, "X is on the way" and "yes automatically" help, but with few friends matches are rare.
2. **Free tier limits:**
   - Concurrent realtime connections are limited (about 200 on the free plan; to verify).
   - There are no daily backups.
   - Twice the API layer got stuck and needed a manual "Restart project".
3. **Accounts:** Google sign-in is new and optional. Anonymous users still lose their friends on a new phone.
4. **Phone numbers aren't verified** (no SMS). Someone could type another person's number.
5. **Contact hashes:** unsalted SHA-256 of Israeli numbers. That is a small space, reversible by brute force.
6. **Play policies:** activity recognition, foreground service, full-screen intent, battery exemption and contacts all need declarations and could be questioned.
7. **Phone makers' battery savers** (Xiaomi, Samsung, …) may stop the background service.
8. **No iPhone:** iPhone friends can't join, which hurts invitations.
9. **One owner:** server updates are manual, there is no monitoring or alerting, and crash reports go to an in-app inbox.
10. **Legal:**
    - No in-app age confirmation (Play says 18+).
    - No Terms of Service.
    - Israeli privacy law (Amendment 13) not reviewed by a lawyer.
    - A competitor named "DriveTalk" exists.
11. **Driving safety:** voice yes/no and automatic connection while driving. There is no separate driver screen any more; the regular Home is shown while driving.
12. **Monetization:** none. Ideas: a premium tier, family plans, organizations (field workers, loneliness programs). No ads.

---

## 10. Metrics available (owner's numbers screen, totals only)

- **Users:** users, new users, active users, friendships.
- **Usage:** "I'm free" taps, questions, quick connects, both-yes, talked, declined, no answer.
- **Feedback:** reports, feedback.
- **Speed:** median time from "yes" to dialing, and app opening time (in the test info).

---

## 11. Questions we'd love your help with

1. What will most likely make new users from the store **stop using the app in the first week**? How do we prevent it?
2. How do we beat **"nobody is free at the same time"** without breaking consent or becoming noisy?
3. Is the new simple Home ("I'm driving" / "I have time", one tap, 30 minutes, "available to…") clear for a non-technical Israeli 25–60?
4. **"Yes automatically while driving":** is the safety and consent design acceptable? What would you change?
5. **Onboarding:** what is missing? Think about the permissions order, Google vs. no account, and the first friend.
6. **Privacy and legal:** what must be fixed for Israel and Google Play now that the app is public?
7. **Growth:** how do we get each user to bring 2–3 friends, while iPhone users can't join yet?
8. **Business model:** what could work without ads or a feed?
9. **Competitor:** how should we handle the existing "DriveTalk" app (name, positioning)?
10. Anything you think is a **mistake** or **overbuilt**.

---

## 12. How to answer (instructions for the AI reviewer)

- Answer **in Hebrew**, simply, for a non-programmer.
- Start with the **5 most important problems or risks**, ordered by importance. For each:
  - what can go wrong for the user,
  - why you think so,
  - a concrete fix.
- Then list **quick wins** (small changes with big effect).
- Then **ideas** (bigger, optional).
- Mark anything that would **break a hard rule in §6** as such. Don't propose it as-is.
- If you need more detail, ask up to 5 short questions at the end.
