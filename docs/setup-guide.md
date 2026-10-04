# מדריך הפעלה — בדיקה אמיתית עם חבר

_לבעלים. בערך 20–30 דקות, פעם אחת. אין צורך לתכנת._

האפליקציה כבר בנויה. מה שחסר זה רק "לחבר את החשמל": שרת (Supabase) ודף הזמנה.
בלי זה האפליקציה עובדת במצב **הדגמה** בלבד.

> **אסור לשלוח לי, ואסור לשמור ב-GitHub:**
> - סיסמת מסד הנתונים (Database Password) של Supabase
> - מפתח `service_role` או מפתח שמתחיל ב-`sb_secret_`
>
> **מותר:** Project URL, והמפתח הציבורי (`sb_publishable_...` או `anon public`). הם ציבוריים בכוונה, וההגנה על המידע נעשית בשרת עצמו.

---

## שלב 1 — מפתח החתימה ב-GitHub (אם עוד לא עשית)

בלי זה כל עדכון דורש הסרה והתקנה מחדש.

1. נכנסים ל-https://github.com/fenetnet/Drivetalk
2. **Settings** (למעלה מימין) ‹ בתפריט משמאל **Secrets and variables** ‹ **Actions**.
3. בלשונית **Secrets** לוחצים **New repository secret**:
   - Name: `ANDROID_TEST_KEYSTORE_BASE64`
   - Secret: כל התוכן של הקובץ `keystore_base64.txt` ששלחתי.
   - לוחצים **Add secret**.
4. שוב **New repository secret**:
   - Name: `ANDROID_TEST_KEYSTORE_PASSWORD`
   - Secret: התוכן של `keystore_password.txt`.
   - **Add secret**.

## שלב 2 — שרת Supabase (חינם)

**מה זה:** מסד נתונים בענן, שמחבר את הטלפון שלך לטלפון של החבר.
**עלות:** חינם (עד 50,000 משתמשים בחודש). בלי כרטיס אשראי.
**לדעת:** פרויקט חינמי "נרדם" אחרי 7 ימים בלי שימוש. מעירים אותו בכניסה לאתר ובלחיצה על **Restore**.

### 2א. פתיחת פרויקט
1. נכנסים ל-https://supabase.com ‹ **Start your project** ‹ **Continue with GitHub**.
2. אם נשאלים על Organization: שם כלשהו, תוכנית **Free**.
3. **New project**:
   - Name: `drivetalk-test`
   - Database Password: לוחצים **Generate a password**. שומרים אותה אצלך (למשל במנהל הסיסמאות של Google). **לא לשלוח לי.**
   - Region: **Central EU (Frankfurt)**.
   - לוחצים **Create new project** ומחכים כ-2 דקות.

### 2ב. הכנת מסד הנתונים (העתק-הדבק אחד)
1. בטאב אחר פותחים את הקובץ:
   https://github.com/fenetnet/Drivetalk/blob/claude/social-voice-app-mnrxc1/supabase/migrations/20261002000000_two_user_test.sql
2. למעלה מימין לקובץ יש כפתור **Copy raw file** (שני ריבועים). לוחצים עליו.
3. חוזרים ל-Supabase ‹ בתפריט משמאל **SQL Editor** ‹ **New query**.
4. מדביקים (Ctrl+V) ולוחצים **Run** (או Ctrl+Enter).
5. אם קופצת אזהרה על "destructive operation", לוחצים **Run this query**.
6. אמורה להופיע ההודעה **Success. No rows returned**.

### 2ב׳. קובץ שני — זיהוי נסיעה אוטומטי
אותו דבר בדיוק, עם הקובץ:
https://raw.githubusercontent.com/fenetnet/Drivetalk/claude/social-voice-app-mnrxc1/supabase/migrations/20261003000000_auto_driving.sql
(SQL Editor ‹ New query ‹ הדבקה ‹ Run ‹ "Success").

### 2ב״. קובץ שלישי — מעגלים, חיבור מהיר וביטול חסימה
https://raw.githubusercontent.com/fenetnet/Drivetalk/claude/social-voice-app-mnrxc1/supabase/migrations/20261004000000_circles_quick_unblock.sql
(אותו דבר: SQL Editor ‹ New query ‹ הדבקה ‹ Run ‹ "Success").

### 2ב‴. קובץ רביעי — חברים מאנשי הקשר
https://raw.githubusercontent.com/fenetnet/Drivetalk/claude/social-voice-app-mnrxc1/supabase/migrations/20261005000000_contacts.sql

### 2ג. הפעלת כניסה בלי סיסמה
1. בתפריט משמאל: **Authentication** ‹ **Sign In / Providers**.
2. מפעילים את **Allow anonymous sign-ins**.
3. לוחצים **Save**.
4. מרעננים את הדף ומוודאים שהמתג עדיין דלוק.

