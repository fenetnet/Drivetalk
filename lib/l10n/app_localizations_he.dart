// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'DriveTalk';

  @override
  String get tabHome => 'בית';

  @override
  String get tabConnections => 'קשרים';

  @override
  String get tabDiscover => 'גילוי';

  @override
  String get tabSettings => 'הגדרות';

  @override
  String get onbWelcomeTitle => 'הזמן המת שלך יכול להפוך לשיחה טובה';

  @override
  String get onbWelcomeBody =>
      'בנסיעה, בהליכה או בהפסקה — נמצא את האדם הנכון לדבר איתו דווקא עכשיו.';

  @override
  String get onbHowTitle => 'איך זה עובד';

  @override
  String get onbHow1 => 'מסמנים שפנויים, ולכמה זמן.';

  @override
  String get onbHow2 => 'מקבלים כמה הצעות מתאימות — עם הסבר למה כל אחת.';

  @override
  String get onbHow3 =>
      'שיחה מתחילה רק כשגם הצד השני מסכים, או עם מי ששניכם סימנתם מראש ל\"חיבור מהיר\".';

  @override
  String get onbPrivacyTitle => 'פרטיות ובטיחות';

  @override
  String get onbPrivacy1 => 'לא משתפים מיקום, מסלול או מהירות — עם אף אחד.';

  @override
  String get onbPrivacy2 => 'שיחות לא מוקלטות ולא מתומללות.';

  @override
  String get onbPrivacy3 =>
      'בנהיגה — רק דיבורית ומתקן לרכב. אפשר לענות \"כן\" או \"לא\" בקול.';

  @override
  String get onbSetupTitle => 'כמה פרטים קטנים';

  @override
  String get onbNameLabel => 'איך קוראים לך?';

  @override
  String get onbGenderLabel => 'איך לפנות אליך?';

  @override
  String get genderMale => 'בלשון זכר';

  @override
  String get genderFemale => 'בלשון נקבה';

  @override
  String get genderOther => 'ניטרלי';

  @override
  String get onbAdultCheckbox => 'אני בן/בת 18 ומעלה';

  @override
  String get onbOpennessLabel => 'מה מתאים לך שנציע?';

  @override
  String get onbNext => 'המשך';

  @override
  String get onbStart => 'בואו נתחיל';

  @override
  String get onbPrototypeNote => 'זהו אב-טיפוס: כל האנשים והשיחות מדומים.';

  @override
  String homeGreeting(String name) {
    return 'שלום $name';
  }

  @override
  String get homeGreetingNoName => 'שלום';

  @override
  String get homeStatusUnavailable => 'כרגע לא זמין לשיחות';

  @override
  String homeImFreeNow(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'אני פנויה עכשיו',
      'male': 'אני פנוי עכשיו',
      'other': 'אני פנוי/ה עכשיו',
    });
    return '$_temp0';
  }

  @override
  String homeAvailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים שמתאימים לך פנויים עכשיו',
      one: 'אדם אחד שמתאים לך פנוי עכשיו',
      zero:
          'כרגע אף אחד שמתאים לך לא פנוי — אפשר לסמן זמינות ונשלח הזמנה למעטים',
    );
    return '$_temp0';
  }

  @override
  String get homeRestingTitle => 'הזמינות שלך פעילה';

  @override
  String timeLeftMinutes(int minutes) {
    return 'עוד $minutes דק׳';
  }

  @override
  String get homeFindAnother => 'מצא מישהו לדבר איתו';

  @override
  String get stopAvailability => 'עצור זמינות';

  @override
  String get homeAutoDrivingOn => 'זמינות אוטומטית בנסיעה פעילה';

  @override
  String get pickModeTitle => 'מה המצב?';

  @override
  String get modeDriving => 'נסיעה';

  @override
  String get modeWalking => 'הליכה';

  @override
  String get modeBreak => 'הפסקה';

  @override
  String get modeFree => 'סתם פנוי';

  @override
  String get pickDurationTitle => 'לכמה זמן?';

  @override
  String minutesShort(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String get durationUntilTripEnds => 'עד שאסיים את הנסיעה';

  @override
  String durationTripNote(int hours) {
    return 'מסתיים ביציאה מהרכב, ולכל היותר אחרי $hours שעות.';
  }

  @override
  String get searchingTitle => 'מחפשים מישהו שמתאים לדבר איתך עכשיו';

  @override
  String get searchingNoOneYet =>
      'אם אף אחד לא פנוי, נשלח הודעה לכמה אנשים שעשויים להתאים.';

  @override
  String beaconSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'אף אחד לא פנוי בדיוק עכשיו, אז שלחנו הודעה ל-$count אנשים שעשויים להתאים.',
      one: 'אף אחד לא פנוי בדיוק עכשיו, אז שלחנו הודעה לאדם אחד שעשוי להתאים.',
      zero: 'אף אחד לא פנוי בדיוק עכשיו. נמשיך לחפש כל עוד את/ה זמין/ה.',
    );
    return '$_temp0';
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
  String get explorationBadge => 'הפתעה קטנה';

  @override
  String get talkNow => 'לדבר עכשיו';

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
  String get unmatch => 'הסרה מהקשרים';

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
  String reasonAvailable(String name, String gender, int minutes) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'פנויה',
      'male': 'פנוי',
      'other': 'פנוי/ה',
    });
    return '$name $_temp0 עכשיו לעוד כ-$minutes דקות';
  }

  @override
  String reasonDormant(String duration) {
    return 'לא דיברתם כאן $duration';
  }

  @override
  String get reasonNeverTalked => 'עוד לא דיברתם כאן אף פעם';

  @override
  String reasonMutualFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יש לכם $count חברים משותפים',
      one: 'יש לכם חבר משותף',
    );
    return '$_temp0';
  }

  @override
  String reasonSharedGroup(String group) {
    return 'שניכם בקבוצה \"$group\"';
  }

  @override
  String reasonSharedInterests(String interests) {
    return 'לשניכם יש עניין ב$interests';
  }

  @override
  String get reasonBothFof => 'שניכם פתוחים להכיר חברים של חברים';

  @override
  String get reasonEnjoyedLastTime => 'בפעם הקודמת נהניתם מהשיחה';

  @override
  String reasonAnswered(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'אישרה',
      'male': 'אישר',
      'other': 'אישר/ה',
    });
    return '$name $_temp0 שמתאים לדבר עכשיו';
  }

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
  String waitingTitle(String name) {
    return 'שאלנו את $name אם מתאים לדבר עכשיו';
  }

  @override
  String get waitingSubtitle => 'השיחה תתחיל רק אחרי אישור';

  @override
  String get cancel => 'ביטול';

  @override
  String noticeDeclined(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'לא יכולה',
      'male': 'לא יכול',
      'other': 'לא יכול/ה',
    });
    return '$name $_temp0 עכשיו. אפשר להשאיר הודעה קולית.';
  }

  @override
  String get noticeAvailabilityEnded => 'זמן הזמינות הסתיים';

  @override
  String noticeInvitationMuted(int hours) {
    return 'השתקנו הזמנות כאלה ל-$hours שעות';
  }

  @override
  String noticeBlocked(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'נחסמה',
      'male': 'נחסם',
      'other': 'נחסם/ה',
    });
    return '$name $_temp0';
  }

  @override
  String get noticeReported => 'תודה, הדיווח התקבל';

  @override
  String noticePausedToday(String name) {
    return 'לא נציע את $name היום';
  }

  @override
  String noticePausedWhile(String name) {
    return 'לא נציע את $name בתקופה הקרובה';
  }

  @override
  String get callSimulated => 'סימולציה — אין שיחה אמיתית בשלב זה';

  @override
  String get callMute => 'השתק';

  @override
  String get callUnmute => 'בטל השתקה';

  @override
  String get callEnd => 'סיום';

  @override
  String get callAudioOnly => 'שיחת קול בלבד · לא מוקלטת';

  @override
  String feedbackQuestion(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'שמחה',
      'male': 'שמח',
      'other': 'שמח/ה',
    });
    return '$_temp0 שדיברתם?';
  }

  @override
  String get feedbackVeryGood => 'מאוד';

  @override
  String get feedbackGood => 'כן';

  @override
  String get feedbackNotReally => 'לא במיוחד';

  @override
  String get feedbackAgainQuestion => 'שנחבר ביניכם שוב בעתיד?';

  @override
  String get yes => 'כן';

  @override
  String get no => 'לא';

  @override
  String get skip => 'דלג';

  @override
  String invitationText(String name, String gender, int minutes) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'פנויה',
      'male': 'פנוי',
      'other': 'פנוי/ה',
    });
    return '$name $_temp0 עכשיו לכ-$minutes דקות. מתאים לך לדבר?';
  }

  @override
  String get invitationNotNow => 'לא עכשיו';

  @override
  String invitationMute(int hours) {
    return 'להשתיק הצעות כאלה ל-$hours שעות';
  }

  @override
  String get driverSearching => 'מחפשים...';

  @override
  String get driverCall => 'שיחה';

  @override
  String get driverNext => 'הבא';

  @override
  String get driverStop => 'עצור';

  @override
  String driverWaiting(String name) {
    return 'מחכים לאישור של $name';
  }

  @override
  String get driverInVehicle => 'נראה שהמכשיר ברכב';

  @override
  String get driverBecomeAvailable => 'זמין לשיחה';

  @override
  String get driverFindAnother => 'שיחה נוספת';

  @override
  String get driverSafety => 'בנהיגה: רק דיבורית ומתקן לרכב';

  @override
  String get driverNotNow => 'לא עכשיו';

  @override
  String get connTabClose => 'קרובים';

  @override
  String get connTabReconnect => 'לחדש קשר';

  @override
  String get connTabColleagues => 'קולגות ומכרים';

  @override
  String get connTabFof => 'חברים של חברים';

  @override
  String connLastTalked(String duration) {
    return 'דיברתם כאן לפני $duration';
  }

  @override
  String get connLastTalkedToday => 'דיברתם כאן היום';

  @override
  String get connNeverTalked => 'עוד לא דיברתם כאן';

  @override
  String get connEmpty => 'אין כאן אף אחד כרגע';

  @override
  String get connFofOff =>
      'כדי לראות חברים של חברים, צריך להפעיל את האפשרות במסך גילוי. יופיעו רק מי שגם הפעילו אותה.';

  @override
  String get addFriend => 'הוספת חבר';

  @override
  String get addFriendInviteLink => 'קישור הזמנה';

  @override
  String get addFriendInviteLinkBody =>
      'שולחים את הקישור למי שרוצים. אחרי שיצטרפו — תהיו מחוברים.';

  @override
  String get addFriendCopy => 'העתק קישור';

  @override
  String get addFriendCopied => 'הקישור הועתק (קישור לדוגמה בלבד)';

  @override
  String get addFriendQrSoon => 'קוד QR יתווסף בהמשך';

  @override
  String get addFriendSearch => 'חיפוש לפי שם';

  @override
  String get addFriendAdd => 'הוסף';

  @override
  String get addFriendConnected => 'מחובר';

  @override
  String get addFriendGroups => 'קבוצות הזמנה';

  @override
  String get addFriendGroupInvite => 'הזמן לקבוצה';

  @override
  String mutualFriendsShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חברים משותפים',
      one: 'חבר משותף אחד',
      zero: 'אין חברים משותפים',
    );
    return '$_temp0';
  }

  @override
  String get personRelationship => 'סוג הקשר (לא חובה)';

  @override
  String personCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שיחות כאן',
      one: 'שיחה אחת כאן',
      zero: 'עוד לא דיברתם כאן',
    );
    return '$_temp0';
  }

  @override
  String personPausedUntil(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'לא יוצע עד $dateString';
  }

  @override
  String get personAllow => 'להציע שוב';

  @override
  String personUnmatchConfirm(String name) {
    return 'להסיר את $name מהקשרים? אפשר יהיה להתחבר שוב רק בהזמנה חדשה.';
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
  String get discoverIntro =>
      'כאן קובעים כמה פתוח להיות. כל רמה פועלת רק אם גם הצד השני בחר בה.';

  @override
  String get discoverFofTitle => 'פתוח להצעות של חברים של חברים';

  @override
  String get discoverFofBody =>
      'תוצעו זה לזה רק אם שניכם הפעלתם. נציג כמה חברים משותפים יש לכם — בלי שמות.';

  @override
  String get discoverInterests => 'תחומי עניין';

  @override
  String get discoverInterestsBody => 'עוזרים להתאמה ולהסבר למה מישהו הוצע.';

  @override
  String get discoverLanguages => 'שפות שיחה';

  @override
  String get langHe => 'עברית';

  @override
  String get langEn => 'אנגלית';

  @override
  String get settingsDriving => 'נסיעה';

  @override
  String get settingsAutoDriving => 'זמינות אוטומטית בנסיעה';

  @override
  String get settingsAutoDrivingBody =>
      'כשנזהה שהמכשיר כנראה ברכב, נסמן אותך כזמין. שיחה מתחילה רק באישור — או בחיבור מהיר ששניכם סימנתם מראש.';

  @override
  String get settingsAutoDrivingDialogTitle => 'לפני שמפעילים';

  @override
  String get settingsAutoDrivingDialogBody =>
      '• זמינות אוטומטית היא לא אישור לשיחה — שיחה דורשת אישור של שני הצדדים, או חיבור מהיר ששניכם סימנתם מראש.\n• הזיהוי נעשה בטלפון בלבד. לא נשלח מיקום.\n• המערכת יודעת רק שהמכשיר כנראה ברכב — לא מי נוהג.\n• באב-הטיפוס, הנסיעה מדומה דרך כלי המפתחים.';

  @override
  String get enable => 'הפעל';

  @override
  String get settingsCarBluetooth => 'Bluetooth של הרכב';

  @override
  String get settingsCarBluetoothSoon =>
      'יתווסף בשלב 4 — לזיהוי בביטחון גבוה יותר';

  @override
  String get settingsRelPrefs => 'את מי להציע לי';

  @override
  String get settingsNotifications => 'הזמנות מאחרים';

  @override
  String get beaconOff => 'לא לשלוח לי הזמנות';

  @override
  String get beaconLow => 'מעט — עד הזמנה אחת ביום מכל אדם';

  @override
  String get beaconNormal => 'רגיל — עד שתיים ביום מכל אדם';

  @override
  String settingsMutedUntil(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hm(localeName);
    final String timeString = timeDateFormat.format(time);

    return 'מושתק עד $timeString';
  }

  @override
  String get unmute => 'בטל השתקה';

  @override
  String get settingsPrivacy => 'פרטיות';

  @override
  String get privacyTitle => 'מה אנחנו יודעים ומה לא';

  @override
  String get privacyShared =>
      'מה רואים אחרים: שם, תמונה, שאת/ה זמין/ה ולכמה זמן. מספר הטלפון שלך משמש רק לחיוג אחרי ששניכם הסכמתם — וחברים של חברים מקבלים אותו רק אם אישרת.';

  @override
  String get privacyServer =>
      'מה השרת יודע: זמין/לא זמין, מצב (למשל נסיעה) ועד מתי.';

  @override
  String get privacyNever =>
      'מה לא נשמר ולא משותף: מיקום, מסלול, מהירות, הקלטות, תמלולים, יומן השיחות ואנשי הקשר בטלפון.';

  @override
  String get privacyLocal => 'זיהוי נסיעה נעשה בטלפון עצמו.';

  @override
  String get privacyExpiry =>
      'לזמינות יש תמיד זמן סיום — גם אם האפליקציה נסגרת.';

  @override
  String get settingsBlocked => 'משתמשים חסומים';

  @override
  String get blockedEmpty => 'אין משתמשים חסומים';

  @override
  String get unblock => 'בטל חסימה';

  @override
  String get settingsDevTools => 'כלי מפתחים';

  @override
  String get settingsAbout => 'אב-טיפוס · שלב 1 · כל הנתונים מדומים';

  @override
  String get debugTitle => 'כלי מפתחים';

  @override
  String get debugSubtitle => 'לא יופיע בגרסה לחנות';

  @override
  String get debugVehicle => 'רכב';

  @override
  String get debugEnterVehicle => 'נכנסתי לרכב';

  @override
  String get debugEnterVehicleBt => 'נכנסתי לרכב + Bluetooth';

  @override
  String get debugExitVehicle => 'יצאתי מהרכב';

  @override
  String get debugInVehicleYes => 'מצב: המכשיר כנראה ברכב';

  @override
  String get debugInVehicleNo => 'מצב: לא ברכב';

  @override
  String get debugAutoOffWarning =>
      'זמינות אוטומטית כבויה בהגדרות — כניסה לרכב רק תעביר למצב נהג.';

  @override
  String get debugTime => 'זמן';

  @override
  String debugFakeClock(String date, String time) {
    return '$date $time';
  }

  @override
  String get debugResetTime => 'אפס זמן';

  @override
  String get debugPlus5m => '5 דק׳ קדימה';

  @override
  String get debugPlus15m => '15 דק׳ קדימה';

  @override
  String get debugPlus1h => 'שעה קדימה';

  @override
  String get debugPlus1d => 'יום קדימה';

  @override
  String get debugPlus30d => '30 יום קדימה';

  @override
  String get debugMatching => 'התאמות';

  @override
  String get debugSimulateMatch => 'דמה התאמה';

  @override
  String get debugForceNoMatch => 'דמה אין-התאמה';

  @override
  String get debugEveryoneUnavailable => 'כולם לא זמינים';

  @override
  String get debugAnswers => 'תשובת הצד השני';

  @override
  String get debugAnswerAuto => 'לפי הסתברות';

  @override
  String get debugAnswerAccept => 'תמיד מאשר';

  @override
  String get debugAnswerDecline => 'תמיד דוחה';

  @override
  String get debugInvitation => 'הזמנה נכנסת';

  @override
  String get debugSimulateInvitation => 'דמה הזמנה נכנסת';

  @override
  String get debugInvitationMuted => 'ההזמנה לא נמסרה — הזמנות מושתקות בהגדרות';

  @override
  String get debugWhoIsFree => 'מי פנוי';

  @override
  String get debugNotAvailable => 'לא פנוי';

  @override
  String get debugInspector => 'מנוע ההתאמה — מאחורי הקלעים';

  @override
  String get debugInspectorNote =>
      'מבוסס על המצב הנוכחי. אנשים שלא זמינים מופיעים כאן בדירוג להזמנות.';

  @override
  String get debugInspectorRanked => 'מדורגים';

  @override
  String get debugInspectorRejected => 'סוננו';

  @override
  String debugScore(String score) {
    return 'ציון $score';
  }

  @override
  String get filterBlocked => 'חסום';

  @override
  String get filterSkipped => 'דולג בחלון הנוכחי';

  @override
  String get filterSafety => 'מגבלת בטיחות';

  @override
  String get filterNotToday => 'לא היום';

  @override
  String get filterDoNotSuggest => 'לא להציע בתקופה הקרובה';

  @override
  String get filterRelExcluded => 'סוג קשר שביקשת לא להציע';

  @override
  String get filterLanguage => 'אין שפה משותפת';

  @override
  String get filterNotAvailable => 'לא זמין עכשיו';

  @override
  String get filterFof => 'חבר של חבר — לא שניכם הפעלתם';

  @override
  String get filterTier => 'רמת התאמה שלא שניכם פתוחים אליה';

  @override
  String get featCloseness => 'קרבה';

  @override
  String get featDormancy => 'זמן מאז שיחה';

  @override
  String get featAvailableNow => 'זמין עכשיו';

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
  String get debugAnalytics => 'מדדים (נשמרים במכשיר בלבד)';

  @override
  String get debugAnalyticsEmpty => 'עוד אין אירועים';

  @override
  String get debugReset => 'אפס את כל הנתונים';

  @override
  String get debugResetDone => 'הנתונים אופסו';

  @override
  String optionsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים פנויים לדבר עכשיו',
      one: 'מישהו פנוי לדבר עכשיו',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'אפשרויות נוספות';

  @override
  String get talkNowAccepted => 'לדבר — כבר אישר/ה';

  @override
  String starterLine(String text) {
    return 'נושא לפתיחה: $text';
  }

  @override
  String routineDue(String mode, int minutes) {
    return 'זה הזמן הרגיל שלך ל$mode. להיות זמין ל-$minutes דק׳?';
  }

  @override
  String get routineStart => 'כן';

  @override
  String get availableTo => 'זמין ל:';

  @override
  String get availableToEveryone => 'כולם';

  @override
  String get driverListening => 'מקשיב… אפשר לומר \"כן\" או \"לא\"';

  @override
  String quickConnectTitle(String name) {
    return 'מתקשרים ל$name';
  }

  @override
  String quickConnectIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'בעוד $seconds שניות',
      one: 'בעוד שנייה',
      zero: 'מחייג…',
    );
    return '$_temp0';
  }

  @override
  String get quickConnectWhy =>
      'חיבור מהיר — שניכם אישרתם מראש. אפשר לבטל עכשיו או לומר \"בטל\".';

  @override
  String get voiceMessageSimulated => 'הדמיה — שום דבר לא מוקלט או נשלח';

  @override
  String voiceMessageTitle(String name) {
    return 'הודעה קולית ל$name';
  }

  @override
  String voiceMessageHint(int max) {
    return 'עד $max שניות. למשל: \"היי, חשבתי עליך, נדבר בקרוב\".';
  }

  @override
  String get voiceMessageSend => 'שליחה';

  @override
  String get voiceMessageAction => 'הודעה קולית';

  @override
  String get callViaPhone => 'שיחת טלפון רגילה';

  @override
  String get callInApp => 'שיחה באפליקציה · המספרים נשארים פרטיים';

  @override
  String get callWeakSignal => 'קליטה חלשה';

  @override
  String get callWindowEndedKeepTalking =>
      'זמן הזמינות הסתיים — השיחה ממשיכה כרגיל';

  @override
  String callPhoneSimulated(String name) {
    return 'באפליקציה האמיתית, הטלפון היה מחייג עכשיו ל$name בשיחה רגילה. כאן זו הדמיה.';
  }

  @override
  String get callDialTestNumber => 'חייג באמת למספר הבדיקה';

  @override
  String get callDialUnsupported => 'אי אפשר לחייג מכאן (למשל בדפדפן)';

  @override
  String get callSetTestNumberHint =>
      'אפשר להגדיר מספר לבדיקת חיוג אמיתי בכלי המפתחים';

  @override
  String get callDropped => 'השיחה נותקה';

  @override
  String get callRetry => 'לנסות שוב';

  @override
  String get callOnHold => 'השיחה בהמתנה — נכנסה שיחת טלפון';

  @override
  String get callResume => 'להמשיך';

  @override
  String get callWeAreDone => 'סיימנו';

  @override
  String get feedbackDidNotTalk => 'לא דיברנו בסוף';

  @override
  String get offlineBanner => 'אין חיבור לאינטרנט — ננסה שוב אוטומטית';

  @override
  String noticeNoAnswer(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'לא ענתה',
      'male': 'לא ענה',
      'other': 'לא ענה/תה',
    });
    return '$name $_temp0. אפשר להשאיר הודעה קולית.';
  }

  @override
  String noticeNoLongerAvailable(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'לא פנויה',
      'male': 'לא פנוי',
      'other': 'לא פנוי/ה',
    });
    return '$name כבר $_temp0. ממשיכים.';
  }

  @override
  String noticeVoiceMessageSent(String name) {
    return 'ההודעה ל$name נשלחה (הדמיה)';
  }

  @override
  String get noticeMicDenied =>
      'אין הרשאת מיקרופון, אז אי אפשר לענות בקול. אפשר לאשר בהגדרות הטלפון ‹ אפליקציות ‹ DriveTalk ‹ הרשאות. הכפתורים תמיד עובדים.';

  @override
  String noticeQuickConnectCancelled(String name) {
    return 'בוטל. לא נתקשר ל$name עכשיו.';
  }

  @override
  String voiceQuickConnect(String name, int seconds) {
    return 'מתקשרים ל$name בעוד $seconds שניות. לביטול אמרו \"בטל\".';
  }

  @override
  String voiceInvitation(String name, String gender, int minutes) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'פנויה',
      'male': 'פנוי',
      'other': 'פנוי/ה',
    });
    return '$name $_temp0 לכ-$minutes דקות. לדבר?';
  }

  @override
  String voiceSuggestion(String name, String gender, int minutes, String who) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'פנויה',
      'male': 'פנוי',
      'other': 'פנוי/ה',
    });
    return '$name, $who, $_temp0 לעוד כ-$minutes דקות. לדבר?';
  }

  @override
  String get settingsProfile => 'הפרופיל שלי';

  @override
  String get photoFromGallery => 'מהגלריה';

  @override
  String get photoFromCamera => 'צילום';

  @override
  String get photoRemove => 'הסרה';

  @override
  String get photoPrivacyNote =>
      'באב-הטיפוס התמונה נשמרת רק בטלפון הזה. בגרסה האמיתית תמונות ייבדקו לפני שיוצגו לאחרים.';

  @override
  String get myPhoneNumber => 'המספר שלי';

  @override
  String get myPhoneNumberHelp =>
      'משמש רק לחיוג רגיל אחרי ששניכם הסכמתם. לא מוצג לאף אחד על המסך.';

  @override
  String get shareNumberWithFof => 'לאפשר חיוג רגיל גם עם חברים של חברים';

  @override
  String get shareNumberWithFofBody =>
      'רק אם גם הצד השני הסכים. אחרת השיחה איתם תהיה בתוך האפליקציה, והמספרים יישארו פרטיים.';

  @override
  String get settingsVoiceReadout => 'הקראה בקול בנסיעה';

  @override
  String get settingsVoiceReadoutBody => 'הטלפון מקריא מי פנוי ושואל אם לדבר';

  @override
  String get settingsVoiceCommands => 'לענות \"כן\" / \"לא\" בקול';

  @override
  String get settingsVoiceCommandsBody =>
      'דורש הרשאת מיקרופון. הזיהוי נעשה דרך הטלפון ושום דבר לא נשמר.';

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
  String get routinesIntro =>
      'ספרו לנו מתי אתם בדרך כלל בדרכים. בזמנים האלה נציע בלחיצה אחת להפוך לזמינים.';

  @override
  String get routinesEmpty => 'עוד אין זמנים קבועים';

  @override
  String get routineAdd => 'הוספת זמן קבוע';

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
  String get circlesTitle => 'המעגלים שלי';

  @override
  String circlesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מעגלים',
      one: 'מעגל אחד',
      zero: 'אין מעגלים',
    );
    return '$_temp0';
  }

  @override
  String get circlesIntro =>
      'מעגלים פרטיים שרק את/ה רואה. כשנהיים זמינים אפשר לבחור להיות זמינים רק למעגל אחד.';

  @override
  String get circleAdd => 'מעגל חדש';

  @override
  String circleMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count אנשים',
      one: 'אדם אחד',
      zero: 'אין חברים במעגל',
    );
    return '$_temp0';
  }

  @override
  String get circleDelete => 'מחיקת המעגל';

  @override
  String get circleNameHint => 'למשל: חברים מהצבא';

  @override
  String get filterNotInCircle => 'לא במעגל שבחרת';

  @override
  String get quickConnectToggle => 'חיבור מהיר';

  @override
  String quickConnectExplain(String name) {
    return 'כששניכם פנויים — מתקשרים מיד, בלי לחכות לאישור (עם 5 שניות לביטול). עובד רק אם גם $name יסמן אותך.';
  }

  @override
  String quickConnectMutual(String name) {
    return 'פעיל — גם $name סימן אותך.';
  }

  @override
  String quickConnectWaiting(String name) {
    return 'סימנת. יופעל כשגם $name יסמן אותך.';
  }

  @override
  String get debugScenarios => 'תרחישי תקלות והפרעות';

  @override
  String get debugVoice => 'קול';

  @override
  String get debugVoiceBody =>
      'בדפדפן אין מיקרופון — כאן אפשר לדמות תשובה קולית במצב נהג.';

  @override
  String get debugVoiceYes => 'דמה \"כן\"';

  @override
  String get debugVoiceNo => 'דמה \"לא\"';

  @override
  String get debugTestDial => 'חיוג אמיתי לבדיקה';

  @override
  String get debugTestDialLabel => 'מספר לבדיקה (למשל המספר שלך)';

  @override
  String get debugTestDialHelp =>
      'האנשים המדומים לעולם לא מחויגים. מספר שתכתוב כאן יופיע כאפשרות \"חייג באמת\" במסך השיחה.';

  @override
  String get debugAnswerNone => 'לא עונה';

  @override
  String get scRun => 'הפעל';

  @override
  String get scNoAnswerTitle => 'הצד השני לא עונה';

  @override
  String get scNoAnswerBody =>
      'לחצו \"לדבר\" על מישהו — אחרי 30 שניות בלי תשובה ממשיכים הלאה.';

  @override
  String get scNoAnswerArmed =>
      'מעכשיו אף אחד לא עונה. אפשר להחזיר ב\"תשובת הצד השני\".';

  @override
  String get scGoneTitle => 'הפסיק להיות זמין בזמן ההמתנה';

  @override
  String get scGoneBody => 'זמין בזמן שמחכים לתשובה.';

  @override
  String get scBlockedTitle => 'חסם אותי בזמן ההמתנה';

  @override
  String get scBlockedBody =>
      'זמין בזמן שמחכים. נראה כמו \"לא יכול עכשיו\" — בלי לחשוף.';

  @override
  String get scInviteWhileWaitingTitle => 'הזמנה נכנסת בזמן המתנה';

  @override
  String get scInviteWhileWaitingBody =>
      'זמין בזמן שמחכים. אפשר לבחור בהזמנה במקום.';

  @override
  String get scDroppedTitle => 'השיחה נותקה';

  @override
  String get scDroppedBody =>
      'זמין בשיחה בתוך האפליקציה (עם חבר של חבר שלא שיתף מספר).';

  @override
  String get scHoldTitle => 'שיחת טלפון נכנסת באמצע';

  @override
  String get scHoldBody => 'זמין בשיחה בתוך האפליקציה. השיחה עוברת להמתנה.';

  @override
  String get scWeakSignalTitle => 'קליטה חלשה';

  @override
  String get scWeakSignalOff => 'להחזיר קליטה טובה';

  @override
  String get scWeakSignalBody => 'מופיע סימן קטן בשיחה בתוך האפליקציה.';

  @override
  String get scExpireInCallTitle => 'הזמינות נגמרת באמצע שיחה';

  @override
  String get scExpireInCallBody =>
      'זמין בשיחה. השיחה ממשיכה, הזמינות נסגרת אחריה.';

  @override
  String get scExitCarInCallTitle => 'יציאה מהרכב באמצע שיחה';

  @override
  String get scExitCarInCallBody =>
      'זמין בשיחה. מצב הנהג נגמר רק כשהשיחה מסתיימת.';

  @override
  String get scEnterCarChoosingTitle => 'כניסה לרכב בזמן בחירה';

  @override
  String get scEnterCarChoosingBody =>
      'זמין כשמוצגות אפשרויות. עוברים מיד למצב נהג.';

  @override
  String get scOfflineTitle => 'אין אינטרנט';

  @override
  String get scOfflineOff => 'להחזיר אינטרנט';

  @override
  String get scOfflineBody => 'מופיע פס עליון והחיפוש ממתין עד שהחיבור חוזר.';

  @override
  String get scMicDeniedTitle => 'אין הרשאת מיקרופון';

  @override
  String get scMicDeniedBody => 'מוצג הסבר איך לאשר. הכפתורים ממשיכים לעבוד.';

  @override
  String get scAppClosedTitle => 'האפליקציה נסגרה לכמה שעות';

  @override
  String get scAppClosedBody =>
      'הזמינות נגמרת לבד — אף אחד לא נשאר \"זמין\" לנצח.';

  @override
  String get scQuickConnectTitle => 'חיבור מהיר עם אבא';

  @override
  String get scQuickConnectBody =>
      'אבא נהיה פנוי. אם גם את/ה זמין/ה — מתחילה ספירה של 5 שניות עם ביטול.';

  @override
  String get scQuickConnectHint => 'קודם להפוך לזמין/ה, ואז להפעיל שוב.';
}
