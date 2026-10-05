# Google Play — תשובות מוכנות

כל מה שצריך להעתיק ל-Play Console. התמונות נמצאות בתיקייה `store_assets/`.

## פרטי האפליקציה
- **שם:** DriveTalk
- **שפת ברירת מחדל:** עברית (he-IL)
- **אפליקציה או משחק:** אפליקציה
- **חינם או בתשלום:** חינם
- **שם החבילה (נקבע לתמיד בהעלאה הראשונה):** `app.drivetalk.drivetalk`
- **הקובץ להעלאה:** `drivetalk.aab` מדף ההורדה. הוא נבנה לבד עם כל גרסה, ומספר הגרסה עולה לבד.
- **חתימה:** "Play App Signing". Google מנהלת את מפתח החתימה, והמפתח שלנו משמש רק להעלאה.

## דף החנות
**תיאור קצר (עד 80 תווים):**
> כששניכם פנויים — DriveTalk מציעה לכם לדבר. בלי לתאם מראש.

**תיאור מלא:**
> DriveTalk הופכת זמן מת — נסיעה, הליכה, הפסקה — לשיחה עם מישהו שאתם כבר מכירים.
>
> • מסמנים "יש לי זמן", ו-DriveTalk מציעה חבר שגם הוא פנוי עכשיו.
> • שיחה מתחילה רק אם שניכם אומרים כן — ואז הטלפון מחייג מיד, בשיחה רגילה.
> • בנסיעה: מסך פשוט עם כפתורים גדולים, והקראה בקול.
> • "אשמח לדבר" — סימון שקט ליד חבר, שמקדם אותו כשתהיו פנויים.
> • חברים מתחברים לבד דרך אנשי הקשר (רק מספרים מוצפנים).
>
> בלי פיד, בלי לייקים, בלי מיקום ובלי הקלטות.

**תמונות:**
- **אייקון:** `icon-512.png`
- **תמונה ראשית:** `feature-1024x500.png`
- **צילומי טלפון:** `phone-home.png`, `phone-offer.png`, `phone-people.png`, `phone-connected.png`

**קטגוריה:** תקשורת (Communication).

## מדיניות פרטיות (Privacy policy)
- **הקישור:** https://github.com/fenetnet/Drivetalk/blob/claude/social-voice-app-mnrxc1/docs/privacy.md
- **לפני ההגשה:** להוסיף כתובת מייל ליצירת קשר במקום הסוגריים.

## גישה לאפליקציה (App access)
"All functionality is available without special access". נרשמים עם שם בלבד (מספר טלפון רשות), בלי סיסמה.

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
- **אפשר לבקש מחיקה:** כן. באפליקציה: הגדרות ← "מחק את החשבון והמידע שלי". הקישור לאינטרנט: מדיניות הפרטיות.

| סוג מידע (בטופס) | נאסף | רשות או חובה | למה |
| --- | --- | --- | --- |
| Personal info → Name | כן | חובה | App functionality, Account management |
| Personal info → Phone number | כן | רשות | App functionality (חברים מוצאים זה את זה, שיחה רגילה) |
| Photos and videos → Photos | כן | רשות | App functionality (תמונת פרופיל) |
| Contacts | כן | רשות | App functionality (מספרים מוצפנים בלבד, למציאת חברים) |
| App activity → App interactions | כן | חובה | App functionality, Analytics (שם פעולה ומשך בלבד) |
| Device or other IDs | כן | רשות | App functionality (זמינות ברקע) |
| Location | לא | — | — |
| Audio | לא | — | זיהוי הדיבור נעשה בטלפון או בשירות של הטלפון. שום דבר לא נשמר אצלנו |

## הרשאות מיוחדות (אם Play Console שואל)
**Foreground service (dataSync):**
> When the user turns on availability (the "I'm free" button, the home-screen widget, a routine they set, or the opt-in driving detection), a short foreground service checks every 10 seconds whether a friend is also free and shows a notification "X is free — talk?". It stops when the availability ends (it always has an end time) or when the user taps Stop. The notification is visible the whole time.

**Activity recognition:** זיהוי נסיעה (רשות, כבוי כברירת מחדל). בלי מיקום.

**Contacts:** מוצג מסך הסבר לפני הבקשה. נקראים רק מספרים, והם מוצפנים בטלפון.

## חשוב לדעת
- **חברים שהתקינו מהקישור:** צריך להסיר את הגרסה הזו לפני ההתקנה מהחנות. החתימה של Google שונה, ולכן החנות לא יכולה לעדכן מעליה.
- **מה קורה אחרי ההסרה:** נוצר משתמש חדש. החברים מאנשי הקשר מתחברים שוב לבד, אבל מעגלים ו"אשמח לדבר" לא נשמרים.