### 2ד. העתקת שני הערכים הציבוריים ל-GitHub
1. ב-Supabase: גלגל השיניים **Project Settings** ‹ **API Keys** (בגרסאות מסוימות: **Data API** / **API**).
   - **Project URL**: נראה כמו `https://abcd1234.supabase.co`. לפעמים הוא נמצא בעמוד **Data API** או בכפתור **Connect** שבראש הדף.
   - **Publishable key**: מתחיל ב-`sb_publishable_`. אם אין כזה, משתמשים במפתח **anon public** (מתחיל ב-`eyJ`).
   - **לא** להעתיק את **secret** ולא את **service_role**.
2. ב-GitHub: **Settings** ‹ **Secrets and variables** ‹ **Actions**. בוחרים את הלשונית **Variables** (לא Secrets) ‹ **New repository variable**:
   - `SUPABASE_URL` = ה-Project URL.
   - `SUPABASE_ANON_KEY` = ה-publishable/anon key.

## שלב 3 — דף ההזמנה (חינם, בלי חשבון חדש)

זה הדף שהחבר רואה כשהוא לוחץ על קישור ההזמנה: כפתור הורדה, כפתור "פתיחה באפליקציה" והקוד.

1. ב-GitHub: **Settings** ‹ **Pages** (בתפריט משמאל).
2. תחת **Build and deployment** ‹ **Source**: בוחרים **Deploy from a branch**.
3. Branch: בוחרים **gh-pages**, ולידו **/ (root)** ‹ **Save**.
4. אחרי 1–2 דקות מופיעה כתובת: `https://fenetnet.github.io/Drivetalk/`. פותחים ומוודאים שרואים את דף DriveTalk.
5. **Settings** ‹ **Secrets and variables** ‹ **Actions** ‹ **Variables** ‹ **New repository variable**:
   - `INVITE_BASE_URL` = `https://fenetnet.github.io/Drivetalk`

> **רשות — Cloudflare Pages (אושר קודם, לא חובה):** עם Cloudflare, הקישור פותח את האפליקציה ישר, בלי ללחוץ "פתיחה באפליקציה" בדף. אפשר להוסיף את זה אחר כך. אדריך כשתרצה.

## שלב 4 — בנייה מחדש של האפליקציה

1. ב-GitHub: **Actions** ‹ משמאל **Android prototype** ‹ מימין **Run workflow**.
2. בוחרים את הענף `claude/social-voice-app-mnrxc1` ‹ **Run workflow**.
3. מחכים כ-8–10 דקות, עד שמופיע ✓ ירוק.

## שלב 5 — התקנה

1. **פעם אחת בלבד:** אם האפליקציה הישנה מותקנת, מסירים אותה. (זה בגלל המעבר לחתימה הקבועה. מכאן והלאה העדכונים יותקנו מעליה.)
2. בטלפון: https://github.com/fenetnet/Drivetalk/releases/download/prototype/drivetalk-prototype.apk ‹ פותחים ‹ מתקינים.
3. באפליקציה: **הגדרות** ‹ **בדיקה עם חבר אמיתי** (אם היא נפתחה בהדגמה) ‹ כותבים שם ‹ **יאללה**.
4. **האנשים שלי** ‹ **הזמן חבר** ‹ שולחים בוואטסאפ.
5. ממשיכים לפי `docs/two-user-test-plan.md`.

---

## אם משהו לא עובד

| מה רואים | מה לעשות |
|---|---|
| "הבדיקה עם חבר עוד לא מחוברת" | חסרים `SUPABASE_URL` או `SUPABASE_ANON_KEY` (שלב 2ד), או שלא בנית מחדש (שלב 4) |
| "בשרת עוד לא הופעלה כניסה בלי סיסמה" | שלב 2ג |
| "השרת עוד לא הוכן" | שלב 2ב: להריץ שוב את הקובץ |
| "אין חיבור לאינטרנט" אבל יש אינטרנט | פרויקט Supabase נרדם: להיכנס ל-supabase.com ‹ הפרויקט ‹ **Restore** |
| העדכון לא מותקן מעל הקודם | להסיר פעם אחת ולהתקין מחדש (שלב 5.1) |
| הקישור בהזמנה פותח דף 404 | שלב 3: Pages עוד לא הופעל, או שעוד לא עברו 2 דקות |
| כל דבר אחר | לשונית **בדיקה** ‹ **העתק מידע לבדיקה** ‹ לשלוח לי (אין בו סודות) |

## מה הבנייה עושה עם הערכים
ה-APK מקבל בזמן הבנייה את `SUPABASE_URL`, `SUPABASE_ANON_KEY` ו-`INVITE_BASE_URL` מה-Variables של GitHub. אין צורך לשנות קוד. כדי להחליף שרת, משנים את הערך ובונים מחדש.
