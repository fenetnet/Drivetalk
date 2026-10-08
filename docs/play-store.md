# Google Play — תשובות מוכנות

כל מה שצריך להעתיק ל-Play Console. התמונות נמצאות בתיקייה `store_assets/`.

## פרטי האפליקציה
- **שם:** DriveBond – לדבר עם חברים על הדרך (עד 30 תווים; שם החבילה נשאר app.drivetalk.drivetalk)
- **שפת ברירת מחדל:** עברית (he-IL)
- **אפליקציה או משחק:** אפליקציה
- **חינם או בתשלום:** חינם
- **שם החבילה ב-Google Play (נרשם ב-Play Console, לתמיד):** `app.drivetalk.drivetalk` (כמו ה-APK לבודקים). ברישום הראשון ב-Play Console נרשם בטעות `app.drietalk.drivetalk`, ולכן פותחים אפליקציה חדשה בשם הנכון.
- **קישורי הזמנה שנפתחים ישר באפליקציה:** כדי שיעבדו גם בגרסת החנות, צריך להוסיף ל-`invite_site/.well-known/assetlinks.json` את טביעת האצבע SHA-256 של מפתח החתימה של Google (Play Console ← Test and release ← App integrity). עד אז הקישור נפתח בדפדפן, ומשם "פתיחה באפליקציה" או קוד.
- **הקובץ להעלאה:** `drivetalk.aab` מדף ההורדה. הוא נבנה לבד עם כל גרסה, ומספר הגרסה עולה לבד.
- **חתימה:** "Play App Signing". Google מנהלת את מפתח החתימה, והמפתח שלנו משמש רק להעלאה.

## דף החנות
**תיאור קצר (עד 80 תווים):**
> הזמן המת שלך + הזמן המת שלהם = שיחה טובה. בלי לתאם מראש.

**תיאור מלא:**
> מתי דיברת בפעם האחרונה עם חבר טוב — סתם, בלי סיבה?
>
> כל יום אנחנו מבלים שעה בפקקים, בהליכות ובהפסקות. באותו זמן בדיוק, גם החברים שלנו. אף אחד לא מתקשר, כי "אולי הוא עסוק".
>
> DriveBond יודעת מתי שניכם פנויים — ומחברת.
>
> 🚗 בפקק? רואים מי מהחברים פנוי עכשיו: בנסיעה, בהליכה, בהפסקה — ומי בשיחה.
> 🤝 שיחה מתחילה רק כששניכם אומרים "כן". אף אחד לא מופרע.
> 📞 "כן" — והטלפון כבר מחייג, בשיחה רגילה.
> 🎙️ בנסיעה: מסך פשוט, כפתורים ענקיים, ותשובה בקול.
> ⭐ אתה מחליט עם מי: דירוג לכל חבר, ומי שלא בא לך — לא יוצע.
> 🔒 בלי פיד, בלי לייקים, בלי מיקום ובלי הקלטות. אנשי הקשר נשארים בטלפון; רק מספרים מוצפנים יוצאים ממנו.
>
> הזמן המת שלך. הזמן המת שלהם. שיחה אחת טובה.

**תמונות:**
- **אייקון:** `icon-512.png`
- **תמונה ראשית:** `feature-1024x500.png` ("מתי דיברתם בפעם האחרונה?")
- **צילומי טלפון (בסדר הזה):** `phone-1.png` … `phone-7.png`: שתי הראשונות מספרות את הרעיון, ואחריהן מסכי האפליקציה עם כותרת. המקורות ב-`store_assets/src/`. כולם להורדה ב-https://fenetnet.github.io/Drivetalk/store.html

**קטגוריה:** תקשורת (Communication).

## מדיניות פרטיות (Privacy policy)
- **הקישור:** https://fenetnet.github.io/Drivetalk/privacy.html (נבנה מ-`docs/privacy.md` ע"י `tool/privacy_page.py`).
- **מייל ליצירת קשר:** fenet.net@gmail.com (כבר בפנים). את אותו מייל שמים ב-Play Console בשדה "Contact details" ← Email.

