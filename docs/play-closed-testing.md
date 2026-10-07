# Google Play — בדיקה סגורה בלי לקבל "More testing required"

חשבון מפתח פרטי וחדש חייב לעבור **בדיקה סגורה (Closed testing)** לפני שמותר לפרסם לכולם. Google בודקת שלושה דברים:
- היו לפחות **12 בודקים**, מחוברים ברצף **14 יום**.
- הבודקים **באמת השתמשו** באפליקציה.
- המפתח **אסף משוב ועדכן** את האפליקציה בעקבותיו.

הסיבות הנפוצות לדחייה: בודקים שהצטרפו ולא פתחו את האפליקציה, אין עדכונים לאורך הבדיקה, ותשובות קצרות וכלליות בשאלון.

## לפני שמתחילים
1. **מגייסים 15–20 בודקים**, ולא 12 בדיוק. מישהו תמיד נושר, ובודק שעוזב באמצע לא נספר.
2. **קבוצות של חברים**, כמה זוגות או שלשות שמכירים זה את זה. בלי חבר באפליקציה אין הצעות לדבר, ואז אין "שימוש".
3. **כל בודק:**
   - מצטרף בקישור ההצטרפות (Join on the web) עם חשבון Gmail.
   - מתקין מהחנות.
   - **לא מסיר עד סוף 14 הימים.**
4. **אצל כל בודק בהגדרות:**
   - שגרה (למשל בוקר).
   - "לאפשר פעולה ברקע".
   - זה יוצר שימוש יומי גם בלי לזכור לפתוח.

## במהלך 14 הימים
- **לפתוח כל יום:** לפחות פעם ביום, ולסמן "יש לי זמן" לפחות כמה פעמים בשבוע.
- **משוב:** כל בודק שולח לפחות משוב אחד. באפליקציה: הגדרות ← "שליחת משוב". המשובים נשמרים ב-Supabase ← Table Editor ← `feedback_notes`.
- **2–3 עדכונים לאורך הבדיקה:** משתמשים במשוב ומעלים גרסה חדשה לאותו מסלול סגור (Closed testing ← Create new release ← הקובץ `drivetalk.aab` החדש). כל העלאה כזו נחשבת "acting on feedback".
- **מעקב:** הגדרות ← ניהול ← "מספרים" (משתמשים פעילים, הצעות, שיחות). בודק שלא נכנס כמה ימים מקבל תזכורת אישית.

## אחרי 14 יום: השאלון של Google (טיוטות באנגלית)
**How did you recruit testers?**
> Friends, family and colleagues who commute or walk daily — the people DriveTalk is for. We recruited them in small groups who already know each other, because the app connects people who are both free at the same time.

**How engaged were testers?**
> Testers opened the app daily, marked themselves available during commutes (manually and through routines), received offers to talk and placed calls. We tracked active users, offers and completed calls (aggregate numbers only) through an in-app stats screen.

**Feedback and changes made:**
> Testers sent feedback in the app ("Send feedback"). Based on it we released several updates during the test, for example: fewer read-aloud prompts while driving, choosing which contacts to add instead of automatic connections, showing contacts by the name saved on the user's phone, a 0–5 "how much I want to talk" rating, "not now — I'll get back to you", and clearer settings explanations.

**Why is the app ready for production?**
> Core flows (sign-up, adding friends, availability, mutual "yes" → regular phone call, after-call feedback) were used repeatedly by real testers without blocking issues, crash-free, and the latest updates addressed all major feedback.

**לפני שליחת השאלון:** מעדכנים את רשימת השינויים לפי מה שבאמת שונה בזמן הבדיקה.
