# DriveBond — full briefing for an AI reviewer

> **לבעלים:** את הקובץ הזה מעלים או מדביקים לכלי בינה מלאכותית אחר (ChatGPT, Gemini וכו'), ומבקשים ממנו משוב.
> הכלי יענה בעברית פשוטה. ההוראות בשבילו נמצאות בסוף הקובץ.

_Last updated: 2026-10-08 · build 85 · server schema 24_

---

## 0. Who is asking, and what we want from you

- **Owner:** a single non-programmer in Israel (Hebrew speaker).
  - The code is written by an AI coding assistant.
  - Budget is close to zero: free tiers only.
- **What we want from you:** find problems, risks and missed opportunities that we have **not** seen yet. Cover:
  - product,
  - user experience,
  - retention and growth,
  - privacy and legal (Israel and Google Play),
  - technical reliability.
- **Be concrete and prioritized.** Answer in **simple Hebrew**, from the user's point of view. Output instructions are at the end of this file.

---

## 1. The product in one paragraph

**DriveBond** (working name until recently: DriveTalk) turns "dead time" into a phone call with someone you already know: commutes, traffic jams, walks, breaks.
- **Availability:** you mark "I have time now". It always has an end time; the maximum is 3 hours.
- **Matching:** when a friend is also free at the same time, the app asks **both** of you "X is free now — talk?".
- **The call:** only when **both say yes**, one phone dials the other through the phone's **regular dialer**. It is a normal phone call: nothing is recorded, and there is no in-app chat.
- **What it is not:** no feed, no likes, no strangers, no random chat.
- **Platforms:** Android first (Flutter). iPhone is planned later.
- **Language:** Hebrew + RTL first. English is planned for foreign markets.

**Tagline ideas in use:**
- "הזמן המת שלך. הזמן המת שלהם. שיחה אחת טובה."
- "מתי דיברתם בפעם האחרונה?"

---

## 2. Current status (October 2026)

- **Stage:** working prototype, used by the owner and a few friends.
- **Google Play:**
  - The app is registered (package `app.drivetalk.drivetalk`, name DriveBond).
  - Every build is uploaded automatically to the **Internal testing** track.
  - A **Closed testing** track is submitted for Google review.
  - Google requires **≥12 testers for 14 continuous days** before public release.
- **No real users yet** beyond testers. The plan is to recruit 15–20 testers in small groups of friends who know each other.
- **Store listing:**
  - Hebrew texts.
  - Feature graphic: "מתי דיברתם בפעם האחרונה?"
  - 7 screenshots: 2 concept images, then 5 app screens with headlines.
  - Blue/white design; green means "free".
  - Icon: a car inside a speech bubble.
- **Public pages:**
  - Invitation page, privacy policy and account deletion page are on GitHub Pages: `https://fenetnet.github.io/Drivetalk/…`
  - Contact e-mail: fenet.net@gmail.com.

---

## 3. Users and the core loop

1. **Join** with a **display name only** (anonymous account; no password, no e-mail).
   - Phone number is **optional**. It is used for the real call, and so friends can find you in their contacts.
   - Next step: an optional **profile photo** ("so they recognize you"). It can be skipped; one sentence explains how to add it later.
2. **Get friends:**
   - **Invitation link** via the phone's share sheet. The friend installs and opens the link, and you're connected.
   - **Contacts:** the app reads only phone numbers, hashes them on the phone (SHA-256 of the +972 form) and the server returns which contacts use DriveBond. **The user picks** whom to add, and they are connected at once (no approval step).
     - Names never leave the phone.
     - Friends are shown under the name saved in **my** contacts.
3. **Mark yourself free** in one of these ways:
   - the big "יש לי זמן עכשיו" button (choose mode: driving / walking / break / free, and duration);
   - the **home-screen widget** or **quick-settings tile** (one tap, 30 min);
   - **routines** (e.g. Sun–Thu 07:30 for 40 min);
   - **automatic driving detection**: opt-in, off by default. It uses Android Activity Recognition "in vehicle" transitions, or the car's Bluetooth. **No GPS.**
4. **The server matches** two friends who are both free (rules in §5). Both get the question: full screen if the app is open, otherwise a notification (and read aloud while driving).
5. **Both say yes.** The server picks exactly **one caller**. The caller's phone dials immediately (CALL_PHONE permission; it falls back to opening the dialer). The other side sees "X is calling you now".
   - If no numbers were shared, a **simulated** in-app "call" screen is shown. There is no real audio yet; LiveKit is planned.
6. **After the call:** "It was good" / "We talked, but not again soon" (7-day snooze for this pair) / "We didn't talk". While driving, this question waits until the trip ends.

---

## 4. All current features (user's view)

**Home**
- **"Right now" card:** faces of friends who are free, each with a small icon (car / walking / coffee / sun) and minutes left. Friends **in a call** show a phone icon and "בשיחה".
- **Big button:** "יש לי זמן עכשיו" (I have time now).
- **"Your week":** number of calls this week.
- **One tip card at a time:** update available / new contact joined / friend inactive a week / allow background / suggest a routine / widget tip.

**Offer screen**
- Text: "לX יש זמן עכשיו — רוצה לדבר?" (X has time now — want to talk?).
- Buttons: "לדבר עכשיו" (talk now), "לא עכשיו" (not now), and "לא עכשיו — אחזור אליך" (not now — I'll get back to you; the other side is told gently).
- **Waiting for the other side:** up to 25 s, then "no answer" (gently).

**Driver mode** (when the mode is driving)
- Dark screen, huge buttons, one person, minimal text.
- The offer is **read aloud**, and the user can answer **"כן"/"לא" by voice**. Speech is recognized on the phone (or by the phone's speech service); nothing is recorded.

**My people**
- A list with status, stars (0–5 "how much I want to talk"; default 3; **0 = never offered**) and a heart.
- **Heart ("אשמח לדבר" / I'd like to talk):** a silent priority for today / this week / until removed. The friend is not notified.
- **Friend menu:** rating, remove, block, report.
- **Circles:** private groups. Availability can be for one circle only. A circle can be **"quick connect"**: if both pre-approved each other, a match starts a 5-second cancellable countdown and dials without asking. This is limited to once per availability window and once per pair per day.
- **Hidden sections:**
  - Friends who haven't opened the app for 30+ days are folded into a separate section.
  - **"People I removed"** list, with a "bring back" button. Only the one who removed can bring the other back.
- **"Search contacts again"** button. A quiet re-sync also runs at most twice a day when the app opens or returns.

**Settings**
- **Profile:** name, photo, phone number.
- **Driving:** automatic availability while driving (opt-in), car Bluetooth, routines, read-aloud on/off, speak names on/off.
- **General:** notifications (opens Android settings), **hide my status** (friends don't see when I'm free and I don't see theirs; offers still happen), check for update, **send feedback** (free text to the owner), blocked people, privacy explanation, **delete my account and data**.
- **Hidden owner tools:** a long press on "check for update" opens a code prompt. Behind it: numbers (totals only, 7/30 days), the feedback inbox and the reports inbox.

**Background behaviour (Android)**
- During an availability window, a **foreground service** (type `dataSync`) shows a persistent notification ("available to talk", with Stop).
  - It polls the server every 10 s for offers, shows offer notifications with Accept/Decline, and reads them aloud unless the app is on screen.
  - It reports "in a call" (yes/no from `AudioManager.mode`, no permission) so friends see "בשיחה".
- **There is no push service (no FCM).** Outside your own availability window you get **no** notifications.
- **Battery:** after first use the user is asked once to exempt the app from battery optimization.

**Inactive friends**
- Friends see only whole days since "last seen".
- After 7 days, one gentle card appears: "X hasn't opened DriveBond for a week — remove?"

---

## 5. Matching rules (server, Postgres function `create_offers_for`)

- **Who can be offered:** two people are offered to each other only if all of these hold:
  - they are **connected**,
  - both have **active availability**,
  - each is in the other's **audience** (circle),
  - **not blocked**,
  - neither gave the other **rating 0**,
  - no "not soon" snooze,
  - neither is **in a call** (in-app call up to 20 min, or another phone call),
  - neither has another open question.
- **Ordering:** mutual quick-connect first, then "I'd like to talk" (either side), then the sum of both ratings, then **least recently talked**.
- **Anti-noise limits:**
  - one offer at a time per person;
  - an offer expires after **2 minutes**;
  - the same pair at most **once per availability window** (unless they talked);
  - not the same pair within **30 min after a call**;
  - **5 quiet minutes** after a question that didn't become a call;
  - at most **3 questions (that didn't become calls) per availability window**.
- **Driving availability** is a 15-minute lease renewed by the phone every 4 minutes, so it ends by itself if the phone dies.

---

## 6. Hard rules the product follows (non-negotiable)

- **Consent:** a call starts only with consent from **both** sides. Either both say yes now, or both pre-approved "quick connect" (and even then: a visible cancellable 5-second countdown, limited frequency).
- **Calls:** no recording, no transcription, no AI over call content.
- **Phone data:** the phone **call log is never read.**
- **Location:** no GPS. Location, route and speed are never shared with anyone. The server knows only "available / mode / expires_at".
- **Availability:** always expires. Automatic driving detection is opt-in and off by default.
- **Wording:** never claims "you are the driver", only "the phone is probably in a vehicle".
- **Contacts:** only numbers, hashed on the phone. The server keeps only hashes of numbers that belong to DriveBond users. Nobody is connected automatically; anyone can remove; removed pairs never come back from contacts.
- **Driver mode:** huge buttons, no typing, no scrolling lists, one person at a time.
- **Safety and content:** no feed. Block / Report / Remove exist from day one. Match explanations use only real data.
- **Gender:** gender-neutral Hebrew wording for everyone (no gender question).

---

## 7. Data and privacy (what is stored where)

**Server (Supabase, EU region)**
- **Account and profile:** display name, optional phone number (shown to a friend only at call time, to the side that dials), optional profile photo (private storage, friends only).
- **Friends:** friendships, circles, ratings and "I'd like to talk" (only the owner of the rating sees it), blocks, removed pairs (with who removed).
- **Availability:** mode and expiry, deleted when it ends. Also "in a call until" timestamps (yes/no only).
- **Offers and calls:** offers and their answers, after-call outcome.
- **User-written content:** reports (visible only to the app owner) and feedback text (visible only to the app owner).
- **Usage events:** action name and duration only.
- **Last seen:** whole days shown to friends.
- **Contacts:** hashes of contacts' numbers that are DriveBond users.
- **Background device token:** hashed on the server, for the background service.
- **Not stored:** location, call content, call log, contact names.
- **Account deletion** (in the app, or by e-mail) removes everything. Exception: feedback text stays, but detached from the account.

**Phone (local)**
- Settings, routines, local contact names map, cached friend photos (cache directory), device token (SharedPreferences).

**Privacy policy:** https://fenetnet.github.io/Drivetalk/privacy.html
**Account deletion page:** https://fenetnet.github.io/Drivetalk/delete.html

---

## 8. Technology

- **App:** Flutter (Dart), Riverpod 3, Hebrew ARB localization. All app logic is in one controller (`lib/real/real_controller.dart`).
- **Android native (Kotlin):**
  - foreground service (dataSync), Activity Recognition Transition API, car Bluetooth receiver;
  - home-screen widget, quick-settings tile;
  - routines (AlarmManager), TTS, notifications, contacts reader, direct dial (`ACTION_CALL`).
- **Server:** Supabase.
  - Postgres with Row Level Security; logic in SECURITY DEFINER SQL functions; Realtime (one channel per table).
  - Anonymous auth; Storage for photos.
  - Schema changes are SQL migration files. The owner pastes each new one into the Supabase SQL editor, using a copy page.
- **Build and release:** GitHub Actions builds the APK (also downloadable from a fixed GitHub release link for testers outside Play) and the AAB (Play), and uploads the AAB to Play internal testing automatically through a Google service account.
- **Tests:**
  - 82 automated Flutter tests (two simulated phones against an in-memory copy of the server rules);
  - an end-to-end script against a local Supabase (dozens of security and logic checks);
  - one live two-phone test against a real local server.
- **Static site:** GitHub Pages hosts the invitation page, privacy and deletion pages, and the store images.

---

## 9. Known limitations and open risks (honest list)

1. **Cold start / overlap problem.** A match needs two friends free **at the same minute**. With few friends on the app, matches will be rare, and an empty app may be uninstalled. There is no push notification outside one's own window.
2. **No real in-app audio.** If no phone numbers are shared, the "call" is simulated. The phone number is optional, so this can happen.
3. **Anonymous accounts.** A new phone or a reinstall creates a new account, and friends are lost. There is no login or recovery.
4. **Phone numbers are not verified** (no SMS code). Someone could type another person's number.
5. **Contact hashes are unsalted SHA-256** of Israeli numbers. That is a small space, so they are reversible by brute force.
6. **Play policy exposure:**
   - `ACTIVITY_RECOGNITION` triggers Google's "health apps" declaration (our use: vehicle detection only).
   - The `dataSync` foreground service needs a declaration and video. Android 15 limits dataSync services to 6 h per day.
   - The battery-optimization exemption request is a sensitive permission.
7. **Battery / OEM killers** (Xiaomi, Samsung etc.) may stop the background service despite the exemption.
8. **Polling every 10 s** from every available phone. This is fine at prototype scale and may matter at thousands of users on a free tier.
9. **iPhone is not supported yet.** Friends with iPhones can't join, which hurts invitations.
10. **Single owner, manual server updates, no monitoring or alerting.** There is no crash reporting service.
11. **Legal:**
    - No age gate (target audience declared 18+).
    - No Terms of Service document yet; only a privacy policy.
    - Israeli privacy law (Amendment 13) and Play policies not reviewed by a lawyer.
12. **Owner tools** are protected by a short numeric code.

---

## 10. Metrics available (owner's "numbers" screen, totals only)

Users, new users, active users, friendships, "I'm free" taps, offers, quick connects, both-yes, talked, declined, "I'll get back to you", no answer, reports, feedback, and median time from "yes" to dialing.

---

## 11. Questions we'd love your help with

1. What will most likely make the 15–20 closed-test testers **stop using the app in the first week**? How do we prevent it?
2. How do we solve the **"nobody is free at the same time"** problem with few friends, without breaking the consent rules and without becoming noisy?
3. Is "both mark themselves free" the right core mechanic? Are there lighter ways to signal availability, or better default availability (routines, auto driving)?
4. What is missing in **onboarding** for a non-technical Israeli user (permissions order, explanations, first friend)?
5. **Privacy/legal:** what must we fix before a public release in Israel and on Google Play? (Data safety, health declaration, foreground service, contacts, age, terms.)
6. **Safety in the car:** is the driver-mode flow (voice yes/no, read-aloud, immediate dialing) acceptable? What would you change?
7. **Growth:** how should invitations work so that each user brings 2–3 friends? (Remember: iPhone users can't join yet.)
8. **Pricing:** what could a future business model be without ads or a feed?
9. **English/international:** what changes in the product or texts for markets outside Israel?
10. Anything in this design that you think is a **mistake**, or that we're **overbuilding**.

---

## 12. How to answer (instructions for the AI reviewer)

- Answer **in Hebrew**, in simple language, for a non-programmer.
- Start with the **5 most important problems or risks**, ordered by importance. For each:
  - what can go wrong (from the user's point of view),
  - why you think so,
  - a concrete suggestion to fix it.
- Then list **quick wins** (small changes with big effect).
- Then **ideas** (bigger, optional).
- Mark anything that would **break one of the hard rules in §6** as such. Don't propose it as-is.
- If you need more detail, ask up to 5 short questions at the end.