## גישה לאפליקציה (App access)
"All functionality is available without special access". נרשמים עם שם בלבד (מספר טלפון רשות), בלי סיסמה.
כלי הניהול של הבעלים מוסתר (לחיצה ארוכה על "בדיקת עדכון"), כך שאין למשתמשים אזור מוגבל (D-082).

## פרסומות (Ads)
אין פרסומות (No).

## דירוג תוכן (Content rating)
- **קטגוריה:** Social / Communication.
- **משתמשים מתקשרים זה עם זה:** כן.
- **משתפים מיקום:** לא.
- **רכישות דיגיטליות:** לא.
- **אלימות, מין, שפה, הימורים, סמים:** לא.

## קהל יעד (Target audience)
18 ומעלה בלבד.

## בטיחות מידע (Data safety)
- **האם אוספים מידע?** כן.
- **האם משתפים מידע עם צד שלישי?** לא. מספר הטלפון נמסר לחבר רק כששניהם אישרו שיחה. זו העברה ביוזמת המשתמש, ולא "שיתוף".
- **מוצפן בהעברה:** כן (HTTPS).
- **אפשר לבקש מחיקה:** כן. באפליקציה: הגדרות ← "למחוק את החשבון והמידע שלי". הקישור לאינטרנט (Delete account URL): https://fenetnet.github.io/Drivetalk/delete.html
- **שירות השרת (Supabase):** מעבד את המידע בשבילנו, ולכן לא נחשב "שיתוף עם צד שלישי".

| סוג מידע (בטופס) | נאסף | רשות או חובה | למה |
| --- | --- | --- | --- |
| Personal info → Name | כן | חובה | App functionality, Account management |
| Personal info → User IDs | כן | חובה | App functionality, Account management (מזהה חשבון פנימי, לא שם משתמש) |
| Personal info → Phone number | כן | רשות | App functionality (חברים מוצאים זה את זה, שיחה רגילה) |
| Photos and videos → Photos | כן | רשות | App functionality (תמונת פרופיל) |
| Contacts | כן | רשות | App functionality (מספרים מוצפנים בלבד, ונשמרים רק של מי שמשתמש ב-DriveBond; שמות לא יוצאים מהטלפון) |
| App activity → App interactions | כן | חובה | App functionality, Analytics (שם פעולה ומשך בלבד; דירוג 0–5 לחברים; "פעיל לאחרונה" בימים; "בשיחה" כן/לא בזמן זמינות) |
| App activity → Other user-generated content | כן | רשות | App functionality, Fraud prevention/security (משוב ודיווח שהמשתמש כותב ושולח) |
| Device or other IDs | כן | חובה | App functionality (זמינות ברקע; נוצר לבד אחרי ההרשמה) |
| Location | לא | — | — |
| Audio | לא | — | זיהוי הדיבור נעשה בטלפון או בשירות של הטלפון. שום דבר לא נשמר אצלנו |

### בטיחות הנתונים — מסך אחרי מסך (ממשק בעברית)
1. **סקירה כללית:** "הבא".
2. **איסוף נתונים ואבטחה:**
   - האם האפליקציה אוספת או משתפת נתוני משתמשים? **כן**.
   - האם כל הנתונים מוצפנים בזמן ההעברה? **כן**.
   - איך נכנסים לחשבון: **"אחר"**. בתיבת ההסבר: `Users create an account by entering a display name only (anonymous sign-in). No password or email.`
   - קישור למחיקת חשבון: קישור מדיניות הפרטיות (סעיף "מחיקה").
   - מחיקת חלק מהנתונים בלי למחוק חשבון: **לא** (לא חובה).
