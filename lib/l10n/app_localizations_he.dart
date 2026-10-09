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
      'female': 'יש לי זמן עכשיו',
      'male': 'יש לי זמן עכשיו',
      'other': 'יש לי זמן עכשיו',
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
  String get pickModeTitle => 'מה המצב?';

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
  String get driverSearching => 'מחפשים...';

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
  String get availableToEveryone => 'כולם';

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
      'בנסיעה, הטלפון אומר בקול מי פנוי, ואפשר לענות \"כן\" או \"לא\" בלי לגעת במסך.';

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
  String get realNotConfiguredTitle => 'הבדיקה עם חבר עוד לא מחוברת';

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
  String get realWaitingForFriends => 'כשחבר יהיה פנוי — נשאל את שניכם.';

  @override
  String get realFreeFriendsTitle => 'עכשיו';

  @override
  String get realNobodyFree =>
      'יש לך 20 דקות? לוחצים \"יש לי זמן\" ונחפש עם מי לדבר.';

  @override
  String get realFreeHint => 'רוצים לדבר? לוחצים \"יש לי זמן\" ונציע לכם.';

  @override
  String get realNobodyFreeYet => 'נעדכן ברגע שמישהו מתאים יתפנה.';

  @override
  String get homeIntentsTitle => 'אשמח לדבר';

  @override
  String get homeIntentsBody => 'כשתהיו פנויים יחד — נציע אותם קודם.';

  @override
  String get realNoFriendsTitle => 'עוד אין פה חברים';

  @override
  String get realNoFriendsBody =>
      'הזמינו חבר — וכששניכם פנויים, נציע לכם לדבר.';

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
  String get realBgFailedTitle => 'לא הצלחנו להדליק זמינות ברקע';

  @override
  String get realBgFailedBody =>
      'הטלפון חסם את זה. פותחים את DriveBond ולוחצים \"יש לי זמן\".';

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
  String get realVoiceOfferAnon => 'חבר פנוי עכשיו. לדבר?';

  @override
  String get realVoiceQuickAnon => 'מתחברים לחבר. אפשר לבטל בכפתור.';

  @override
  String get realVoiceCallingAnon => 'מתקשרים.';

  @override
  String get realVoiceTheyCallAnon => 'מתקשרים אליך עכשיו.';

  @override
  String get settingsSpeakNames => 'להקריא שמות';

  @override
  String get settingsSpeakNamesBody =>
      'הטלפון אומר בקול את שם החבר. כבוי: רק \"חבר פנוי\", בלי שם (טוב כשיש עוד אנשים ברכב).';

  @override
  String get realDeleteAccount => 'למחוק את החשבון והמידע שלי';

  @override
  String get realDeleteAccountConfirm =>
      'הכול נמחק מהשרת: שם, מספר, חברים, מעגלים ותמונה. אי אפשר לבטל.';

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
  String get outcomeQuestion => 'איך היה?';

  @override
  String get outcomeGood => 'היה טוב';

  @override
  String get outcomeNotSoon => 'לא להציע בקרוב';

  @override
  String get outcomeNoTalk => 'לא דיברנו בפועל';

  @override
  String get intentTitle => 'אשמח לדבר';

  @override
  String intentExplain(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female':
          '$name לא תקבל שום הודעה. כששניכם תהיו פנויים — היא תוצע לך קודם.',
      'male':
          '$name לא יקבל שום הודעה. כששניכם תהיו פנויים — הוא יוצע לך קודם.',
      'other':
          'שום הודעה לא נשלחת ל$name. כששניכם תהיו פנויים — נציע את $name קודם.',
    });
    return '$_temp0';
  }

  @override
  String get intentToday => 'היום';

  @override
  String get intentWeek => 'השבוע';

  @override
  String get intentAlways => 'עד שאבטל';

  @override
  String get intentRemove => 'להסיר';

  @override
  String get intentBadgeToday => 'אשמח לדבר · היום';

  @override
  String get intentBadgeWeek => 'אשמח לדבר · השבוע';

  @override
  String get intentBadgeAlways => 'אשמח לדבר';

  @override
  String realCallingNow(String name) {
    return 'מתקשרים ל$name…';
  }

  @override
  String get realDialedBody => 'כשתסיימו — חזרו לכאן.';

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
  String get realTheyCallBody => 'אם השיחה לא מגיעה תוך דקה — לחצו למטה.';

  @override
  String get realTheyDidNotCall => 'לא הגיעה שיחה';

  @override
  String get realNoNumbersTitle => 'אי אפשר להתקשר הפעם';

  @override
  String get realNoNumbersBody =>
      'לשניכם אין מספר טלפון באפליקציה. כדי לדבר, אחד מכם מוסיף מספר: הגדרות ← לחיצה על השם ← \"המספר שלי\".';

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
  String get realInviteProblemUsed => 'ההזמנה הזו כבר נוצלה. בקשו הזמנה חדשה.';

  @override
  String get realInviteProblemExpired => 'פג תוקף ההזמנה. בקשו הזמנה חדשה.';

  @override
  String get realInviteProblemOwn => 'זו הזמנה ששלחת בעצמך 🙂 שלחו אותה לחבר.';

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
    return 'משהו השתבש ($code). נסו שוב.';
  }

  @override
  String get realErrorAnonymousDisabled =>
      'בשרת עוד לא הופעלה כניסה בלי סיסמה (Anonymous sign-ins).';

  @override
  String get realErrorSchema => 'השרת עוד לא הוכן (צריך להריץ את קובץ ההגדרה).';

  @override
  String get realErrorInvalidPhone => 'מספר הטלפון לא נראה תקין';

  @override
  String get realErrorInvalidName => 'השם צריך להיות באורך 1–40 תווים';

  @override
  String get realErrorRateLimited =>
      'יותר מדי ניסיונות. נסו שוב בעוד כמה דקות.';

  @override
  String get realErrorTooManyInvites =>
      'יש כבר הרבה הזמנות פתוחות. נסו שוב מחר.';

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
      'כאן רואים שהכל עובד. אם משהו לא עובד — \"להעתיק מידע לבדיקה\" ושולחים לי.';

  @override
  String get realTestSteps =>
      '1. להזמין חבר\n2. שניכם: \"יש לי זמן\"\n3. שניכם: \"לדבר עכשיו\"';

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
  String get realNotShared => 'לא משותף';

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
  String get realAutoDrivingFailed => 'לא הצלחנו להפעיל זיהוי נסיעה. נסו שוב.';

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
  String get realCirclesTitle => 'מעגלים';

  @override
  String get realCirclesIntro => 'קבוצות פרטיות. אפשר לסמן זמן פנוי רק לקבוצה.';

  @override
  String get realCircleNew => 'מעגל חדש';

  @override
  String get realCircleName => 'שם המעגל (למשל: משפחה)';

  @override
  String get realCircleQuick => 'חיבור מהיר';

  @override
  String get realCircleQuickBody =>
      'אם גם הם שמו אותך בחיבור מהיר — מתחברים מיד, עם 5 שניות לביטול.';

  @override
  String get realCircleMembers => 'מי במעגל';

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
  String get realCircleDelete => 'מחיקת המעגל';

  @override
  String get realCircleNoFriends => 'קודם צריך להזמין חברים';

  @override
  String get realPhoneRequired => 'מספר טלפון (לא חובה)';

  @override
  String get realPhoneRequiredHelp =>
      'למה כדאי: חברים ששמרו את המספר שלך יוכלו למצוא ולהוסיף אותך, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל את המספר רק כששניכם אמרתם \"כן\". אפשר גם להוסיף אחר כך.';

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
  String get realWelcomeHeadline => 'זמן מת?\nשיחה טובה.';

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
  String get realCarTitle => 'הרכב שלי (בלוטות׳)';

  @override
  String get realCarBody =>
      'כשהטלפון מתחבר לבלוטות׳ של הרכב, זה סימן שהנסיעה התחילה. עוזר לזהות נסיעה מהר יותר.';

  @override
  String get realCarPick => 'בחירת הרכב';

  @override
  String get realCarNoDevices =>
      'לא נמצאו מכשירי בלוטות׳ מחוברים. חברו את הטלפון לרכב פעם אחת ונסו שוב.';

  @override
  String get realCarRemove => 'בלי רכב';

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
  String get hideStatusTitle => 'להסתיר מתי יש לי זמן';

  @override
  String get hideStatusBody =>
      'החברים לא יראו מתי יש לך זמן, וגם לך לא יוצג מי פנוי. הצעות לדבר ממשיכות כרגיל.';

  @override
  String get hiddenNote =>
      'המצב שלך מוסתר, ולכן גם לא רואים כאן מי פנוי. הצעות לדבר ממשיכות.';

  @override
  String get realLaterButton => 'לא עכשיו — אחזור אליך';

  @override
  String realLaterNote(String name) {
    return 'מ$name: עכשיו לא מתאים, אחזור אליך.';
  }

  @override
  String get backgroundTitle => 'שההצעות יגיעו גם כשהאפליקציה סגורה';

  @override
  String get backgroundBody =>
      'חיסכון הסוללה של הטלפון עלול לעצור את DriveBond ברקע, ואז זיהוי הנסיעה וההתראות לא עובדים. לחיצה אחת מתקנת.';

  @override
  String get backgroundAllow => 'לאפשר פעולה ברקע';

  @override
  String get notNowShort => 'לא עכשיו';

  @override
  String get firstRunRoutineTitle => 'מתי בדרך כלל יש לך זמן בדרך?';

  @override
  String get firstRunRoutineBody =>
      'בימים א׳–ה׳ בשעה שבחרת הזמינות תידלק לבד לחצי שעה. השעה ניתנת לשינוי בעיפרון. אפשר לשנות בכל רגע גם בהגדרות ← השגרה שלי.';

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
  String get statsUsers => 'משתמשים (סה״כ)';

  @override
  String get statsNewUsers => 'הצטרפו בתקופה';

  @override
  String get statsActiveUsers => 'פתחו את האפליקציה בתקופה';

  @override
  String get statsFriendships => 'חיבורים בין אנשים (סה״כ)';

  @override
  String get statsFreeTimes => 'פעמים שסימנו \"יש לי זמן\"';

  @override
  String get statsOffers => 'הצעות לדבר';

  @override
  String get statsQuick => 'חיבורים מהירים';

  @override
  String get statsBothYes => 'שניהם אמרו כן';

  @override
  String get statsTalked => 'דיברו בפועל (לפי המשוב)';

  @override
  String get statsDeclined => '\"לא עכשיו\"';

  @override
  String get statsLater => 'מתוכם \"אחזור אליך\"';

  @override
  String get statsNoAnswer => 'בלי תשובה';

  @override
  String get statsDialMs => 'זמן מ\"כן\" שני עד חיוג (חציון)';

  @override
  String get statsSeconds => 'שנ׳';

  @override
  String get statsNote =>
      'רק סכומים. בלי שמות, בלי מספרים, ובלי שום מידע על אדם מסוים.';

  @override
  String get notificationsTitle => 'התראות';

  @override
  String get notificationsOnBody =>
      'דלוקות: מקבלים הודעה כשלחבר יש זמן ואפשר לדבר. לחיצה לשינוי בהגדרות הטלפון.';

  @override
  String get notificationsOffBody =>
      'כבויות: בלי התראות, הצעות לדבר מגיעות רק כשהאפליקציה פתוחה. לחיצה להדלקה.';

  @override
  String get statsReports => 'דיווחים';

  @override
  String realInviteStore(String url) {
    return 'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה מ-Google Play: $url';
  }

  @override
  String inactiveTitle(String name) {
    return '$name: בלי כניסה ל-DriveBond כבר שבוע';
  }

  @override
  String get inactiveBody => 'אולי האפליקציה הוסרה. להסיר מהרשימה שלך?';

  @override
  String get inactiveRemove => 'להסיר מהרשימה';

  @override
  String get inactiveKeep => 'להשאיר';

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
}
