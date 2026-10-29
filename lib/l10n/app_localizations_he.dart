// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get tabHome => 'בית';

  @override
  String get tabSettings => 'הגדרות';

  @override
  String get onbNameLabel => 'איך קוראים לך?';

  @override
  String get homeGreetingNoName => 'שלום';

  @override
  String homeImFreeNow(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'יש לך כמה דקות לשיחה?',
      'male': 'יש לך כמה דקות לשיחה?',
      'other': 'יש לך כמה דקות לשיחה?',
    });
    return '$_temp0';
  }

  @override
  String timeLeftMinutes(int minutes) {
    return 'עוד $minutes דק׳';
  }

  @override
  String get stopAvailability => 'לעצור זמינות';

  @override
  String get modeDriving => 'נסיעה';

  @override
  String get modeWalking => 'הליכה';

  @override
  String get modeBreak => 'הפסקה';

  @override
  String get modeFree => 'סתם זמן פנוי';

  @override
  String get pickDurationTitle => 'לכמה זמן?';

  @override
  String minutesShort(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String get durationUntilTripEnds => 'לכל הנסיעה';

  @override
  String durationTripNote(int hours) {
    return 'נשאר עד $hours שעות, או עד שלוחצים \"לעצור\".';
  }

  @override
  String get tierFamiliar => 'מוכר';

  @override
  String get tierReconnect => 'לחדש קשר';

  @override
  String get tierWiden => 'להרחיב מעגל';

  @override
  String get tierSurprise => 'הפתע אותי';

  @override
  String get tierFamiliarDesc => 'חברים קרובים, משפחה ואנשים שכבר בקשר איתך';

  @override
  String get tierReconnectDesc => 'אנשים שמכירים, אבל לא דיברתם כאן הרבה זמן';

  @override
  String get tierWidenDesc => 'מכרים, קולגות וחברים של חברים';

  @override
  String get tierSurpriseDesc =>
      'הפתעה מבוקרת: חבר של חבר או קבוצה משותפת — תמיד עם הסבר';

  @override
  String get next => 'הבא';

  @override
  String get notToday => 'לא היום';

  @override
  String get doNotSuggest => 'לא להציע בתקופה הקרובה';

  @override
  String get more => 'עוד';

  @override
  String get block => 'חסימה';

  @override
  String get report => 'דיווח';

  @override
  String get unmatch => 'הסרה מהרשימה';

  @override
  String get relFamily => 'משפחה';

  @override
  String get relCloseFriend => 'חבר/ה קרוב/ה';

  @override
  String get relFriend => 'חבר/ה';

  @override
  String get relChildhoodFriend => 'חבר/ת ילדות';

  @override
  String get relColleague => 'קולגה';

  @override
  String get relFormerColleague => 'קולגה לשעבר';

  @override
  String get relAcquaintance => 'מכר/ה';

  @override
  String get relFriendOfFriend => 'חבר/ה של חברים';

  @override
  String get relSharedGroup => 'מקבוצה משותפת';

  @override
  String get relUnclassified => 'קשר';

  @override
  String get relNone => 'ללא סיווג';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ימים',
      two: 'יומיים',
      one: 'יום',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חודשים',
      two: 'חודשיים',
      one: 'חודש',
    );
    return '$_temp0';
  }

  @override
  String get durationYearPlus => 'יותר משנה';

  @override
  String get listAnd => ' ו';

  @override
  String get cancel => 'ביטול';

  @override
  String noticeBlocked(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name ברשימת החסומים',
      'male': '$name ברשימת החסומים',
      'other': '$name ברשימת החסומים',
    });
    return '$_temp0';
  }

  @override
  String get noticeReported => 'תודה, הדיווח התקבל';

  @override
  String get yes => 'כן';

  @override
  String get no => 'לא';

  @override
  String get skip => 'לדלג';

  @override
  String get driverStop => 'לעצור';

  @override
  String get driverSafety => 'בנהיגה: רק דיבורית ומתקן לרכב';

  @override
  String personUnmatchConfirm(String name) {
    return 'להסיר את $name מהרשימה? אפשר להחזיר בכל רגע ב\"אנשים שהסרתי\".';
  }

  @override
  String personBlockConfirm(String name) {
    return 'לחסום את $name? לא תוצעו זה לזה ולא תוכלו לדבר.';
  }

  @override
  String get confirm => 'אישור';

  @override
  String reportTitle(String name) {
    return 'דיווח על $name';
  }

  @override
  String get reportInappropriate => 'התנהגות לא הולמת';

  @override
  String get reportHarassment => 'הטרדה';

  @override
  String get reportSpam => 'ספאם או התחזות';

  @override
  String get reportUnderage => 'נראה מתחת לגיל 18';

  @override
  String get reportOther => 'אחר';

  @override
  String get reportAlsoBlock => 'גם לחסום';

  @override
  String get reportSend => 'שליחת דיווח';

  @override
  String get settingsDriving => 'נסיעה';

  @override
  String get enable => 'להפעיל';

  @override
  String get settingsPrivacy => 'פרטיות';

  @override
  String get unblock => 'לבטל חסימה';

  @override
  String get featCloseness => 'קרבה';

  @override
  String get featDormancy => 'זמן מאז שיחה';

  @override
  String get featAvailableNow => 'יש זמן עכשיו';

  @override
  String get featOverlap => 'חפיפת זמן';

  @override
  String get featSharedInterests => 'תחומי עניין';

  @override
  String get featSharedGroup => 'קבוצה משותפת';

  @override
  String get featMutualFriends => 'חברים משותפים';

  @override
  String get featRecentlySuggested => 'הוצע לאחרונה';

  @override
  String get featFeedback => 'פידבק קודם';

  @override
  String routineDue(String mode, int minutes) {
    return 'זה הזמן הרגיל שלך ל$mode. לסמן זמן פנוי ל-$minutes דק׳?';
  }

  @override
  String get routineStart => 'כן';

  @override
  String get availableTo => 'עם מי מתאים לדבר עכשיו?';

  @override
  String get routineAvailableTo => 'עם מי מתאים לדבר בזמן הזה?';

  @override
  String get availableToEveryone => 'כרגיל';

  @override
  String get driverListening => 'מקשיבים… אפשר לומר \"כן\" או \"לא\"';

  @override
  String get callWeAreDone => 'סיימנו';

  @override
  String get noticeMicDenied =>
      'אין הרשאת מיקרופון — עונים בכפתורים. אפשר לאשר בהגדרות הטלפון ← אפליקציות ← DriveBond ← הרשאות.';

  @override
  String get photoFromGallery => 'מהגלריה';

  @override
  String get photoFromCamera => 'צילום';

  @override
  String get photoRemove => 'הסרה';

  @override
  String get settingsVoiceReadout => 'הקראה בקול בנסיעה';

  @override
  String get settingsVoiceReadoutBody =>
      'בנסיעה הטלפון אומר בקול מי פנוי. כשהאפליקציה פתוחה עונים \"כן\" או \"לא\" בקול; אחרת — \"לדבר\" בהתראה.';

  @override
  String get routinesTitle => 'השגרה שלי';

  @override
  String routinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count זמנים קבועים',
      one: 'זמן קבוע אחד',
      zero: 'עוד לא הוגדרו זמנים קבועים',
    );
    return '$_temp0';
  }

  @override
  String get routinesEmpty => 'עוד אין זמנים קבועים';

  @override
  String get routineAdd => 'הוספת זמן קבוע';

  @override
  String get routineDelete => 'מחיקת השגרה';

  @override
  String get routineDeleteConfirm => 'למחוק את השגרה הזו?';

  @override
  String get routineDeleteGo => 'למחוק';

  @override
  String get save => 'שמירה';

  @override
  String get daySun => 'א׳';

  @override
  String get dayMon => 'ב׳';

  @override
  String get dayTue => 'ג׳';

  @override
  String get dayWed => 'ד׳';

  @override
  String get dayThu => 'ה׳';

  @override
  String get dayFri => 'ו׳';

  @override
  String get daySat => 'ש׳';

  @override
  String get realNotConfiguredTitle => 'DriveBond עוד לא מחוברת לשרת';

  @override
  String get realNotConfiguredBody =>
      'בגרסה הזו השרת עוד לא הוגדר. צריך להתקין גרסה מעודכנת.';

  @override
  String get realStarting => 'מתחברים…';

  @override
  String get realWelcomeTitle => 'בדיקה עם חבר';

  @override
  String get realPhoneLabel => 'מספר טלפון (לא חובה)';

  @override
  String get realPhoneHelp =>
      'חברים ששמרו את המספר שלך יוכלו למצוא ולהוסיף אותך, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל את המספר רק כששניכם אמרתם \"כן\".';

  @override
  String get realJoin => 'יאללה';

  @override
  String get realInviteWaitingAfterJoin =>
      'יש לך הזמנה — היא תיפתח מיד אחרי הכניסה';

  @override
  String get realTabPeople => 'האנשים שלי';

  @override
  String get realTabTest => 'בדיקה';

  @override
  String realMeAvailableTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'את פנויה לשיחה',
      'male': 'אתה פנוי לשיחה',
      'other': 'יש לך זמן לשיחה',
    });
    return '$_temp0';
  }

  @override
  String get realFreeFriendsTitle => 'עכשיו';

  @override
  String get realNobodyFree =>
      'כרגע אף חבר לא פנוי. כשמישהו יסמן שיש לו זמן, הוא יופיע כאן.';

  @override
  String get realFreeHint =>
      'רוצים לדבר עם מישהו פנוי? לוחצים עליו, ונשאל אם מתאים לו עכשיו.';

  @override
  String get realNobodyFreeYet => 'נעדכן ברגע שמישהו מתאים יתפנה.';

  @override
  String get realNoFriendsTitle => 'עוד אין פה חברים';

  @override
  String get realNoFriendsBody =>
      'אפשר להזמין חבר — וכששניכם פנויים, נציע לכם לדבר.';

  @override
  String get realInviteFriend => 'להזמין חבר';

  @override
  String get realHaveCode => 'יש לי קוד הזמנה';

  @override
  String get realCodeHint => 'הדביקו כאן את הקישור או הקוד';

  @override
  String get realCodeInvalid => 'לא מצאנו קוד הזמנה בטקסט הזה';

  @override
  String get realOpen => 'פתיחה';

  @override
  String get realInviteMessage =>
      'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond. כששנינו פנויים היא פשוט מציעה לנו לדבר.';

  @override
  String realInviteMessageNoSite(String apkUrl, String code) {
    return 'להורדה: $apkUrl\nואז באפליקציה: האנשים שלי ← יש לי קוד הזמנה ← $code';
  }

  @override
  String get realInviteShareSubject => 'הזמנה ל-DriveBond';

  @override
  String get realInviteCopied => 'ההזמנה הועתקה — אפשר להדביק בוואטסאפ';

  @override
  String realOfferTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name פנויה עכשיו. רוצה לדבר?',
      'male': '$name פנוי עכשיו. רוצה לדבר?',
      'other': 'ל$name יש זמן עכשיו. רוצה לדבר?',
    });
    return '$_temp0';
  }

  @override
  String get realTalkNow => 'לדבר עכשיו';

  @override
  String get realNotNow => 'לא עכשיו';

  @override
  String get realOfferNote => 'השיחה תתחיל רק אם שניכם אומרים כן';

  @override
  String realWaitingTitle(String name) {
    return 'מחכים ל$name…';
  }

  @override
  String realWaitingBody(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'ברגע ש$name תאשר — מתחברים.',
      'male': 'ברגע ש$name יאשר — מתחברים.',
      'other': 'ברגע שתגיע תשובה מ$name — מתחברים.',
    });
    return '$_temp0';
  }

  @override
  String get realStopWaiting => 'לא לחכות';

  @override
  String get realDidNotWorkOut => 'לא הסתדר הפעם. נחפש הזדמנות אחרת.';

  @override
  String get routinesExplain =>
      'זמנים קבועים שבהם הזמינות נדלקת לבד, למשל הנסיעה לעבודה.';

  @override
  String get realBlockedBody =>
      'אנשים שחסמת לא יוצעו לך, והם לא יראו מתי יש לך זמן.';

  @override
  String get settingsPrivacyBody =>
      'מה נשמר ומה לא. אפשר גם למחוק מהשרת את מה שסונכרן מאנשי הקשר.';

  @override
  String get realNoAnswer => 'אין תשובה כרגע. נציע שוב בהזדמנות אחרת.';

  @override
  String get realVoiceDidNotWorkOut => 'לא הסתדר הפעם.';

  @override
  String realVoiceTheyCall(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name מתקשרת אליך.',
      'male': '$name מתקשר אליך.',
      'other': 'שיחה מ$name מגיעה.',
    });
    return '$_temp0';
  }

  @override
  String realQuickConnecting(String name) {
    return 'מתחברים ל$name…';
  }

  @override
  String get realQuickConnectingBody => 'חיבור מהיר — אפשר לבטל';

  @override
  String realQuickSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'עוד $seconds שניות — אפשר לבטל',
      one: 'עוד שנייה — אפשר לבטל',
    );
    return '$_temp0';
  }

  @override
  String get realQuickCancelled => 'החיבור בוטל';

  @override
  String get realQuickTooLate => 'כבר מאוחר לבטל — השיחה מתחילה';

  @override
  String get widgetTip =>
      'אפשר לסמן \"יש לי זמן\" בלחיצה אחת, בלי לפתוח את האפליקציה: לחיצה ארוכה על מסך הבית ← ווידג\'טים ← DriveBond.';

  @override
  String get gotIt => 'הבנתי';

  @override
  String get realContactsAgain => 'חיפוש שוב באנשי הקשר';

  @override
  String get settingsGeneral => 'כללי';

  @override
  String get adminTitle => 'ניהול';

  @override
  String get adminCode => 'קוד';

  @override
  String get adminWrong => 'קוד שגוי';

  @override
  String get adminLock => 'לסגור את הניהול';

  @override
  String get updateAvailable => 'יש גרסה חדשה של DriveBond';

  @override
  String get updateNow => 'לעדכן';

  @override
  String get updateCheck => 'בדיקת עדכון';

  @override
  String get updateCurrent => 'הגרסה שלך:';

  @override
  String get updateNone => 'יש לך את הגרסה האחרונה';

  @override
  String get updateHow => 'מורידים, לוחצים על הקובץ ← \"עדכון\". הכול נשמר.';

  @override
  String get updateHowStore => 'מעדכנים בגוגל פליי. החברים וההגדרות נשמרים.';

  @override
  String get realBgFailedTitle => 'לא הצלחנו להדליק זמינות ברקע';

  @override
  String get realBgFailedBody =>
      'הטלפון חסם את זה. פותחים את DriveBond ובוחרים שוב מה עושים עכשיו.';

  @override
  String routineHint(String day, String time) {
    return 'נראה שבימי $day סביב $time יש לך בדרך כלל זמן. להפעיל זמינות אוטומטית בזמן הזה?';
  }

  @override
  String get routineHintYes => 'להפעיל';

  @override
  String get routineHintNo => 'לא, תודה';

  @override
  String get realStatusServerVersion => 'גרסת השרת';

  @override
  String realServerOutdated(int have, int need) {
    return 'השרת צריך עדכון: בשרת $have, נדרש $need';
  }

  @override
  String get realClearContacts => 'למחוק מידע שסונכרן מאנשי הקשר';

  @override
  String get realDeleteAccount => 'למחוק את החשבון והמידע שלי';

  @override
  String get realDeleteAccountConfirm =>
      'הכול נמחק מהשרת: שם, מספר, חברים, קבוצות ותמונה. אי אפשר לבטל.';

  @override
  String get realDeleteAccountGo => 'למחוק';

  @override
  String get realDeleteAccountDone => 'החשבון והמידע נמחקו';

  @override
  String get realNotifPublic => 'יש הצעה חדשה ב-DriveBond';

  @override
  String get firstRunContactsTitle => 'נראה מי מהאנשים שלך כבר כאן';

  @override
  String get firstRunContactsBody =>
      'רק מספרים, מוצפנים. שמות לא יוצאים מהטלפון.';

  @override
  String get firstRunContactsGo => 'לחפש באנשי הקשר';

  @override
  String firstRunFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מצאנו $count אנשים מאנשי הקשר',
      one: 'מצאנו אדם אחד מאנשי הקשר',
    );
    return '$_temp0';
  }

  @override
  String get firstRunNoneTitle => 'כדי לנסות את DriveBond צריך לפחות חבר אחד';

  @override
  String get firstRunNoneBody =>
      'שולחים קישור למישהו שאוהבים לדבר איתו. אחרי ההתקנה, אחד מכם מוסיף את השני: האנשים שלי ← חיפוש באנשי הקשר.';

  @override
  String get firstRunLater => 'אחר כך';

  @override
  String get firstRunMagicTitle => 'ככה זה עובד';

  @override
  String get firstRunMagicBody =>
      'כששניכם פנויים, DriveBond מציעה לכם לדבר. לא צריך לתאם מראש.';

  @override
  String get firstRunMagicGo => 'יאללה';

  @override
  String get routineNameToWork => 'בדרך לעבודה';

  @override
  String get routineNameHome => 'בדרך הביתה';

  @override
  String get routineNameWalk => 'הליכת ערב';

  @override
  String get routineNameBreak => 'הפסקת צהריים';

  @override
  String get routineEveryone => 'כולם';

  @override
  String realCallingNow(String name) {
    return 'מתקשרים ל$name…';
  }

  @override
  String get realDialedBody => 'כשהשיחה נגמרת, חוזרים לכאן.';

  @override
  String realTheyCallTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name מתקשרת אליך עכשיו',
      'male': '$name מתקשר אליך עכשיו',
      'other': 'שיחה מ$name מגיעה עכשיו',
    });
    return '$_temp0';
  }

  @override
  String get realTheyCallBody =>
      'הטלפון יצלצל עוד רגע. אם השיחה לא מגיעה תוך דקה — \"לא הגיעה שיחה\".';

  @override
  String get realTheyDidNotCall => 'לא הגיעה שיחה';

  @override
  String get realNoNumbersTitle => 'אי אפשר להתקשר הפעם';

  @override
  String get realNoNumbersBody =>
      'לשניכם אין מספר טלפון באפליקציה. כדי לדבר, אחד מכם מוסיף מספר: הגדרות ← לחיצה על השם ← \"המספר שלי לשיחה רגילה\".';

  @override
  String get realDialFailedTitle => 'לא הצלחנו לפתוח את החייגן';

  @override
  String realDialFailedBody(String name) {
    return 'אפשר להתקשר ל$name ידנית.';
  }

  @override
  String get realFeedbackThanks => 'תודה!';

  @override
  String realConnected(String name) {
    return 'מעולה! $name עכשיו ברשימת האנשים שלך.';
  }

  @override
  String realInviteTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name הזמינה אותך',
      'male': '$name הזמין אותך',
      'other': 'הזמנה מ$name',
    });
    return '$_temp0';
  }

  @override
  String get realInviteBody =>
      'כששניכם פנויים — נציע לכם לדבר. רק אם שניכם מסכימים.';

  @override
  String get realInviteAccept => 'אישור';

  @override
  String get realInviteLoading => 'בודקים את ההזמנה…';

  @override
  String get realInviteProblemUsed => 'ההזמנה הזו כבר נוצלה. צריך הזמנה חדשה.';

  @override
  String get realInviteProblemExpired => 'פג תוקף ההזמנה. צריך הזמנה חדשה.';

  @override
  String get realInviteProblemOwn =>
      'זו הזמנה ששלחת בעצמך 🙂 אפשר לשלוח אותה לחבר.';

  @override
  String get realInviteProblemNotFound =>
      'לא מצאנו את ההזמנה. בדקו שהקישור הועתק במלואו.';

  @override
  String realInviteAlready(String name) {
    return '$name כבר ברשימת האנשים שלך.';
  }

  @override
  String get realErrorOffline => 'אין חיבור לאינטרנט. ננסה שוב לבד.';

  @override
  String realErrorGeneric(String code) {
    return 'משהו השתבש ($code). אפשר לנסות שוב.';
  }

  @override
  String get realErrorAnonymousDisabled =>
      'בשרת עוד לא הופעלה כניסה בלי סיסמה (Anonymous sign-ins).';

  @override
  String get realErrorSchema => 'השרת עוד לא מוכן. אפשר לנסות שוב מאוחר יותר.';

  @override
  String get realErrorInvalidPhone => 'מספר הטלפון לא נראה תקין';

  @override
  String get realErrorInvalidName => 'השם צריך להיות באורך 1–40 תווים';

  @override
  String get realErrorRateLimited =>
      'יותר מדי ניסיונות. אפשר לנסות שוב בעוד כמה דקות.';

  @override
  String get realErrorTooManyInvites =>
      'יש כבר הרבה הזמנות פתוחות. אפשר לנסות שוב מחר.';

  @override
  String get realSaved => 'נשמר';

  @override
  String get realDialFailed => 'לא הצלחנו לפתוח את החייגן. אפשר להתקשר ידנית.';

  @override
  String realUnmatched(String name) {
    return 'הקשר עם $name הוסר';
  }

  @override
  String get realNotFree => 'אין זמינות כרגע';

  @override
  String get realTestIntro =>
      'כאן רואים שהכול עובד. אם משהו לא עובד — \"להעתיק מידע לבדיקה\" ושולחים לי.';

  @override
  String get realTestSteps =>
      '1. להזמין חבר\n2. שניכם: בוחרים מה עושים עכשיו (למשל \"סתם זמן פנוי\")\n3. שניכם: \"לדבר עכשיו\"';

  @override
  String get realStatusServer => 'שרת';

  @override
  String get realStatusAccount => 'חשבון';

  @override
  String get realStatusLive => 'עדכון מיידי';

  @override
  String get realStatusFriends => 'חברים';

  @override
  String get realStatusMe => 'הזמינות שלי';

  @override
  String get realStatusFreeFriends => 'חברים פנויים עכשיו';

  @override
  String get realStatusLastOffer => 'הצעה אחרונה';

  @override
  String get realStatusVersion => 'גרסה';

  @override
  String get realStatusLastError => 'שגיאה אחרונה';

  @override
  String get realStatusPhone => 'מספר לשיחה רגילה';

  @override
  String get realOk => 'תקין';

  @override
  String get realNotConnected => 'לא מחובר';

  @override
  String get realLiveError => 'לא יציב — מתעדכן כל כמה שניות';

  @override
  String get realNone => 'אין';

  @override
  String get realShared => 'משותף';

  @override
  String get realNotShared => 'אין מספר · להוסיף';

  @override
  String get realMeNotAvailable => 'אין זמינות';

  @override
  String get realOfferPending => 'מחכה לתשובה';

  @override
  String get realOfferAccepted => 'שניכם אמרתם כן';

  @override
  String get realOfferDeclined => 'לא הסתדר';

  @override
  String get realOfferExpired => 'פג הזמן';

  @override
  String get realOfferCancelled => 'בוטל';

  @override
  String get realCopyDiagnostics => 'להעתיק מידע לבדיקה';

  @override
  String get realCopied => 'הועתק. אפשר להדביק ולשלוח';

  @override
  String get realRefresh => 'רענון';

  @override
  String get realTestModeToggle => 'מסך בדיקה (Test Mode)';

  @override
  String get realTestModeBody => 'מציג את הלשונית \"בדיקה\" עם מצב החיבור';

  @override
  String get realMyNumber => 'המספר שלי לשיחה רגילה';

  @override
  String get realStartOver => 'להתחיל מחדש כמשתמש חדש';

  @override
  String get realStartOverConfirm =>
      'החברים וההזמנות של המשתמש הנוכחי לא יעברו. להמשיך?';

  @override
  String get realDownloadLink => 'קישור להורדת האפליקציה';

  @override
  String get realShareApp => 'שיתוף';

  @override
  String get realNameTitle => 'השם שלי';

  @override
  String get realPhotoTitle => 'התמונה שלי';

  @override
  String get realPhotoSaved => 'התמונה נשמרה';

  @override
  String get realPhotoRemoved => 'התמונה הוסרה';

  @override
  String get realPrivacyNote =>
      'בלי מיקום ובלי הקלטות. בשרת נשמר רק מה שהאפליקציה צריכה: שם, מספר ותמונה (אם הוספת), החברים שלך ומתי יש לך זמן. הפירוט המלא במדיניות הפרטיות.';

  @override
  String realVoiceOffer(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name פנויה. לדבר?',
      'male': '$name פנוי. לדבר?',
      'other': 'ל$name יש זמן. לדבר?',
    });
    return '$_temp0';
  }

  @override
  String realVoiceCalling(String name) {
    return 'מתקשרים ל$name.';
  }

  @override
  String get realNotifChannelStatus => 'זמינות בנסיעה';

  @override
  String get realNotifChannelOffers => 'חבר פנוי לשיחה';

  @override
  String get realNotifStatusTitle => 'DriveBond · זמינות לשיחה בנסיעה';

  @override
  String get realNotifStatusBody => 'נסיעה טובה! נודיע כשחבר פנוי.';

  @override
  String get realAutoDriving => 'זמינות אוטומטית בנסיעה';

  @override
  String get realAutoDrivingBody =>
      'כשהטלפון מזהה שהוא ברכב, החברים יכולים לקבל הצעה לדבר איתך. נכבה לבד בסוף הנסיעה. בלי GPS ובלי מיקום.';

  @override
  String get realAutoDrivingUnsupported => 'לא זמין במכשיר הזה';

  @override
  String get realAutoDrivingDialogTitle => 'זמינות אוטומטית בנסיעה';

  @override
  String get realAutoDrivingDialogBody =>
      'הטלפון מזהה נסיעה לבד (בלי GPS) ומסמן שיש לך זמן עד סוף הנסיעה.\n\nשיחה מתחילה רק אם שניכם אומרים כן (או בחיבור מהיר ששניכם הפעלתם).\n\nיתבקשו הרשאות \"פעילות גופנית\" והתראות.';

  @override
  String get realAutoDrivingOn => 'מעולה. בנסיעה הבאה הזמינות תידלק לבד.';

  @override
  String get realAutoDrivingOff => 'זמינות אוטומטית בנסיעה כובתה';

  @override
  String get realAutoDrivingNoPermission =>
      'צריך הרשאת \"פעילות גופנית\": הגדרות הטלפון ← אפליקציות ← DriveBond ← הרשאות.';

  @override
  String get realAutoDrivingFailed =>
      'לא הצלחנו להפעיל זיהוי נסיעה. אפשר לנסות שוב.';

  @override
  String get realStatusAutoDriving => 'זיהוי נסיעה';

  @override
  String get realAutoOn => 'פעיל';

  @override
  String get realAutoOff => 'כבוי';

  @override
  String get realInVehicleNow => 'ברכב עכשיו';

  @override
  String get realSimEnter => 'דמה: נכנסתי לרכב';

  @override
  String get realSimExit => 'דמה: יצאתי מהרכב';

  @override
  String realVoiceQuick(String name) {
    return 'מתחברים ל$name. אפשר לבטל בכפתור.';
  }

  @override
  String realUnblocked(String name) {
    return 'החסימה של $name בוטלה';
  }

  @override
  String realUnblockedBack(String name) {
    return 'החסימה של $name בוטלה — $name שוב ברשימה שלך';
  }

  @override
  String get realBlockedTitle => 'חסומים';

  @override
  String get realBlockedEmpty => 'לא חסמת אף אחד';

  @override
  String get realUnblock => 'ביטול חסימה';

  @override
  String get realCirclesTitle => 'קבוצות';

  @override
  String get realCirclesIntro =>
      'קבוצה היא כמה חברים יחד, למשל משפחה או עבודה. כשיש לך זמן, בוחרים \"זמין ל…\": רק לקבוצות מסוימות, או לכולם חוץ מקבוצות מסוימות.';

  @override
  String get circleSeesAll => 'רואים שיש לך זמן: בכל מצב';

  @override
  String circleSeesSome(String modes) {
    return 'רואים שיש לך זמן: $modes';
  }

  @override
  String get circleSeesNone => 'מוסתר מהקבוצה שיש לך זמן';

  @override
  String get circleRuleQuestion => 'מתי חברי הקבוצה יראו שיש לך זמן?';

  @override
  String get modeInDriving => 'בנסיעה';

  @override
  String get modeInWalking => 'בהליכה';

  @override
  String get modeInBreak => 'בהפסקה';

  @override
  String get modeInFree => 'בזמן פנוי';

  @override
  String get realCircleNew => 'קבוצה חדשה';

  @override
  String get realCircleName => 'שם הקבוצה (למשל: שכנים)';

  @override
  String get realCircleMembers => 'מי בקבוצה';

  @override
  String realCircleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים',
      one: 'אדם אחד',
      zero: 'עוד אין אנשים',
    );
    return '$_temp0';
  }

  @override
  String get realCircleDelete => 'מחיקת הקבוצה';

  @override
  String get realCircleNoFriends => 'קודם צריך להזמין חברים';

  @override
  String get circleFamily => 'משפחה';

  @override
  String get circleFriends => 'חברים';

  @override
  String get circleWork => 'עבודה';

  @override
  String get whoSeesTitle => 'מי רואה שיש לי זמן';

  @override
  String get whoSeesSubtitle => 'קבוצות: מי רואה, ומתי';

  @override
  String get whoSeesTwo => 'מי שנמצא בשתי קבוצות רואה רק אם שתיהן מרשות.';

  @override
  String get whoSeesOthers => 'כל השאר (חברים שלא בשום קבוצה)';

  @override
  String get showAlways => 'תמיד';

  @override
  String get showNever => 'אף פעם';

  @override
  String get showOnly => 'רק במצבים שמסומנים:';

  @override
  String showOnlyModes(String modes) {
    return 'רק: $modes';
  }

  @override
  String get friendCirclesTitle => 'קבוצות';

  @override
  String get friendCirclesBody => 'הקבוצה קובעת אם רואים שאפשר לדבר איתך.';

  @override
  String get hiddenUnhide => 'לבטל את ההסתרה';

  @override
  String get homeWhatNow => 'בוחרים מה עושים עכשיו, ונמצא חבר שגם פנוי לדבר';

  @override
  String get permIntroTitle => 'רגע לפני';

  @override
  String get permIntroBody =>
      'כדי שהשיחה תתחיל מיד כששניכם אומרים \"כן\", ושנוכל להודיע כשחבר מתפנה, הטלפון ישאל כמה שאלות:\n\n• שיחות טלפון — כדי לחייג בלחיצה אחת.\n• התראות — כדי להודיע גם כשהאפליקציה סגורה.\n• מיקרופון (בנסיעה) — כדי לענות \"כן\" או \"לא\" בקול. שום דבר לא מוקלט.';

  @override
  String get permIntroGo => 'הבנתי, ממשיכים';

  @override
  String get realPhoneRequired => 'מספר טלפון';

  @override
  String get realPhoneRequiredHelp =>
      'צריך את המספר כדי שחברים ששמרו אותו ימצאו אותך, וכדי שהשיחה תהיה שיחת טלפון רגילה. החבר מקבל את המספר רק כששניכם אמרתם \"כן\".';

  @override
  String get realContactsTitle => 'חברים מאנשי הקשר';

  @override
  String get realContactsBody =>
      'מוצאים מי מאנשי הקשר כבר כאן, ובוחרים את מי להוסיף. לא צריך את המספר שלך.';

  @override
  String get realContactsButton => 'חיפוש באנשי הקשר';

  @override
  String realContactsFound(String names) {
    return '$names — עכשיו ברשימה שלך';
  }

  @override
  String get realContactsNone =>
      'עוד אין כאן מאנשי הקשר שלך. אפשר להזמין עם קישור.';

  @override
  String get realContactsNoPermission =>
      'בלי הרשאה לאנשי קשר — אפשר להזמין עם קישור.';

  @override
  String get realNotifManualTitle => 'DriveBond · זמינות לשיחה';

  @override
  String get realNotifManualBody => 'נודיע כשחבר פנוי — גם כשהאפליקציה סגורה.';

  @override
  String realOfferName(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name פנויה עכשיו',
      'male': '$name פנוי עכשיו',
      'other': 'ל$name יש זמן עכשיו',
    });
    return '$_temp0';
  }

  @override
  String get realOfferAsk => 'רוצה לדבר?';

  @override
  String realOfferAskShort(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'פנויה. לדבר?',
      'male': 'פנוי. לדבר?',
      'other': 'יש זמן. לדבר?',
    });
    return '$_temp0';
  }

  @override
  String get realGreetMorning => 'בוקר טוב';

  @override
  String get realGreetNoon => 'צהריים טובים';

  @override
  String get realGreetEvening => 'ערב טוב';

  @override
  String get realGreetNight => 'לילה טוב';

  @override
  String realHomeTitle(String name) {
    return '$name, עם מי\nמדברים היום?';
  }

  @override
  String realFreeCount(int count) {
    return 'יש זמן: $count';
  }

  @override
  String get realGroupAccount => 'החשבון שלי';

  @override
  String get realWelcomeHeadline => 'הזמן בדרך –\nעם האנשים שלך.';

  @override
  String get realWelcomeSub => 'כששניכם פנויים באותו רגע — נציע לכם לדבר.';

  @override
  String realInviteSimple(String apkUrl, String guideUrl) {
    return 'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה: $apkUrl\nעזרה בהתקנה: $guideUrl';
  }

  @override
  String get realQuickOff => 'יש לי זמן';

  @override
  String get realQuickOn => 'יש לי זמן · לעצירה';

  @override
  String get realCarTitle => 'הרכבים שלי (בלוטות׳)';

  @override
  String get realCarBody =>
      'כשהטלפון מתחבר לבלוטות׳ של הרכב, זה סימן שהנסיעה התחילה. עוזר לזהות נסיעה מהר יותר.';

  @override
  String get realCarPick => 'בחירת הרכבים';

  @override
  String get realCarNoDevices =>
      'לא נמצאו מכשירי בלוטות׳ מחוברים. חברו את הטלפון לרכב פעם אחת ונסו שוב.';

  @override
  String get realWeekTitle => 'השבוע שלך';

  @override
  String realWeekTalks(int talks) {
    String _temp0 = intl.Intl.pluralLogic(
      talks,
      locale: localeName,
      other: '$talks שיחות',
      one: 'שיחה אחת',
      zero: 'עוד אין שיחות השבוע',
    );
    return '$_temp0';
  }

  @override
  String realWeekFriends(int friends) {
    String _temp0 = intl.Intl.pluralLogic(
      friends,
      locale: localeName,
      other: 'עם $friends חברים',
      one: 'עם חבר אחד',
    );
    return '$_temp0';
  }

  @override
  String get realRoutinesIntro =>
      'בזמנים האלה הזמינות נדלקת לבד, גם כשהאפליקציה סגורה.';

  @override
  String get realRoutineNotifTitle => 'DriveBond · השגרה שלך';

  @override
  String get realRoutineNotifBody =>
      'הזמינות לשיחה נדלקה. \"לעצור\" בהתראה מבטל.';

  @override
  String get done => 'סיום';

  @override
  String get ratingNever => 'לא להציע';

  @override
  String ratingLabel(int rating) {
    return 'דירוג $rating מתוך 5';
  }

  @override
  String get ratingTitle => 'כמה בא לי לדבר?';

  @override
  String get ratingHelp => '0 = לא להציע בכלל · 5 = הכי חשוב. רק לך זה מוצג.';

  @override
  String get contactsPickTitle => 'מאנשי הקשר שלך כבר כאן';

  @override
  String get contactsPickBody =>
      'בוחרים רק את מי שבא לדבר איתו. מי שלא נבחר לא יודע על זה.';

  @override
  String get contactsAdd => 'להוסיף';

  @override
  String get contactsNo => 'לא';

  @override
  String newContactTitle(String name) {
    return '$name מאנשי הקשר שלך כבר כאן';
  }

  @override
  String get newContactBody => 'להוסיף לאנשים שלי?';

  @override
  String get hiddenNote =>
      'המצב שלך מוסתר, ולכן גם לא רואים כאן מי פנוי. הצעות לדבר ממשיכות.';

  @override
  String get realLaterButton => 'עכשיו לא, אבל אשמח בהמשך';

  @override
  String realLaterNote(String name) {
    return 'מ$name: עכשיו לא מתאים, אולי אחר כך.';
  }

  @override
  String get backgroundTitle => 'לא לפספס אף שיחה';

  @override
  String get backgroundBody =>
      'כך נוכל להודיע לך ברגע שחבר מתפנה, ולזהות נסיעה, גם כשהאפליקציה סגורה. ברקע היא עובדת רק כשסימנת שיש לך זמן או בזמן נסיעה.';

  @override
  String get backgroundAllow => 'להפעיל';

  @override
  String get addNumberTitle => 'שחברים ימצאו אותך';

  @override
  String get addNumberBody =>
      'בלי מספר טלפון חברים לא ימצאו אותך באנשי הקשר, ואי אפשר להתקשר אליך בשיחה רגילה. המספר נמסר לחבר רק אחרי ששניכם אמרתם \"כן\".';

  @override
  String get addNumberGo => 'להוסיף מספר';

  @override
  String newFriendTitle(String name) {
    return 'חדש ברשימה שלך: $name';
  }

  @override
  String get newFriendBody =>
      'התחברתם — מאנשי הקשר או מהזמנה. מעכשיו תוכלו לקבל הצעה לדבר כששניכם פנויים.';

  @override
  String get newFriendGroup => 'לבחור קבוצה';

  @override
  String get newFriendOk => 'מעולה';

  @override
  String get notNowShort => 'לא עכשיו';

  @override
  String get firstRunRoutineTitle => 'באילו שעות יש לך בדרך כלל נסיעה?';

  @override
  String get firstRunRoutineBody =>
      'מסמנים שעה אחת או יותר. בימים א׳–ה׳, בשעה הזו, נסמן שיש לך זמן — לחצי שעה. את השעה משנים בלחיצה על העיפרון, ואפשר לשנות הכול גם בהגדרות ← השגרה שלי.';

  @override
  String firstRunRoutineMorning(String time) {
    return 'בוקר · $time · בדרך לעבודה';
  }

  @override
  String firstRunRoutineEvening(String time) {
    return 'ערב · $time · בדרך הביתה';
  }

  @override
  String get firstRunRoutineNone => 'לא קבוע';

  @override
  String get statsTitle => 'מספרים';

  @override
  String get statsFailed =>
      'לא הצלחנו לטעון. אם זה חוזר, צריך להכניס שוב את קוד הניהול (לחיצה ארוכה על \"בדיקת עדכון\").';

  @override
  String get statsWeek => '7 ימים';

  @override
  String get statsMonth => '30 ימים';

  @override
  String get statsUsers => 'אנשים באפליקציה';

  @override
  String get statsNewUsers => 'הצטרפו';

  @override
  String get statsActiveUsers => 'נכנסו לאפליקציה';

  @override
  String get statsFriendships => 'חברויות';

  @override
  String get statsFreeTimes => '\"יש לי זמן\"';

  @override
  String get statsOffers => 'הצעות לדבר';

  @override
  String get statsQuick => 'חיבורים מהירים';

  @override
  String get statsBothYes => 'שניהם אמרו כן';

  @override
  String get statsTalked => 'דיברו בפועל';

  @override
  String get statsDeclined => '\"לא עכשיו\"';

  @override
  String get statsLater => '\"אחזור אליך\"';

  @override
  String get statsNoAnswer => 'בלי תשובה';

  @override
  String get statsDialMs => 'כמה מהר מתחיל החיוג';

  @override
  String get statsSeconds => 'שנ׳';

  @override
  String get statsNote =>
      'רק סכומים. בלי שמות, בלי מספרים, ובלי שום מידע על אדם מסוים.';

  @override
  String get statsReports => 'דיווחים';

  @override
  String realInviteStore(String url) {
    return 'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה מ-Google Play: $url';
  }

  @override
  String inactiveDays(int days) {
    return 'בלי כניסה כבר $days ימים';
  }

  @override
  String get inactiveMonth => 'בלי כניסה יותר מחודש';

  @override
  String get feedbackTitle => 'שליחת משוב';

  @override
  String get feedbackBody => 'משהו לא עובד? רעיון? זה מגיע ישר אלינו.';

  @override
  String get feedbackHint => 'מה כדאי לשפר?';

  @override
  String get feedbackSend => 'לשלוח';

  @override
  String get statsFeedback => 'משובים';

  @override
  String get statsReportsTitle => 'דיווחים אחרונים';

  @override
  String get statsFeedbackTitle => 'משובים אחרונים';

  @override
  String get statsNotesEmpty => 'עוד אין כאן כלום';

  @override
  String get statsNotesFailed =>
      'אין גישה. צריך להכניס שוב את קוד הניהול: הגדרות ← לחיצה ארוכה על \"בדיקת עדכון\".';

  @override
  String get firstRunRoutineChangeTime => 'לשנות שעה';

  @override
  String get inCall => 'בשיחה';

  @override
  String get close => 'סגירה';

  @override
  String get firstRunPhotoTitle => 'תמונה, כדי שיזהו אותך';

  @override
  String get firstRunPhotoBody => 'רשות. רק החברים שלך רואים אותה.';

  @override
  String get firstRunPhotoGo => 'לבחור תמונה';

  @override
  String get firstRunPhotoLater =>
      'אפשר להוסיף או להחליף בכל זמן: הגדרות ← לחיצה על השם שלך ← \"התמונה שלי\".';

  @override
  String peopleAsleepTitle(int count) {
    return 'לא פתחו את האפליקציה חודש ($count)';
  }

  @override
  String get peopleAsleepBody => 'חוזרים לרשימה לבד כשהם פותחים שוב.';

  @override
  String get removedTitle => 'אנשים שהסרתי';

  @override
  String get removedBody => 'אפשר להחזיר — וחוזרים להיות חברים מיד.';

  @override
  String get removedEmpty => 'לא הסרת אף אחד.';

  @override
  String get removedRestore => 'להחזיר';

  @override
  String get statsUsersHint => 'כל מי שנרשם אי פעם (אדם אחד לכל מספר טלפון)';

  @override
  String get statsNewUsersHint => 'נרשמו לראשונה בתקופה הזו';

  @override
  String get statsActiveUsersHint => 'פתחו אותה לפחות פעם אחת בתקופה';

  @override
  String get statsFriendshipsHint =>
      'כמה זוגות חברים מחוברים באפליקציה (בסך הכול)';

  @override
  String get statsFreeTimesHint => 'כמה פעמים מישהו סימן שהוא פנוי';

  @override
  String get statsOffersHint => 'כמה פעמים הצענו לשני חברים פנויים לדבר';

  @override
  String get statsQuickHint =>
      'שיחות שהתחילו בלי לשאול (שני הצדדים הסכימו מראש)';

  @override
  String get statsBothYesHint => 'הצעות שהפכו לשיחה';

  @override
  String get statsTalkedHint => 'לפי מה שענו אחרי השיחה';

  @override
  String get statsDeclinedHint => 'אחד הצדדים סירב להצעה';

  @override
  String get statsLaterHint => 'מתוך ה\"לא עכשיו\"';

  @override
  String get statsNoAnswerHint => 'אף אחד לא ענה בזמן';

  @override
  String get statsReportsHint => 'דיווחים על משתמשים. לחיצה לפרטים';

  @override
  String get statsFeedbackHint =>
      'הודעות שנשלחו אליך מתוך האפליקציה. לחיצה לפרטים';

  @override
  String get statsCrashes => 'קריסות';

  @override
  String get statsCrashesHint =>
      'תקלות שהאפליקציה דיווחה עליהן לבד. לחיצה לפרטים';

  @override
  String get statsDialMsHint => 'מה\"כן\" השני ועד שהטלפון מחייג (בדרך כלל)';

  @override
  String get statsCrashesTitle => 'קריסות אחרונות';

  @override
  String askTitle(String name) {
    return 'לדבר עם $name עכשיו?';
  }

  @override
  String get askBody => 'נשאל אם מתאים עכשיו. אם כן, מתחילים לדבר.';

  @override
  String get askBodyNotFree =>
      'נסמן שגם לך יש זמן (30 דקות), ונשאל אם מתאים עכשיו.';

  @override
  String get askYes => 'כן, לשאול';

  @override
  String askNotFree(String name) {
    return 'נראה של$name כבר אין זמן כרגע.';
  }

  @override
  String askBusy(String name) {
    return 'ל$name לא מתאים ממש עכשיו. נציע כשיתאים.';
  }

  @override
  String askNotNow(String name) {
    return 'כבר שאלנו את $name הפעם. נחכה לפעם הבאה.';
  }

  @override
  String askCallOpen(String name) {
    return 'השיחה האחרונה שלך עם $name עוד לא נסגרה. ברגע שאחד מכם עונה \"איך היה?\" או שהשיחה מתנתקת, אפשר לפנות שוב.';
  }

  @override
  String get askNoNumber =>
      'אי אפשר להתקשר: לאף אחד מכם אין מספר טלפון באפליקציה.';

  @override
  String get askMeNotFree => 'קודם צריך לסמן שיש לך זמן.';

  @override
  String get askFailed => 'לא הצלחנו לשאול עכשיו. אפשר לנסות שוב.';

  @override
  String friendKept(String name) {
    return '$name ברשימה שלך';
  }

  @override
  String hiddenFreeLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ועוד $count חברים פנויים, בלי שם',
      one: 'ועוד חבר אחד פנוי, בלי שם',
    );
    return '$_temp0';
  }

  @override
  String get anonymousSeeNote =>
      'בחרת להופיע בלי שם, ולכן גם כאן רואים רק כמה פנויים.';

  @override
  String get missedTitle => 'לא ענית, אז הפסקנו להציע אותך.';

  @override
  String get missedBody =>
      'בינתיים החברים לא רואים שיש לך זמן. עדיין יש לך זמן?';

  @override
  String get missedYes => 'כן, יש לי זמן';

  @override
  String get missedNo => 'לא עכשיו';

  @override
  String get autoMissedTitle => 'בנסיעות האחרונות לא ענית.';

  @override
  String get autoMissedBody => 'להשאיר את הזיהוי האוטומטי של נסיעות?';

  @override
  String get autoMissedKeep => 'להשאיר';

  @override
  String get autoMissedOff => 'לכבות';

  @override
  String get graceTitle => 'כמה דקות להתארגן';

  @override
  String get graceBody => 'אחר כך נציע שיחה, אם מישהו פנוי.';

  @override
  String get graceReady => 'אפשר כבר עכשיו';

  @override
  String get graceNotThisTrip => 'לא בנסיעה הזו';

  @override
  String get extendButton => 'להאריך';

  @override
  String get extendTitle => 'להאריך בעוד…';

  @override
  String extendBy(int minutes) {
    return '+$minutes דק׳';
  }

  @override
  String get durationUntilTime => 'עד שעה…';

  @override
  String durationUntilTimeCapped(String time) {
    return 'אפשר עד 3 שעות, אז סימנו עד $time.';
  }

  @override
  String pendingTitle(String name) {
    return 'הצטרפת לרשימה של $name';
  }

  @override
  String pendingBody(String name) {
    return 'המספר של $name לא שמור אצלך, ולכן $name עוד לא רואה מתי יש לך זמן. להשאיר ברשימה?';
  }

  @override
  String get pendingKeep => 'להשאיר';

  @override
  String get pendingRemove => 'להסיר';

  @override
  String offerShared(int minutes) {
    return 'שניכם פנויים עוד כ-$minutes דק׳';
  }

  @override
  String get offerLastTalkToday => 'כבר דיברתם היום';

  @override
  String offerLastTalkDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'דיברתם לפני $days ימים',
      one: 'דיברתם אתמול',
    );
    return '$_temp0';
  }

  @override
  String offerLastTalkDate(String date) {
    return 'לא דיברתם מאז $date';
  }

  @override
  String get offerFirstTalk => 'זו תהיה השיחה הראשונה שלכם כאן';

  @override
  String get waitOther => 'לדבר עם מישהו אחר';

  @override
  String get settingsAnonymous => 'להופיע בלי שם כשיש לי זמן';

  @override
  String get settingsAnonymousHint =>
      'החברים רואים רק כמה חברים פנויים, לא מי. כך גם אצלך: רק כמה פנויים. בהצעה לדבר השם תמיד מופיע.';

  @override
  String get settingsHideInCall => 'להסתיר כשאני בשיחה';

  @override
  String get settingsHideInCallHint =>
      'בזמן שיחה החברים לא יראו שיש לך זמן. זה הדדי: גם לך לא יופיעו חברים שנמצאים בשיחה.';

  @override
  String get settingsQuietHours => 'שעות שקטות';

  @override
  String get settingsQuietOff =>
      'בלי שעות שקטות. בנסיעה שמזוהה לבד, אפשר לקבל הצעות בכל שעה.';

  @override
  String settingsQuietOn(String from, String to) {
    return 'בין השעה $from לשעה $to, בנסיעה שמזוהה לבד לא נסמן אותך פנוי.';
  }

  @override
  String get quietPickFrom => 'מאיזו שעה?';

  @override
  String get quietPickTo => 'עד איזו שעה?';

  @override
  String get quietClear => 'לבטל שעות שקטות';

  @override
  String get quietSet => 'לבחור שעות';

  @override
  String get realNotifChannelTalk => 'הצעות לדבר';

  @override
  String get driverFreeTitle => 'מי פנוי עכשיו';

  @override
  String get driverFreeHint => 'לוחצים על חבר, ונשאל אותו.';

  @override
  String get driverNobody => 'עוד אין חבר פנוי';

  @override
  String get driverNobodyBody => 'כשמישהו יתפנה, נציע לכם לדבר.';

  @override
  String get driverNormalView => 'למסך הרגיל';

  @override
  String get driverBack => 'חזרה למסך הנהיגה';

  @override
  String get freeNotNow => 'לא כרגע';

  @override
  String freeNotNowTitle(String name) {
    return 'אי אפשר לפנות ל$name כרגע';
  }

  @override
  String get freeNotNowBody =>
      'ממש עכשיו אי אפשר להציע שיחה (למשל בתחילת נסיעה, או כשכבר שאלתם הפעם). כשזה יתאפשר, זה יופיע כרגיל.';

  @override
  String freeNotNowMine(String name) {
    return 'זה בגלל שעוד לא אישרת את $name ברשימה שלך. אחרי האישור אפשר לדבר מיד.';
  }

  @override
  String afterCallTitle(String name) {
    return 'מתי להציע לך שוב את $name?';
  }

  @override
  String afterCallNote(String name) {
    return 'בינתיים אפשר תמיד ללחוץ על $name ולשאול בעצמך.';
  }

  @override
  String get afterCallAny => 'בכל זמן';

  @override
  String get afterCallTomorrow => 'מחר';

  @override
  String get afterCall3 => 'בעוד 3 ימים';

  @override
  String get afterCallWeek => 'בעוד שבוע';

  @override
  String get afterCallNoTalk => 'לא הצלחנו לדבר';

  @override
  String directTitle(String name) {
    return '$name רוצה לדבר איתך';
  }

  @override
  String get directAsk => 'מתאים לך עכשיו?';

  @override
  String get directAskShort => 'רוצה לדבר איתך. לענות?';

  @override
  String voiceDirect(String name) {
    return '$name רוצה לדבר איתך. לענות?';
  }

  @override
  String get callToMain => 'למסך הראשי';

  @override
  String callBackToCall(String name) {
    return 'בשיחה עם $name · חזרה למסך השיחה';
  }

  @override
  String bgVoiceOffer(String name) {
    return 'ל$name יש זמן לדבר. אם מתאים — \"לדבר\" בהתראה.';
  }

  @override
  String bgVoiceDirect(String name) {
    return '$name רוצה לדבר איתך. אם מתאים — \"לדבר\" בהתראה.';
  }

  @override
  String get notifPublicTalk => 'מישהו פנוי לדבר עכשיו';

  @override
  String answeredTheyCall(String name) {
    return 'שיחה מ$name בדרך. הטלפון יצלצל.';
  }

  @override
  String answeredYouCall(String name) {
    return 'גם $name רוצה לדבר. לחיצה כאן — ומתקשרים.';
  }

  @override
  String answeredWaiting(String name) {
    return 'מחכים לתשובה מ$name.';
  }

  @override
  String get answeredMissed => 'לא הסתדר הפעם. נציע שוב בהזדמנות אחרת.';

  @override
  String voiceYouCall(String name) {
    return 'גם $name רוצה לדבר. לחיצה על ההתראה — ומתקשרים.';
  }

  @override
  String get permsTitle => 'כדי שזה יעבוד גם בנסיעה';

  @override
  String get permsBody =>
      'כמה אישורים מהטלפון, פעם אחת עכשיו, כדי שלא יקפצו שאלות באמצע נסיעה.';

  @override
  String get permsAllowAll => 'לאשר הכול';

  @override
  String get permsAllowOne => 'לאשר';

  @override
  String get permsDone => 'מאושר';

  @override
  String get permsNotifTitle => 'התראות';

  @override
  String get permsNotifBody => 'כדי לדעת כשחבר פנוי, גם כשהאפליקציה סגורה.';

  @override
  String get permsCallTitle => 'שיחות טלפון';

  @override
  String get permsCallBody => 'כדי שהשיחה תצא מיד כששניכם אומרים כן.';

  @override
  String get permsMicTitle => 'מיקרופון';

  @override
  String get permsMicBody =>
      'כדי לענות \"כן\" או \"לא\" בקול בנהיגה. שום דבר לא מוקלט.';

  @override
  String get permsBgTitle => 'עבודה ברקע';

  @override
  String get permsBgBody =>
      'כדי שחיסכון הסוללה לא יעצור את ההתראות באמצע נסיעה.';

  @override
  String get permsAutoTitle => 'זמינות אוטומטית בנסיעה (רשות)';

  @override
  String get permsAutoBody =>
      'כשהטלפון ברכב, נסמן שיש לך זמן. בלי GPS. אפשר לכבות בכל רגע.';

  @override
  String get permsSettings => 'הרשאות';

  @override
  String get permsSettingsBody => 'התראות, שיחות, מיקרופון, עבודה ברקע';

  @override
  String get answeredRetry =>
      'לא הצלחנו לענות מכאן. לחיצה כאן — עונים באפליקציה.';

  @override
  String get quickTitle => 'חיבור מהיר';

  @override
  String get quickOffBody => 'כששניכם פנויים, השיחה יוצאת לבד. 5 שניות לבטל.';

  @override
  String quickWaitingBody(String name) {
    return 'מופעל אצלך. יעבוד כשזה יופעל גם אצל $name.';
  }

  @override
  String get quickBothBody =>
      'פעיל אצל שניכם. כששניכם פנויים, השיחה יוצאת לבד.';

  @override
  String quickConfirmTitle(String name) {
    return 'חיבור מהיר עם $name?';
  }

  @override
  String quickConfirmBody(String name) {
    return 'כששניכם פנויים, השיחה יוצאת לבד, בלי שאלה. יש 5 שניות לבטל: אם אחד מכם מבטל, השיחה לא יוצאת.\n\nבאפליקציה של $name תופיע הצעה להפעיל גם.';
  }

  @override
  String get quickTurnOn => 'להפעיל';

  @override
  String quickAskTitle(String name) {
    return '$name רוצה חיבור מהיר איתך';
  }

  @override
  String get quickAskBody =>
      'כששניכם פנויים, השיחה תצא לבד, בלי לשאול. לשניכם יש 5 שניות לבטל.';

  @override
  String get quickAskYes => 'להפעיל גם';

  @override
  String get quickIntroTitle => 'חדש: חיבור מהיר';

  @override
  String get quickIntroBody =>
      'לחברים הכי קרובים: כששניכם פנויים, השיחה יוצאת לבד, בלי לשאול. 5 שניות לבטל.';

  @override
  String get quickIntroPick => 'לבחור חברים';

  @override
  String get quickPickTitle => 'חיבור מהיר עם…';

  @override
  String quickTheyWantBody(String name) {
    return 'אצל $name חיבור מהיר איתך כבר פועל. להפעיל גם?';
  }

  @override
  String get quickTheyWantChip => 'רוצה חיבור מהיר';

  @override
  String pauseTitle(String when) {
    return 'הצעות מושהות $when';
  }

  @override
  String pauseBody(String name) {
    return 'אפשר תמיד ללחוץ על $name ולשאול בעצמך.';
  }

  @override
  String get pauseQuickNote => 'חיבור מהיר עובד גם בזמן ההשהיה.';

  @override
  String get pauseCancel => 'לבטל';

  @override
  String pauseChip(String when) {
    return 'מושהה $when';
  }

  @override
  String pauseUntilTime(String time) {
    return 'עד $time';
  }

  @override
  String get pauseUntilTomorrow => 'עד מחר';

  @override
  String pauseUntilDay(String day) {
    return 'עד יום $day';
  }

  @override
  String pauseUntilDate(String date) {
    return 'עד $date';
  }

  @override
  String get settingsPrivacyInfo => 'מה נשמר עליי';

  @override
  String get permsPhoneNotif => 'הגדרות ההתראות בטלפון';

  @override
  String get realCirclesNone =>
      'משפחה, עבודה, חברים קרובים: מי רואה שיש לך זמן';

  @override
  String get routineAskTitle => 'השגרה שלך: יש לך זמן עכשיו?';

  @override
  String routineAskBody(String minutes) {
    return 'בלחיצה על \"כן\" נסמן שיש לך זמן ל-$minutes דק׳.';
  }

  @override
  String get routineAskYes => 'כן, יש לי זמן';

  @override
  String get othersRuleTitle => 'חברים שלא בשום קבוצה: מתי הם יראו שיש לך זמן?';

  @override
  String get pasteCode => 'הדבקה';

  @override
  String get realCallEnded => 'השיחה הסתיימה';

  @override
  String get realTapOrWait => 'אפשר ללחוץ על חבר פנוי, או לחכות שנציע.';

  @override
  String driverMyTimeLeft(int minutes) {
    return 'הזמן הפנוי שלך: עוד $minutes דק׳';
  }

  @override
  String durationTripNoteDetected(int hours) {
    return 'נגמר לבד כשהנסיעה נגמרת (ולכל היותר אחרי $hours שעות).';
  }

  @override
  String get afterCallHope => 'מקווים שהשיחה הייתה טובה 🙂';

  @override
  String get afterCallWrite => 'יש משוב או תובנה? אפשר לכתוב לנו, ונשפר';

  @override
  String realWaitingLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'עוד $seconds שניות',
      one: 'עוד שנייה',
    );
    return '$_temp0';
  }

  @override
  String get addFriend => 'הוספת חבר';

  @override
  String get addFriendInviteBody => 'שולחים קישור בוואטסאפ או בהודעה';

  @override
  String get addFriendCodeBody => 'קיבלת הזמנה בלי קישור? מכניסים כאן את הקוד';

  @override
  String get addFriendContactsBody => 'רואים מי מאנשי הקשר כבר כאן, ובוחרים';

  @override
  String get tripNotifChannel => 'חברים יוצאים לדרך';

  @override
  String tripNotifTitle(String name) {
    return '$name בדרך';
  }

  @override
  String get tripNotifBody => 'יש זמן לדבר עכשיו';

  @override
  String get tripNotifTalk => 'לדבר';

  @override
  String get settingsTripNotify => 'להודיע לחברים עם חיבור מהיר כשיוצאים לדרך';

  @override
  String get settingsTripNotifyBody =>
      'רק לחברים ששניכם הדלקתם חיבור מהיר, פעם ביום לכל היותר, ולא בשעות השקטות שלהם.';

  @override
  String get pushTestButton => 'שליחת התראת בדיקה אליי';

  @override
  String get pushTestSent =>
      'נשלחה התראת בדיקה. היא אמורה להופיע בעוד כמה שניות.';

  @override
  String get pushTestNoAppPush =>
      'בגרסה הזו של האפליקציה עוד אין התראות (חסרות הגדרות Firebase ב-GitHub).';

  @override
  String get pushTestNoFunction =>
      'פונקציית ההתראות (smooth-responder) לא נמצאה ב-Supabase.';

  @override
  String get pushTestNotConfigured =>
      'בפונקציה חסר הסוד FCM_SERVICE_ACCOUNT ב-Supabase.';

  @override
  String get pushTestNoServer => 'השרת עוד לא עודכן לחלק 12 (גרסה 44).';

  @override
  String get pushTestNotAllowed =>
      'הפונקציה דורשת אימות: צריך לכבות בה את Enforce JWT Verification.';

  @override
  String pushTestFailed(String code) {
    return 'השליחה לא הצליחה ($code).';
  }

  @override
  String get pushTestTitle => 'בדיקה: ההתראות עובדות ✓';

  @override
  String get pushTestNoToken =>
      'הכתובת של הטלפון הזה לא נמצאה בשרת (no_token).';

  @override
  String get notifChannelNews => 'עדכונים מ-DriveBond';

  @override
  String get ownerNotifFeedback => 'התקבל משוב חדש';

  @override
  String get ownerNotifCrash => 'האפליקציה קרסה אצל מישהו';

  @override
  String ownerNotifUser(String name) {
    return 'משתמש חדש: $name';
  }

  @override
  String get versionNotifTitle => 'יש גרסה חדשה של DriveBond';

  @override
  String get versionNotifBody => 'לחיצה לעדכון ב-Google Play';

  @override
  String friendsSeeMeFree(String mode, String left) {
    return 'חברים רואים: פנוי · $mode · $left';
  }

  @override
  String get friendsSeeMeInCall =>
      'חברים רואים: בשיחה. בינתיים לא יגיעו שאלות.';

  @override
  String get friendsSeeMeHidden =>
      'בשיחה: חברים לא רואים שיש לך זמן (מוסתר בשיחה).';

  @override
  String missedNotifTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name ניסתה להשיג אותך',
      'male': '$name ניסה להשיג אותך',
      'other': 'פספסת שיחה עם $name',
    });
    return '$_temp0';
  }

  @override
  String get missedNotifBody => 'השאלה נסגרה לפני שענית. אפשר להתקשר כשנוח.';

  @override
  String get quietPickDays => 'באילו ימים?';

  @override
  String get quietDaysSave => 'שמירה';

  @override
  String get quietDayLetters => 'א,ב,ג,ד,ה,ו,ש';

  @override
  String settingsQuietOnDays(String days, String from, String to) {
    return 'בימים $days, בין השעה $from לשעה $to, בנסיעה שמזוהה לבד לא נסמן אותך פנוי.';
  }

  @override
  String get aboutTitle => 'על DriveBond';

  @override
  String get aboutSettingsBody =>
      'מה מיוחד באפליקציה, אילו הרשאות אישרת ולמה צריך אותם';

  @override
  String get aboutHero =>
      'הזמן המת של היום, בנסיעה, בפקק או בהליכה, הופך לשיחה טובה עם מישהו שחשוב לך.';

  @override
  String get aboutSpecialTitle => 'מה מיוחד כאן';

  @override
  String get aboutSpecial1Title => 'רגע מת הופך לשיחה';

  @override
  String get aboutSpecial1Body =>
      'כשיש לכם זמן באותו רגע, האפליקציה מחברת ביניכם. בלי לתאם מראש ובלי \"נדבר מתישהו\".';

  @override
  String get aboutSpecial2Title => 'שיחה רק כששניכם רוצים';

  @override
  String get aboutSpecial2Body =>
      'אף שיחה לא מתחילה בלי \"כן\" משני הצדדים. גם כשמזוהה נסיעה, זה רק אומר שיש זמן, לא שמישהו יתקשר.';

  @override
  String get aboutSpecial3Title => 'בנהיגה: בקול ובכפתורים גדולים';

  @override
  String get aboutSpecial3Body =>
      'הטלפון מקריא מי פנוי, ועונים \"כן\" או \"לא\" בקול. בלי הקלדה ובלי רשימות לגלול.';

  @override
  String get aboutSpecial4Title => 'אתם שולטים';

  @override
  String get aboutSpecial4Body =>
      'מי רואה שיש לכם זמן, שעות וימים שקטים, הסתרה בזמן שיחה, וחסימה. הכול בהגדרות.';

  @override
  String get aboutSpecial5Title => 'בלי פיד ובלי זרים';

  @override
  String get aboutSpecial5Body =>
      'אין גלילה אינסופית ואין צ\'אט אקראי. רק שיחות עם אנשים שבחרתם.';

  @override
  String get aboutPermsTitle => 'ההרשאות בטלפון';

  @override
  String get aboutPermsIntro =>
      'מה אישרת ולמה צריך את זה. כל הרשאה משמשת רק למה שכתוב כאן.';

  @override
  String get aboutPermOn => 'מאושר';

  @override
  String get aboutPermOff => 'לא אושר';

  @override
  String get aboutPermOptional => 'רשות';

  @override
  String get aboutPermInUse => 'בשימוש';

  @override
  String get aboutPermNotifBody =>
      'כדי שתדעו כשחבר פנוי, כשמישהו שואל אם יש לכם זמן, או כשמישהו ניסה להשיג אתכם, גם כשהאפליקציה סגורה.';

  @override
  String get aboutPermCallBody =>
      'כששניכם אומרים \"כן\", השיחה יוצאת מיד דרך החייגן הרגיל של הטלפון, בלי עוד לחיצה. האפליקציה לא קוראת את יומן השיחות.';

  @override
  String get aboutPermMicBody =>
      'רק כשהאפליקציה שואלת ומחכה ל\"כן\" או \"לא\" בנהיגה. כשהטלפון מחובר לדיבורית של הרכב, משתמשים במיקרופון של הרכב (המוזיקה עלולה להיעצר לשנייה). ההקשבה נעשית בטלפון עצמו, ושום דבר לא מוקלט ולא נשמר.';

  @override
  String get aboutPermBgBody =>
      'חיסכון הסוללה של הטלפון עלול לעצור את האפליקציה באמצע נסיעה. הפטור מאפשר לה להמשיך לעבוד ולהודיע לכם בזמן.\nהאפליקציה עובדת ברקע רק בזמן נסיעה, או כשסימנתם שיש לכם זמן, ולא כל היום. בשאר הזמן היא כבויה, ואנדרואיד מעיר אותה רק כשהטלפון ברכב.\nצריכת הסוללה קטנה מאוד: בלי GPS, ורק בדיקה קצרה מול השרת, בדרך כלל פעם בחצי דקה.';

  @override
  String get aboutPermContactsTitle => 'אנשי קשר';

  @override
  String get aboutPermContactsBody =>
      'כדי למצוא חברים שכבר משתמשים ב-DriveBond. נקראים רק מספרי הטלפון, והם עוברים הצפנה חד-כיוונית בטלפון עצמו. השמות לא יוצאים מהטלפון, ואף אחד לא מתחבר אליכם בלי שתבחרו.';

  @override
  String get aboutPermActivityTitle => 'פעילות גופנית (זיהוי נסיעה)';

  @override
  String get aboutPermActivityBody =>
      'רק אם הדלקתם \"זמינות אוטומטית בנסיעה\". אנדרואיד אומר לאפליקציה \"הטלפון כנראה ברכב\", בלי GPS ובלי מיקום. זה כבוי עד שמדליקים.';

  @override
  String get aboutPermBtTitle => 'בלוטות\' (הרכב)';

  @override
  String get aboutPermBtBody =>
      'רשות: אם בחרתם את הרכב, האפליקציה שמה לב כשהטלפון מתחבר אליו, וכך מזהה נסיעה מהר יותר. המידע נשאר בטלפון.';

  @override
  String get aboutPrivacyTitle => 'מה אנחנו אף פעם לא עושים';

  @override
  String get aboutNever1 =>
      'לא מקליטים שיחות, לא מתמללים, ואין שום בינה מלאכותית על מה שנאמר.';

  @override
  String get aboutNever2 => 'לא קוראים את יומן השיחות.';

  @override
  String get aboutNever3 =>
      'לא משתמשים ב-GPS. מיקום, מסלול ומהירות לא נשלחים לאף אחד.';

  @override
  String get aboutNever4 =>
      'חברים רואים רק אם יש לכם זמן, באיזה מצב (למשל בנסיעה), ועד מתי.';

  @override
  String get aboutNever5 => 'לא אומרים שאתם הנהגים, רק ש\"הטלפון כנראה ברכב\".';

  @override
  String get aboutFeedbackTitle => 'עזרו לנו לשפר';

  @override
  String get aboutFeedbackBody =>
      'האפליקציה עדיין בבדיקה. כל הערה עוזרת: מה אהבתם, מה בלבל, ומה לא עבד.';

  @override
  String get meInRow => 'אני';

  @override
  String get quietEveryDay => 'כל יום';

  @override
  String quietRangeLine(String days, String from, String to) {
    return '$days: $from–$to';
  }

  @override
  String get quietScreenBody =>
      'בשעות האלה, בנסיעה שמזוהה לבד לא נסמן אותך פנוי. אפשר כמה לוחות זמנים, למשל ראשון–חמישי בלילה ושעות אחרות בשישי ושבת.';

  @override
  String get quietAdd => 'הוספת שעות שקטות';

  @override
  String get quietNone => 'עוד אין שעות שקטות.';

  @override
  String get quietDelete => 'למחוק';

  @override
  String quietMany(String count, String lines) {
    return '$count לוחות זמנים: $lines';
  }

  @override
  String waitingSent(String name) {
    return '✓ נשלח ל$name';
  }

  @override
  String waitingReached(String name) {
    return '✓✓ הגיע לטלפון של $name';
  }

  @override
  String get permsFullTitle => 'שאלה על כל המסך בנהיגה';

  @override
  String get permsFullBody => 'כדי לענות \"כן\" בקול גם כשהמסך נעול.';

  @override
  String get aboutPermFullBody =>
      'בנהיגה, כשחבר שואל אם יש לך זמן, האפליקציה נפתחת כמו שיחה נכנסת, גם על מסך נעול, ושואלת בקול. ככה אפשר לענות \"כן\" או \"לא\" בלי לגעת בטלפון. כשהמסך בשימוש (למשל ניווט), מופיעה רק התראה למעלה.';

  @override
  String get whyTitle => 'למה מישהו לא מופיע?';

  @override
  String get whyHint => 'מספר הטלפון שלו';

  @override
  String get whyCheck => 'לבדוק';

  @override
  String get whyBadNumber => 'זה לא נראה כמו מספר טלפון.';

  @override
  String whyNumber(String number) {
    return 'המספר בצורה אחידה: $number';
  }

  @override
  String get whyNoContacts =>
      'אין לאפליקציה גישה לאנשי הקשר, אז היא לא יכולה למצוא אותו משם.';

  @override
  String get whyNotInContacts =>
      'המספר הזה לא נמצא באנשי הקשר בטלפון הזה (אולי שמור אצלך מספר אחר שלו).';

  @override
  String whyInContacts(String name, String number) {
    return 'נמצא באנשי הקשר: $name, שמור כ-$number.';
  }

  @override
  String get whyMe => 'זה המספר שלך.';

  @override
  String get whyNotUser =>
      'אין ב-DriveBond משתמש עם המספר הזה (אולי נרשם בלי מספר, או עם מספר אחר).';

  @override
  String get whyUser =>
      'הוא משתמש ב-DriveBond. בהוספת חבר ← אנשי קשר הוא אמור להופיע; אם לא, לחפש שוב.';

  @override
  String get whyFriend => 'הוא כבר חבר שלך.';

  @override
  String get whyRemoved =>
      'אחד מכם הסיר את השני בעבר, ולכן הוא לא חוזר מאנשי הקשר. מי שהסיר יכול להחזיר: האנשים שלי ← אנשים שהסרתי ← להחזיר.';

  @override
  String get whyBlocked => 'יש חסימה ביניכם, ולכן הוא לא מופיע.';

  @override
  String get whyRateLimited => 'היום כבר חיפשו הרבה. אפשר לנסות שוב מחר.';

  @override
  String get whyOldServer => 'השרת עוד לא עודכן לבדיקה הזו (חלק 21).';

  @override
  String get widgetTitle => 'פנויים עכשיו';

  @override
  String get widgetEmpty => 'אף אחד לא פנוי כרגע';

  @override
  String widgetLeft(String m) {
    return 'עוד $m דק׳';
  }

  @override
  String get voiceHeardYes => 'קיבלתי, מחברים.';

  @override
  String get voiceHeardNo => 'בסדר.';

  @override
  String get voiceNotHeard => 'לא שמעתי. אפשר ללחוץ.';

  @override
  String healthMissing(String what) {
    return 'חסר אישור בטלפון: $what. בלעדיו DriveBond לא עובדת כמו שצריך.';
  }

  @override
  String get healthFix => 'לתקן';

  @override
  String get whatsNewTitle => 'מה חדש בעדכון';

  @override
  String get whatsNewBody =>
      '• \"כן\" בקול: צפצוף כשמקשיבים, יותר זמן לענות, ואישור בקול\n• אחרי שיחה אפשר לפנות שוב מיד\n• ווידג\'ט למסך הבית: מי פנוי עכשיו';

  @override
  String get problemTitle => 'דיווח על בעיה';

  @override
  String get problemBody =>
      'משהו לא עבד? כתבו מה קרה, ונקבל גם את הפרטים הטכניים.';

  @override
  String get problemHint => 'מה קרה? בערך מתי?';

  @override
  String get problemDetails =>
      'יחד עם ההודעה יישלחו פרטים טכניים מהטלפון (גרסה, מצב, יומן). בלי שמות של חברים, בלי מספרים ובלי שום דבר מהקול.';

  @override
  String get ownerLookupTitle => 'מצב של משתמש בשרת';

  @override
  String get ownerLookupHint => 'שם או מספר טלפון';

  @override
  String get ownerLookupNone => 'לא נמצא אף אחד.';

  @override
  String get ownerDetails => 'פרטים טכניים';

  @override
  String get testDriveTry => 'לנסות נסיעת מבחן';

  @override
  String get testDriveTitle => 'נסיעת מבחן';

  @override
  String get testDriveSettings =>
      'ככה זה מרגיש ברכב. גם בדיקה שהמיקרופון עובד.';

  @override
  String get testDriveBody =>
      'נדמה שחבר פנוי בזמן נסיעה. האפליקציה תשאל בקול, ואפשר לענות \"כן\" או \"לא\" בקול או בכפתור. אף אחד לא מקבל שאלה, זה רק תרגול.';

  @override
  String get testDriveStart => 'להתחיל';

  @override
  String get testDriveFriendInitial => 'ד';

  @override
  String get testDriveQuestion => 'לדני (לדוגמה) יש זמן. לדבר?';

  @override
  String get testDriveYes => 'כן, לדבר';

  @override
  String get testDriveNo => 'לא עכשיו';

  @override
  String get testDriveYesTitle => 'מעולה, ככה זה עובד';

  @override
  String get testDriveYesBody =>
      'בנסיעה אמיתית, אחרי שגם החבר אומר כן, הטלפון מחייג לבד. נשאר רק לדבר.';

  @override
  String get testDriveNoTitle => 'גם זה בסדר';

  @override
  String get testDriveNoBody => 'אפשר תמיד לסרב. נציע שוב בהזדמנות אחרת.';

  @override
  String get testDriveNotHeardTitle => 'לא שמענו תשובה';

  @override
  String get testDriveNotHeardBody =>
      'אפשר לנסות שוב ולדבר ברור אחרי הצפצוף. אם זה חוזר, כדאי לבדוק בהגדרות ← הרשאות שהמיקרופון מאושר. הכפתורים תמיד עובדים.';

  @override
  String get testDriveDone => 'סיימתי';

  @override
  String get testDriveAgain => 'לנסות שוב';

  @override
  String get homeUpdating => 'מתעדכן…';

  @override
  String get startingLines =>
      'מחפשים מי פנוי לדבר…|בודקים מי בדרך…|מכינים את החברים שלך…|עוד רגע…';

  @override
  String get googleContinue => 'המשך עם Google';

  @override
  String get googleOr => 'או בלי Google';

  @override
  String googleConnected(String email) {
    return 'מחובר עם Google: $email';
  }

  @override
  String get googleCardTitle => 'לשמור את החשבון עם Google';

  @override
  String get googleCardBody =>
      'ככה החברים שלך יחזרו אליך גם בטלפון חדש או אחרי התקנה מחדש.';

  @override
  String get googleCardAction => 'חיבור ל-Google';

  @override
  String get googleSettingsTitle => 'חשבון Google';

  @override
  String get googleSettingsOff =>
      'לא מחובר. כדאי, כדי שהחשבון יחזור בטלפון חדש';

  @override
  String get googleTakenTitle => 'לחשבון Google הזה כבר יש חשבון DriveBond';

  @override
  String get googleTakenBody =>
      'כנראה מטלפון אחר. אפשר לעבור אליו, והחברים שלו יופיעו כאן. החשבון שפתוח עכשיו בטלפון הזה ינותק ממנו.';

  @override
  String get googleSwitch => 'לעבור לחשבון הזה';

  @override
  String get realErrorGoogle => 'לא הצלחנו להתחבר עם Google. אפשר לנסות שוב.';

  @override
  String get autoYesTitle => 'כן אוטומטי בנסיעה';

  @override
  String get autoYesBody =>
      'בזמן נסיעה, חבר שנתת לו מספיק כוכבים ולוחץ עליך מתחבר מיד, בלי שאלה. הוא מתקשר, והטלפון שלך פשוט מצלצל. אם גם הוא הפעיל את זה בשבילך, מתחברים לבד אחרי 5 שניות שאפשר לבטל.';

  @override
  String get autoYesFrom => 'ממי';

  @override
  String get autoYesStars3 => '3 כוכבים ומעלה';

  @override
  String get autoYesStars4 => '4 ומעלה';

  @override
  String get autoYesStars5 => 'רק 5';

  @override
  String get autoYesOn => '⚡ כן אוטומטי פועל';

  @override
  String get autoYesOff => '⚡ כן אוטומטי כבוי';

  @override
  String get instantFriend => 'מתחבר מיד';

  @override
  String get homeAutoYesTitle => '⚡ כן אוטומטי בנסיעה';

  @override
  String homeAutoYesOnBody(int stars) {
    return 'חברים עם $stars כוכבים ומעלה מתחברים אליך מיד כשאתה בנסיעה.';
  }

  @override
  String get homeAutoYesOffBody =>
      'כבוי. כשדולק, חברים קרובים מתחברים אליך מיד בנסיעה, בלי שאלה.';

  @override
  String get modeFreeShort => 'פנוי';

  @override
  String get startDriving => 'אני בנסיעה';

  @override
  String get startFree => 'יש לי זמן';

  @override
  String get startHint => 'לחיצה אחת = 30 דקות. אפשר לשנות אחר כך.';

  @override
  String audienceLabel(String who) {
    return 'זמין ל: $who';
  }

  @override
  String get audienceAll => 'כולם';

  @override
  String audienceAllBut(String names) {
    return 'כולם חוץ מ$names';
  }

  @override
  String get audienceTitle => 'למי אני זמין?';

  @override
  String get audienceOnlyTab => 'רק לקבוצות שאסמן';

  @override
  String get audienceExceptTab => 'לכולם חוץ מ…';

  @override
  String get audienceOnlyNote =>
      'רק מי שבקבוצות המסומנות יראה שיש לך זמן. בלי סימון: כולם.';

  @override
  String get audienceExceptNote =>
      'כל החברים יראו שיש לך זמן, חוץ ממי שבקבוצות המסומנות.';

  @override
  String get audienceNoGroups =>
      'עוד אין קבוצות. אפשר ליצור אותן בלשונית האנשים.';

  @override
  String audienceMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים',
      one: 'אדם אחד',
    );
    return '$_temp0';
  }

  @override
  String meDrivingTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'את בנסיעה',
      'male': 'אתה בנסיעה',
      'other': 'בנסיעה',
    });
    return '$_temp0';
  }

  @override
  String meFreeTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'יש לך זמן',
      'male': 'יש לך זמן',
      'other': 'יש לך זמן',
    });
    return '$_temp0';
  }

  @override
  String timeLeftEdit(int minutes) {
    return 'עוד $minutes דק׳';
  }

  @override
  String get autoTripEnds => 'נסיעה אוטומטית · נגמרת לבד';

  @override
  String get timeTitle => 'לכמה זמן?';

  @override
  String get time15 => '15 דק׳';

  @override
  String get time30 => '30 דק׳';

  @override
  String get time45 => '45 דק׳';

  @override
  String get time60 => 'שעה';

  @override
  String get time90 => 'שעה וחצי';

  @override
  String get time120 => 'שעתיים';

  @override
  String get time180 => '3 שעות';

  @override
  String get timeUntil => 'עד שעה מסוימת';

  @override
  String get timeMaxNote => 'עד 3 שעות מתחילת הזמן הפנוי.';

  @override
  String get endFree => 'סיום';

  @override
  String get groupsNote =>
      'מה השתנה: \"מי רואה אותי בכל מצב\" ירד מהקבוצות. במקומו, כשיש לך זמן בוחרים \"זמין ל…\". מי שלא רוצים שיראה אותך: 0 כוכבים. הגדרה שכבר קבעת נשמרת, ואפשר לראות אותה בתוך הקבוצה.';

  @override
  String get intro1Title => 'שוב תקוע בפקק?';

  @override
  String get intro1Body => 'אולי זה דווקא זמן טוב לדבר עם חבר.';

  @override
  String get intro2Title => 'גם לחבר שלך\nיש זמן עכשיו.';

  @override
  String get intro2Body => 'DriveBond מזהה כששניכם פנויים ומציעה לכם לדבר.';

  @override
  String get introStart => 'בואו נתחיל';

  @override
  String get onbContinue => 'המשך';

  @override
  String get onbBack => 'חזרה';

  @override
  String get onbWhatIs => 'מה זה DriveBond?';

  @override
  String get onbPhoneTitle => 'מה המספר שלך?';

  @override
  String get onbGoogleName => 'השם שיופיע לחברים';

  @override
  String get intro3Title => 'פתאום הפקק\nעובר בכיף.';

  @override
  String get intro3Body => 'שניכם מאשרים קולית ומתחילה שיחת טלפון רגילה.';

  @override
  String get intro2Badge => 'DriveBond זיהתה: שניכם פנויים עכשיו';

  @override
  String get aboutTourOpen => 'איך זה עובד – ב-3 תמונות';

  @override
  String get aboutTourDone => 'הבנתי';

  @override
  String get realCarPickHint =>
      'אפשר לסמן כמה רכבים, למשל רכב פרטי ורכב עבודה.';

  @override
  String get realCarSave => 'שמירה';
}