3. **סוגי נתונים:** מסמנים בדיוק את השורות "כן" שבטבלה למעלה.
4. **לכל סוג נתונים** (חלון קטן לכל אחד):
   - נאסף? **כן**. משותף? **לא**.
   - מעובד זמנית בלבד (ephemeral)? **לא**.
   - חובה או רשות: לפי הטבלה.
   - מטרות: לפי הטבלה.
5. **תצוגה מקדימה** ← "שמירה".

### שאר הטפסים בדף "תוכן האפליקציה"
- **מזהה פרסום (Advertising ID):** האפליקציה לא משתמשת בו (No).
- **אפליקציות ממשלתיות, תכונות פיננסיות, אפליקציות בריאות, אפליקציות חדשות:** הכל No / "אין".
- **הרשאות שירות בחזית (Foreground service):** סוג dataSync, ההסבר והסרטון למטה.

## הרשאות מיוחדות (אם Play Console שואל)
**Foreground service (dataSync):** Google עשויה לבקש גם סרטון קצר (קישור ל-YouTube, אפשר "לא רשום" / Unlisted). מספיקה הקלטת מסך של 20–30 שניות: לוחצים "יש לי זמן", יוצאים מהאפליקציה, רואים את ההתראה הקבועה, ולוחצים "עצור".

> When the user turns on availability (the "I'm free" button, the home-screen widget, a routine they set, or the opt-in driving detection), a short foreground service checks every 10 seconds whether a friend is also free and shows a notification "X is free — talk?". It stops when the availability ends (it always has an end time) or when the user taps Stop. The notification is visible the whole time.

**Activity recognition:** זיהוי נסיעה (רשות, כבוי כברירת מחדל). בלי מיקום.

**Ignore battery optimizations (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS), אם שואלים:**
> DriveBond's core function is telling the user, while driving with the app closed, that a friend is free to talk — via a short foreground service during an availability window the user started (or opt-in driving detection). Aggressive battery optimization on many devices stops this service mid-trip, so the user is asked once, with an explanation, to exempt the app. It is only asked from users who use background availability.

**Contacts:** מוצג מסך הסבר לפני הבקשה. נקראים רק מספרים, והם מוצפנים בטלפון.

## חשוב לדעת
- **חברים שהתקינו מהקישור:** צריך להסיר את הגרסה הזו לפני ההתקנה מהחנות. החתימה של Google שונה, ולכן החנות לא יכולה לעדכן מעליה.
- **מה קורה אחרי ההסרה:** נוצר משתמש חדש. מוסיפים שוב חברים מאנשי הקשר בכמה לחיצות. דירוגים, מעגלים ו"אשמח לדבר" לא עוברים.
- **שאר הטפסים:** Government apps, Financial features, Health, News: הכל No.

## עדכונים דרך Google Play
- **מי שהתקין מהחנות:** מקבל עדכון אוטומטי (כמו כל אפליקציה) **אחרי שמעלים** את קובץ ה-AAB החדש למסלול ב-Play Console. ההעלאה עדיין ידנית: מורידים `drivetalk.aab` מדף ההורדה ← Play Console ← המסלול (פנימי או סגור) ← "יצירת גרסה חדשה" ← העלאה ← שמירה ← פרסום.
- **בדיקה של Google:** בבדיקה פנימית העדכון זמין תוך דקות עד שעות. בבדיקה סגורה ובהפצה לכולם Google בודקת כל עדכון, מכמה שעות ועד כמה ימים.
- **העלאה אוטומטית (D-084):** כל גרסה עולה לבד לבדיקה פנימית, אחרי ההגדרה החד-פעמית:
  1. ב-Google Cloud: פרויקט, הפעלת "Google Play Android Developer API", חשבון שירות ומפתח JSON.
  2. ב-Play Console ← "משתמשים והרשאות": מזמינים את המייל של חשבון השירות עם הרשאת שחרור למסלולי בדיקה.
  3. ב-GitHub ← Settings ← Secrets and variables ← Actions: סוד בשם `PLAY_SERVICE_ACCOUNT_JSON` עם כל התוכן של קובץ ה-JSON.
