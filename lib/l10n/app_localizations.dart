import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('he')];

  /// No description provided for @tabHome.
  ///
  /// In he, this message translates to:
  /// **'בית'**
  String get tabHome;

  /// No description provided for @tabSettings.
  ///
  /// In he, this message translates to:
  /// **'הגדרות'**
  String get tabSettings;

  /// No description provided for @onbNameLabel.
  ///
  /// In he, this message translates to:
  /// **'איך קוראים לך?'**
  String get onbNameLabel;

  /// No description provided for @homeGreetingNoName.
  ///
  /// In he, this message translates to:
  /// **'שלום'**
  String get homeGreetingNoName;

  /// No description provided for @homeImFreeNow.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{יש לך כמה דקות לשיחה?} male{יש לך כמה דקות לשיחה?} other{יש לך כמה דקות לשיחה?}}'**
  String homeImFreeNow(String gender);

  /// No description provided for @timeLeftMinutes.
  ///
  /// In he, this message translates to:
  /// **'עוד {minutes} דק׳'**
  String timeLeftMinutes(int minutes);

  /// No description provided for @stopAvailability.
  ///
  /// In he, this message translates to:
  /// **'לעצור זמינות'**
  String get stopAvailability;

  /// No description provided for @modeDriving.
  ///
  /// In he, this message translates to:
  /// **'נסיעה'**
  String get modeDriving;

  /// No description provided for @modeWalking.
  ///
  /// In he, this message translates to:
  /// **'הליכה'**
  String get modeWalking;

  /// No description provided for @modeBreak.
  ///
  /// In he, this message translates to:
  /// **'הפסקה'**
  String get modeBreak;

  /// No description provided for @modeFree.
  ///
  /// In he, this message translates to:
  /// **'סתם זמן פנוי'**
  String get modeFree;

  /// No description provided for @pickDurationTitle.
  ///
  /// In he, this message translates to:
  /// **'לכמה זמן?'**
  String get pickDurationTitle;

  /// No description provided for @minutesShort.
  ///
  /// In he, this message translates to:
  /// **'{minutes} דק׳'**
  String minutesShort(int minutes);

  /// No description provided for @durationUntilTripEnds.
  ///
  /// In he, this message translates to:
  /// **'לכל הנסיעה'**
  String get durationUntilTripEnds;

  /// No description provided for @durationTripNote.
  ///
  /// In he, this message translates to:
  /// **'נשאר עד {hours} שעות, או עד שלוחצים \"לעצור\".'**
  String durationTripNote(int hours);

  /// No description provided for @tierFamiliar.
  ///
  /// In he, this message translates to:
  /// **'מוכר'**
  String get tierFamiliar;

  /// No description provided for @tierReconnect.
  ///
  /// In he, this message translates to:
  /// **'לחדש קשר'**
  String get tierReconnect;

  /// No description provided for @tierWiden.
  ///
  /// In he, this message translates to:
  /// **'להרחיב מעגל'**
  String get tierWiden;

  /// No description provided for @tierSurprise.
  ///
  /// In he, this message translates to:
  /// **'הפתע אותי'**
  String get tierSurprise;

  /// No description provided for @tierFamiliarDesc.
  ///
  /// In he, this message translates to:
  /// **'חברים קרובים, משפחה ואנשים שכבר בקשר איתך'**
  String get tierFamiliarDesc;

  /// No description provided for @tierReconnectDesc.
  ///
  /// In he, this message translates to:
  /// **'אנשים שמכירים, אבל לא דיברתם כאן הרבה זמן'**
  String get tierReconnectDesc;

  /// No description provided for @tierWidenDesc.
  ///
  /// In he, this message translates to:
  /// **'מכרים, קולגות וחברים של חברים'**
  String get tierWidenDesc;

  /// No description provided for @tierSurpriseDesc.
  ///
  /// In he, this message translates to:
  /// **'הפתעה מבוקרת: חבר של חבר או קבוצה משותפת — תמיד עם הסבר'**
  String get tierSurpriseDesc;

  /// No description provided for @next.
  ///
  /// In he, this message translates to:
  /// **'הבא'**
  String get next;

  /// No description provided for @notToday.
  ///
  /// In he, this message translates to:
  /// **'לא היום'**
  String get notToday;

  /// No description provided for @doNotSuggest.
  ///
  /// In he, this message translates to:
  /// **'לא להציע בתקופה הקרובה'**
  String get doNotSuggest;

  /// No description provided for @more.
  ///
  /// In he, this message translates to:
  /// **'עוד'**
  String get more;

  /// No description provided for @block.
  ///
  /// In he, this message translates to:
  /// **'חסימה'**
  String get block;

  /// No description provided for @report.
  ///
  /// In he, this message translates to:
  /// **'דיווח'**
  String get report;

  /// No description provided for @unmatch.
  ///
  /// In he, this message translates to:
  /// **'הסרה מהרשימה'**
  String get unmatch;

  /// No description provided for @relFamily.
  ///
  /// In he, this message translates to:
  /// **'משפחה'**
  String get relFamily;

  /// No description provided for @relCloseFriend.
  ///
  /// In he, this message translates to:
  /// **'חבר/ה קרוב/ה'**
  String get relCloseFriend;

  /// No description provided for @relFriend.
  ///
  /// In he, this message translates to:
  /// **'חבר/ה'**
  String get relFriend;

  /// No description provided for @relChildhoodFriend.
  ///
  /// In he, this message translates to:
  /// **'חבר/ת ילדות'**
  String get relChildhoodFriend;

  /// No description provided for @relColleague.
  ///
  /// In he, this message translates to:
  /// **'קולגה'**
  String get relColleague;

  /// No description provided for @relFormerColleague.
  ///
  /// In he, this message translates to:
  /// **'קולגה לשעבר'**
  String get relFormerColleague;

  /// No description provided for @relAcquaintance.
  ///
  /// In he, this message translates to:
  /// **'מכר/ה'**
  String get relAcquaintance;

  /// No description provided for @relFriendOfFriend.
  ///
  /// In he, this message translates to:
  /// **'חבר/ה של חברים'**
  String get relFriendOfFriend;

  /// No description provided for @relSharedGroup.
  ///
  /// In he, this message translates to:
  /// **'מקבוצה משותפת'**
  String get relSharedGroup;

  /// No description provided for @relUnclassified.
  ///
  /// In he, this message translates to:
  /// **'קשר'**
  String get relUnclassified;

  /// No description provided for @relNone.
  ///
  /// In he, this message translates to:
  /// **'ללא סיווג'**
  String get relNone;

  /// No description provided for @durationDays.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{יום} =2{יומיים} other{{count} ימים}}'**
  String durationDays(int count);

  /// No description provided for @durationMonths.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{חודש} =2{חודשיים} other{{count} חודשים}}'**
  String durationMonths(int count);

  /// No description provided for @durationYearPlus.
  ///
  /// In he, this message translates to:
  /// **'יותר משנה'**
  String get durationYearPlus;

  /// No description provided for @listAnd.
  ///
  /// In he, this message translates to:
  /// **' ו'**
  String get listAnd;

  /// No description provided for @cancel.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get cancel;

  /// No description provided for @noticeBlocked.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} ברשימת החסומים} male{{name} ברשימת החסומים} other{{name} ברשימת החסומים}}'**
  String noticeBlocked(String name, String gender);

  /// No description provided for @noticeReported.
  ///
  /// In he, this message translates to:
  /// **'תודה, הדיווח התקבל'**
  String get noticeReported;

  /// No description provided for @yes.
  ///
  /// In he, this message translates to:
  /// **'כן'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In he, this message translates to:
  /// **'לא'**
  String get no;

  /// No description provided for @skip.
  ///
  /// In he, this message translates to:
  /// **'לדלג'**
  String get skip;

  /// No description provided for @driverStop.
  ///
  /// In he, this message translates to:
  /// **'לעצור'**
  String get driverStop;

  /// No description provided for @driverSafety.
  ///
  /// In he, this message translates to:
  /// **'בנהיגה: רק דיבורית ומתקן לרכב'**
  String get driverSafety;

  /// No description provided for @personUnmatchConfirm.
  ///
  /// In he, this message translates to:
  /// **'להסיר את {name} מהרשימה? אפשר להחזיר בכל רגע ב\"אנשים שהסרתי\".'**
  String personUnmatchConfirm(String name);

  /// No description provided for @personBlockConfirm.
  ///
  /// In he, this message translates to:
  /// **'לחסום את {name}? לא תוצעו זה לזה ולא תוכלו לדבר.'**
  String personBlockConfirm(String name);

  /// No description provided for @confirm.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get confirm;

  /// No description provided for @reportTitle.
  ///
  /// In he, this message translates to:
  /// **'דיווח על {name}'**
  String reportTitle(String name);

  /// No description provided for @reportInappropriate.
  ///
  /// In he, this message translates to:
  /// **'התנהגות לא הולמת'**
  String get reportInappropriate;

  /// No description provided for @reportHarassment.
  ///
  /// In he, this message translates to:
  /// **'הטרדה'**
  String get reportHarassment;

  /// No description provided for @reportSpam.
  ///
  /// In he, this message translates to:
  /// **'ספאם או התחזות'**
  String get reportSpam;

  /// No description provided for @reportUnderage.
  ///
  /// In he, this message translates to:
  /// **'נראה מתחת לגיל 18'**
  String get reportUnderage;

  /// No description provided for @reportOther.
  ///
  /// In he, this message translates to:
  /// **'אחר'**
  String get reportOther;

  /// No description provided for @reportAlsoBlock.
  ///
  /// In he, this message translates to:
  /// **'גם לחסום'**
  String get reportAlsoBlock;

  /// No description provided for @reportSend.
  ///
  /// In he, this message translates to:
  /// **'שליחת דיווח'**
  String get reportSend;

  /// No description provided for @settingsDriving.
  ///
  /// In he, this message translates to:
  /// **'נסיעה'**
  String get settingsDriving;

  /// No description provided for @enable.
  ///
  /// In he, this message translates to:
  /// **'להפעיל'**
  String get enable;

  /// No description provided for @settingsPrivacy.
  ///
  /// In he, this message translates to:
  /// **'פרטיות'**
  String get settingsPrivacy;

  /// No description provided for @unblock.
  ///
  /// In he, this message translates to:
  /// **'לבטל חסימה'**
  String get unblock;

  /// No description provided for @featCloseness.
  ///
  /// In he, this message translates to:
  /// **'קרבה'**
  String get featCloseness;

  /// No description provided for @featDormancy.
  ///
  /// In he, this message translates to:
  /// **'זמן מאז שיחה'**
  String get featDormancy;

  /// No description provided for @featAvailableNow.
  ///
  /// In he, this message translates to:
  /// **'יש זמן עכשיו'**
  String get featAvailableNow;

  /// No description provided for @featOverlap.
  ///
  /// In he, this message translates to:
  /// **'חפיפת זמן'**
  String get featOverlap;

  /// No description provided for @featSharedInterests.
  ///
  /// In he, this message translates to:
  /// **'תחומי עניין'**
  String get featSharedInterests;

  /// No description provided for @featSharedGroup.
  ///
  /// In he, this message translates to:
  /// **'קבוצה משותפת'**
  String get featSharedGroup;

  /// No description provided for @featMutualFriends.
  ///
  /// In he, this message translates to:
  /// **'חברים משותפים'**
  String get featMutualFriends;

  /// No description provided for @featRecentlySuggested.
  ///
  /// In he, this message translates to:
  /// **'הוצע לאחרונה'**
  String get featRecentlySuggested;

  /// No description provided for @featFeedback.
  ///
  /// In he, this message translates to:
  /// **'פידבק קודם'**
  String get featFeedback;

  /// No description provided for @routineDue.
  ///
  /// In he, this message translates to:
  /// **'זה הזמן הרגיל שלך ל{mode}. לסמן זמן פנוי ל-{minutes} דק׳?'**
  String routineDue(String mode, int minutes);

  /// No description provided for @routineStart.
  ///
  /// In he, this message translates to:
  /// **'כן'**
  String get routineStart;

  /// No description provided for @availableTo.
  ///
  /// In he, this message translates to:
  /// **'עם מי מתאים לדבר עכשיו?'**
  String get availableTo;

  /// No description provided for @routineAvailableTo.
  ///
  /// In he, this message translates to:
  /// **'עם מי מתאים לדבר בזמן הזה?'**
  String get routineAvailableTo;

  /// No description provided for @availableToEveryone.
  ///
  /// In he, this message translates to:
  /// **'כרגיל'**
  String get availableToEveryone;

  /// No description provided for @driverListening.
  ///
  /// In he, this message translates to:
  /// **'מקשיבים… אפשר לומר \"כן\" או \"לא\"'**
  String get driverListening;

  /// No description provided for @callWeAreDone.
  ///
  /// In he, this message translates to:
  /// **'סיימנו'**
  String get callWeAreDone;

  /// No description provided for @noticeMicDenied.
  ///
  /// In he, this message translates to:
  /// **'אין הרשאת מיקרופון — עונים בכפתורים. אפשר לאשר בהגדרות הטלפון ← אפליקציות ← DriveBond ← הרשאות.'**
  String get noticeMicDenied;

  /// No description provided for @photoFromGallery.
  ///
  /// In he, this message translates to:
  /// **'מהגלריה'**
  String get photoFromGallery;

  /// No description provided for @photoFromCamera.
  ///
  /// In he, this message translates to:
  /// **'צילום'**
  String get photoFromCamera;

  /// No description provided for @photoRemove.
  ///
  /// In he, this message translates to:
  /// **'הסרה'**
  String get photoRemove;

  /// No description provided for @settingsVoiceReadout.
  ///
  /// In he, this message translates to:
  /// **'הקראה בקול בנסיעה'**
  String get settingsVoiceReadout;

  /// No description provided for @settingsVoiceReadoutBody.
  ///
  /// In he, this message translates to:
  /// **'בנסיעה הטלפון אומר בקול מי פנוי. כשהאפליקציה פתוחה עונים \"כן\" או \"לא\" בקול; אחרת — \"לדבר\" בהתראה.'**
  String get settingsVoiceReadoutBody;

  /// No description provided for @routinesTitle.
  ///
  /// In he, this message translates to:
  /// **'השגרה שלי'**
  String get routinesTitle;

  /// No description provided for @routinesCount.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{עוד לא הוגדרו זמנים קבועים} =1{זמן קבוע אחד} other{{count} זמנים קבועים}}'**
  String routinesCount(int count);

  /// No description provided for @routinesEmpty.
  ///
  /// In he, this message translates to:
  /// **'עוד אין זמנים קבועים'**
  String get routinesEmpty;

  /// No description provided for @routineAdd.
  ///
  /// In he, this message translates to:
  /// **'הוספת זמן קבוע'**
  String get routineAdd;

  /// No description provided for @routineDelete.
  ///
  /// In he, this message translates to:
  /// **'מחיקת השגרה'**
  String get routineDelete;

  /// No description provided for @routineDeleteConfirm.
  ///
  /// In he, this message translates to:
  /// **'למחוק את השגרה הזו?'**
  String get routineDeleteConfirm;

  /// No description provided for @routineDeleteGo.
  ///
  /// In he, this message translates to:
  /// **'למחוק'**
  String get routineDeleteGo;

  /// No description provided for @save.
  ///
  /// In he, this message translates to:
  /// **'שמירה'**
  String get save;

  /// No description provided for @daySun.
  ///
  /// In he, this message translates to:
  /// **'א׳'**
  String get daySun;

  /// No description provided for @dayMon.
  ///
  /// In he, this message translates to:
  /// **'ב׳'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In he, this message translates to:
  /// **'ג׳'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In he, this message translates to:
  /// **'ד׳'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In he, this message translates to:
  /// **'ה׳'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In he, this message translates to:
  /// **'ו׳'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In he, this message translates to:
  /// **'ש׳'**
  String get daySat;

  /// No description provided for @realNotConfiguredTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveBond עוד לא מחוברת לשרת'**
  String get realNotConfiguredTitle;

  /// No description provided for @realNotConfiguredBody.
  ///
  /// In he, this message translates to:
  /// **'בגרסה הזו השרת עוד לא הוגדר. צריך להתקין גרסה מעודכנת.'**
  String get realNotConfiguredBody;

  /// No description provided for @realStarting.
  ///
  /// In he, this message translates to:
  /// **'מתחברים…'**
  String get realStarting;

  /// No description provided for @realWelcomeTitle.
  ///
  /// In he, this message translates to:
  /// **'בדיקה עם חבר'**
  String get realWelcomeTitle;

  /// No description provided for @realPhoneLabel.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון (לא חובה)'**
  String get realPhoneLabel;

  /// No description provided for @realPhoneHelp.
  ///
  /// In he, this message translates to:
  /// **'חברים ששמרו את המספר שלך יוכלו למצוא ולהוסיף אותך, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל את המספר רק כששניכם אמרתם \"כן\".'**
  String get realPhoneHelp;

  /// No description provided for @realJoin.
  ///
  /// In he, this message translates to:
  /// **'יאללה'**
  String get realJoin;

  /// No description provided for @realInviteWaitingAfterJoin.
  ///
  /// In he, this message translates to:
  /// **'יש לך הזמנה — היא תיפתח מיד אחרי הכניסה'**
  String get realInviteWaitingAfterJoin;

  /// No description provided for @realTabPeople.
  ///
  /// In he, this message translates to:
  /// **'האנשים שלי'**
  String get realTabPeople;

  /// No description provided for @realTabTest.
  ///
  /// In he, this message translates to:
  /// **'בדיקה'**
  String get realTabTest;

  /// No description provided for @realMeAvailableTitle.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{את פנויה לשיחה} male{אתה פנוי לשיחה} other{יש לך זמן לשיחה}}'**
  String realMeAvailableTitle(String gender);

  /// No description provided for @realFreeFriendsTitle.
  ///
  /// In he, this message translates to:
  /// **'עכשיו'**
  String get realFreeFriendsTitle;

  /// No description provided for @realNobodyFree.
  ///
  /// In he, this message translates to:
  /// **'כרגע אף חבר לא פנוי. כשמישהו יסמן שיש לו זמן, הוא יופיע כאן.'**
  String get realNobodyFree;

  /// No description provided for @realFreeHint.
  ///
  /// In he, this message translates to:
  /// **'רוצים לדבר עם מישהו פנוי? לוחצים עליו, ונשאל אם מתאים לו עכשיו.'**
  String get realFreeHint;

  /// No description provided for @realNobodyFreeYet.
  ///
  /// In he, this message translates to:
  /// **'נעדכן ברגע שמישהו מתאים יתפנה.'**
  String get realNobodyFreeYet;

  /// No description provided for @realNoFriendsTitle.
  ///
  /// In he, this message translates to:
  /// **'עוד אין פה חברים'**
  String get realNoFriendsTitle;

  /// No description provided for @realNoFriendsBody.
  ///
  /// In he, this message translates to:
  /// **'אפשר להזמין חבר — וכששניכם פנויים, נציע לכם לדבר.'**
  String get realNoFriendsBody;

  /// No description provided for @realInviteFriend.
  ///
  /// In he, this message translates to:
  /// **'להזמין חבר'**
  String get realInviteFriend;

  /// No description provided for @realHaveCode.
  ///
  /// In he, this message translates to:
  /// **'יש לי קוד הזמנה'**
  String get realHaveCode;

  /// No description provided for @realCodeHint.
  ///
  /// In he, this message translates to:
  /// **'הדביקו כאן את הקישור או הקוד'**
  String get realCodeHint;

  /// No description provided for @realCodeInvalid.
  ///
  /// In he, this message translates to:
  /// **'לא מצאנו קוד הזמנה בטקסט הזה'**
  String get realCodeInvalid;

  /// No description provided for @realOpen.
  ///
  /// In he, this message translates to:
  /// **'פתיחה'**
  String get realOpen;

  /// No description provided for @realInviteMessage.
  ///
  /// In he, this message translates to:
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond. כששנינו פנויים היא פשוט מציעה לנו לדבר.'**
  String get realInviteMessage;

  /// No description provided for @realInviteMessageNoSite.
  ///
  /// In he, this message translates to:
  /// **'להורדה: {apkUrl}\nואז באפליקציה: האנשים שלי ← יש לי קוד הזמנה ← {code}'**
  String realInviteMessageNoSite(String apkUrl, String code);

  /// No description provided for @realInviteShareSubject.
  ///
  /// In he, this message translates to:
  /// **'הזמנה ל-DriveBond'**
  String get realInviteShareSubject;

  /// No description provided for @realInviteCopied.
  ///
  /// In he, this message translates to:
  /// **'ההזמנה הועתקה — אפשר להדביק בוואטסאפ'**
  String get realInviteCopied;

  /// No description provided for @realOfferTitle.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} פנויה עכשיו. רוצה לדבר?} male{{name} פנוי עכשיו. רוצה לדבר?} other{ל{name} יש זמן עכשיו. רוצה לדבר?}}'**
  String realOfferTitle(String name, String gender);

  /// No description provided for @realTalkNow.
  ///
  /// In he, this message translates to:
  /// **'לדבר עכשיו'**
  String get realTalkNow;

  /// No description provided for @realNotNow.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get realNotNow;

  /// No description provided for @realOfferNote.
  ///
  /// In he, this message translates to:
  /// **'השיחה תתחיל רק אם שניכם אומרים כן'**
  String get realOfferNote;

  /// No description provided for @realWaitingTitle.
  ///
  /// In he, this message translates to:
  /// **'מחכים ל{name}…'**
  String realWaitingTitle(String name);

  /// No description provided for @realWaitingBody.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{ברגע ש{name} תאשר — מתחברים.} male{ברגע ש{name} יאשר — מתחברים.} other{ברגע שתגיע תשובה מ{name} — מתחברים.}}'**
  String realWaitingBody(String name, String gender);

  /// No description provided for @realStopWaiting.
  ///
  /// In he, this message translates to:
  /// **'לא לחכות'**
  String get realStopWaiting;

  /// No description provided for @realDidNotWorkOut.
  ///
  /// In he, this message translates to:
  /// **'לא הסתדר הפעם. נחפש הזדמנות אחרת.'**
  String get realDidNotWorkOut;

  /// No description provided for @routinesExplain.
  ///
  /// In he, this message translates to:
  /// **'זמנים קבועים שבהם הזמינות נדלקת לבד, למשל הנסיעה לעבודה.'**
  String get routinesExplain;

  /// No description provided for @realBlockedBody.
  ///
  /// In he, this message translates to:
  /// **'אנשים שחסמת לא יוצעו לך, והם לא יראו מתי יש לך זמן.'**
  String get realBlockedBody;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In he, this message translates to:
  /// **'מה נשמר ומה לא. אפשר גם למחוק מהשרת את מה שסונכרן מאנשי הקשר.'**
  String get settingsPrivacyBody;

  /// No description provided for @realNoAnswer.
  ///
  /// In he, this message translates to:
  /// **'אין תשובה כרגע. נציע שוב בהזדמנות אחרת.'**
  String get realNoAnswer;

  /// No description provided for @realVoiceDidNotWorkOut.
  ///
  /// In he, this message translates to:
  /// **'לא הסתדר הפעם.'**
  String get realVoiceDidNotWorkOut;

  /// No description provided for @realVoiceTheyCall.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} מתקשרת אליך.} male{{name} מתקשר אליך.} other{שיחה מ{name} מגיעה.}}'**
  String realVoiceTheyCall(String name, String gender);

  /// No description provided for @realQuickConnecting.
  ///
  /// In he, this message translates to:
  /// **'מתחברים ל{name}…'**
  String realQuickConnecting(String name);

  /// No description provided for @realQuickConnectingBody.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר — אפשר לבטל'**
  String get realQuickConnectingBody;

  /// No description provided for @realQuickSeconds.
  ///
  /// In he, this message translates to:
  /// **'{seconds, plural, =1{עוד שנייה — אפשר לבטל} other{עוד {seconds} שניות — אפשר לבטל}}'**
  String realQuickSeconds(int seconds);

  /// No description provided for @realQuickCancelled.
  ///
  /// In he, this message translates to:
  /// **'החיבור בוטל'**
  String get realQuickCancelled;

  /// No description provided for @realQuickTooLate.
  ///
  /// In he, this message translates to:
  /// **'כבר מאוחר לבטל — השיחה מתחילה'**
  String get realQuickTooLate;

  /// No description provided for @widgetTip.
  ///
  /// In he, this message translates to:
  /// **'אפשר לסמן \"יש לי זמן\" בלחיצה אחת, בלי לפתוח את האפליקציה: לחיצה ארוכה על מסך הבית ← ווידג\'טים ← DriveBond.'**
  String get widgetTip;

  /// No description provided for @gotIt.
  ///
  /// In he, this message translates to:
  /// **'הבנתי'**
  String get gotIt;

  /// No description provided for @realContactsAgain.
  ///
  /// In he, this message translates to:
  /// **'חיפוש שוב באנשי הקשר'**
  String get realContactsAgain;

  /// No description provided for @settingsGeneral.
  ///
  /// In he, this message translates to:
  /// **'כללי'**
  String get settingsGeneral;

  /// No description provided for @adminTitle.
  ///
  /// In he, this message translates to:
  /// **'ניהול'**
  String get adminTitle;

  /// No description provided for @adminCode.
  ///
  /// In he, this message translates to:
  /// **'קוד'**
  String get adminCode;

  /// No description provided for @adminWrong.
  ///
  /// In he, this message translates to:
  /// **'קוד שגוי'**
  String get adminWrong;

  /// No description provided for @adminLock.
  ///
  /// In he, this message translates to:
  /// **'לסגור את הניהול'**
  String get adminLock;

  /// No description provided for @updateAvailable.
  ///
  /// In he, this message translates to:
  /// **'יש גרסה חדשה של DriveBond'**
  String get updateAvailable;

  /// No description provided for @updateNow.
  ///
  /// In he, this message translates to:
  /// **'לעדכן'**
  String get updateNow;

  /// No description provided for @updateCheck.
  ///
  /// In he, this message translates to:
  /// **'בדיקת עדכון'**
  String get updateCheck;

  /// No description provided for @updateCurrent.
  ///
  /// In he, this message translates to:
  /// **'הגרסה שלך:'**
  String get updateCurrent;

  /// No description provided for @updateNone.
  ///
  /// In he, this message translates to:
  /// **'יש לך את הגרסה האחרונה'**
  String get updateNone;

  /// No description provided for @updateHow.
  ///
  /// In he, this message translates to:
  /// **'מורידים, לוחצים על הקובץ ← \"עדכון\". הכול נשמר.'**
  String get updateHow;

  /// No description provided for @updateHowStore.
  ///
  /// In he, this message translates to:
  /// **'מעדכנים בגוגל פליי. החברים וההגדרות נשמרים.'**
  String get updateHowStore;

  /// No description provided for @realBgFailedTitle.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו להדליק זמינות ברקע'**
  String get realBgFailedTitle;

  /// No description provided for @realBgFailedBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון חסם את זה. פותחים את DriveBond ובוחרים שוב מה עושים עכשיו.'**
  String get realBgFailedBody;

  /// No description provided for @routineHint.
  ///
  /// In he, this message translates to:
  /// **'נראה שבימי {day} סביב {time} יש לך בדרך כלל זמן. להפעיל זמינות אוטומטית בזמן הזה?'**
  String routineHint(String day, String time);

  /// No description provided for @routineHintYes.
  ///
  /// In he, this message translates to:
  /// **'להפעיל'**
  String get routineHintYes;

  /// No description provided for @routineHintNo.
  ///
  /// In he, this message translates to:
  /// **'לא, תודה'**
  String get routineHintNo;

  /// No description provided for @realStatusServerVersion.
  ///
  /// In he, this message translates to:
  /// **'גרסת השרת'**
  String get realStatusServerVersion;

  /// No description provided for @realServerOutdated.
  ///
  /// In he, this message translates to:
  /// **'השרת צריך עדכון: בשרת {have}, נדרש {need}'**
  String realServerOutdated(int have, int need);

  /// No description provided for @realClearContacts.
  ///
  /// In he, this message translates to:
  /// **'למחוק מידע שסונכרן מאנשי הקשר'**
  String get realClearContacts;

  /// No description provided for @realDeleteAccount.
  ///
  /// In he, this message translates to:
  /// **'למחוק את החשבון והמידע שלי'**
  String get realDeleteAccount;

  /// No description provided for @realDeleteAccountConfirm.
  ///
  /// In he, this message translates to:
  /// **'הכול נמחק מהשרת: שם, מספר, חברים, קבוצות ותמונה. אי אפשר לבטל.'**
  String get realDeleteAccountConfirm;

  /// No description provided for @realDeleteAccountGo.
  ///
  /// In he, this message translates to:
  /// **'למחוק'**
  String get realDeleteAccountGo;

  /// No description provided for @realDeleteAccountDone.
  ///
  /// In he, this message translates to:
  /// **'החשבון והמידע נמחקו'**
  String get realDeleteAccountDone;

  /// No description provided for @realNotifPublic.
  ///
  /// In he, this message translates to:
  /// **'יש הצעה חדשה ב-DriveBond'**
  String get realNotifPublic;

  /// No description provided for @firstRunContactsTitle.
  ///
  /// In he, this message translates to:
  /// **'נראה מי מהאנשים שלך כבר כאן'**
  String get firstRunContactsTitle;

  /// No description provided for @firstRunContactsBody.
  ///
  /// In he, this message translates to:
  /// **'רק מספרים, מוצפנים. שמות לא יוצאים מהטלפון.'**
  String get firstRunContactsBody;

  /// No description provided for @firstRunContactsGo.
  ///
  /// In he, this message translates to:
  /// **'לחפש באנשי הקשר'**
  String get firstRunContactsGo;

  /// No description provided for @firstRunFound.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{מצאנו אדם אחד מאנשי הקשר} other{מצאנו {count} אנשים מאנשי הקשר}}'**
  String firstRunFound(int count);

  /// No description provided for @firstRunNoneTitle.
  ///
  /// In he, this message translates to:
  /// **'כדי לנסות את DriveBond צריך לפחות חבר אחד'**
  String get firstRunNoneTitle;

  /// No description provided for @firstRunNoneBody.
  ///
  /// In he, this message translates to:
  /// **'שולחים קישור למישהו שאוהבים לדבר איתו. אחרי ההתקנה, אחד מכם מוסיף את השני: האנשים שלי ← חיפוש באנשי הקשר.'**
  String get firstRunNoneBody;

  /// No description provided for @firstRunLater.
  ///
  /// In he, this message translates to:
  /// **'אחר כך'**
  String get firstRunLater;

  /// No description provided for @firstRunMagicTitle.
  ///
  /// In he, this message translates to:
  /// **'ככה זה עובד'**
  String get firstRunMagicTitle;

  /// No description provided for @firstRunMagicBody.
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים, DriveBond מציעה לכם לדבר. לא צריך לתאם מראש.'**
  String get firstRunMagicBody;

  /// No description provided for @firstRunMagicGo.
  ///
  /// In he, this message translates to:
  /// **'יאללה'**
  String get firstRunMagicGo;

  /// No description provided for @routineNameToWork.
  ///
  /// In he, this message translates to:
  /// **'בדרך לעבודה'**
  String get routineNameToWork;

  /// No description provided for @routineNameHome.
  ///
  /// In he, this message translates to:
  /// **'בדרך הביתה'**
  String get routineNameHome;

  /// No description provided for @routineNameWalk.
  ///
  /// In he, this message translates to:
  /// **'הליכת ערב'**
  String get routineNameWalk;

  /// No description provided for @routineNameBreak.
  ///
  /// In he, this message translates to:
  /// **'הפסקת צהריים'**
  String get routineNameBreak;

  /// No description provided for @routineEveryone.
  ///
  /// In he, this message translates to:
  /// **'כולם'**
  String get routineEveryone;

  /// No description provided for @realCallingNow.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name}…'**
  String realCallingNow(String name);

  /// No description provided for @realDialedBody.
  ///
  /// In he, this message translates to:
  /// **'כשהשיחה נגמרת, חוזרים לכאן.'**
  String get realDialedBody;

  /// No description provided for @realTheyCallTitle.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} מתקשרת אליך עכשיו} male{{name} מתקשר אליך עכשיו} other{שיחה מ{name} מגיעה עכשיו}}'**
  String realTheyCallTitle(String name, String gender);

  /// No description provided for @realTheyCallBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון יצלצל עוד רגע. אם השיחה לא מגיעה תוך דקה — \"לא הגיעה שיחה\".'**
  String get realTheyCallBody;

  /// No description provided for @realTheyDidNotCall.
  ///
  /// In he, this message translates to:
  /// **'לא הגיעה שיחה'**
  String get realTheyDidNotCall;

  /// No description provided for @realNoNumbersTitle.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר להתקשר הפעם'**
  String get realNoNumbersTitle;

  /// No description provided for @realNoNumbersBody.
  ///
  /// In he, this message translates to:
  /// **'לשניכם אין מספר טלפון באפליקציה. כדי לדבר, אחד מכם מוסיף מספר: הגדרות ← לחיצה על השם ← \"המספר שלי לשיחה רגילה\".'**
  String get realNoNumbersBody;

  /// No description provided for @realDialFailedTitle.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לפתוח את החייגן'**
  String get realDialFailedTitle;

  /// No description provided for @realDialFailedBody.
  ///
  /// In he, this message translates to:
  /// **'אפשר להתקשר ל{name} ידנית.'**
  String realDialFailedBody(String name);

  /// No description provided for @realFeedbackThanks.
  ///
  /// In he, this message translates to:
  /// **'תודה!'**
  String get realFeedbackThanks;

  /// No description provided for @realConnected.
  ///
  /// In he, this message translates to:
  /// **'מעולה! {name} עכשיו ברשימת האנשים שלך.'**
  String realConnected(String name);

  /// No description provided for @realInviteTitle.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} הזמינה אותך} male{{name} הזמין אותך} other{הזמנה מ{name}}}'**
  String realInviteTitle(String name, String gender);

  /// No description provided for @realInviteBody.
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים — נציע לכם לדבר. רק אם שניכם מסכימים.'**
  String get realInviteBody;

  /// No description provided for @realInviteAccept.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get realInviteAccept;

  /// No description provided for @realInviteLoading.
  ///
  /// In he, this message translates to:
  /// **'בודקים את ההזמנה…'**
  String get realInviteLoading;

  /// No description provided for @realInviteProblemUsed.
  ///
  /// In he, this message translates to:
  /// **'ההזמנה הזו כבר נוצלה. צריך הזמנה חדשה.'**
  String get realInviteProblemUsed;

  /// No description provided for @realInviteProblemExpired.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף ההזמנה. צריך הזמנה חדשה.'**
  String get realInviteProblemExpired;

  /// No description provided for @realInviteProblemOwn.
  ///
  /// In he, this message translates to:
  /// **'זו הזמנה ששלחת בעצמך 🙂 אפשר לשלוח אותה לחבר.'**
  String get realInviteProblemOwn;

  /// No description provided for @realInviteProblemNotFound.
  ///
  /// In he, this message translates to:
  /// **'לא מצאנו את ההזמנה. בדקו שהקישור הועתק במלואו.'**
  String get realInviteProblemNotFound;

  /// No description provided for @realInviteAlready.
  ///
  /// In he, this message translates to:
  /// **'{name} כבר ברשימת האנשים שלך.'**
  String realInviteAlready(String name);

  /// No description provided for @realErrorOffline.
  ///
  /// In he, this message translates to:
  /// **'אין חיבור לאינטרנט. ננסה שוב לבד.'**
  String get realErrorOffline;

  /// No description provided for @realErrorGeneric.
  ///
  /// In he, this message translates to:
  /// **'משהו השתבש ({code}). אפשר לנסות שוב.'**
  String realErrorGeneric(String code);

  /// No description provided for @realErrorAnonymousDisabled.
  ///
  /// In he, this message translates to:
  /// **'בשרת עוד לא הופעלה כניסה בלי סיסמה (Anonymous sign-ins).'**
  String get realErrorAnonymousDisabled;

  /// No description provided for @realErrorSchema.
  ///
  /// In he, this message translates to:
  /// **'השרת עוד לא מוכן. אפשר לנסות שוב מאוחר יותר.'**
  String get realErrorSchema;

  /// No description provided for @realErrorInvalidPhone.
  ///
  /// In he, this message translates to:
  /// **'מספר הטלפון לא נראה תקין'**
  String get realErrorInvalidPhone;

  /// No description provided for @realErrorInvalidName.
  ///
  /// In he, this message translates to:
  /// **'השם צריך להיות באורך 1–40 תווים'**
  String get realErrorInvalidName;

  /// No description provided for @realErrorRateLimited.
  ///
  /// In he, this message translates to:
  /// **'יותר מדי ניסיונות. אפשר לנסות שוב בעוד כמה דקות.'**
  String get realErrorRateLimited;

  /// No description provided for @realErrorTooManyInvites.
  ///
  /// In he, this message translates to:
  /// **'יש כבר הרבה הזמנות פתוחות. אפשר לנסות שוב מחר.'**
  String get realErrorTooManyInvites;

  /// No description provided for @realSaved.
  ///
  /// In he, this message translates to:
  /// **'נשמר'**
  String get realSaved;

  /// No description provided for @realDialFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לפתוח את החייגן. אפשר להתקשר ידנית.'**
  String get realDialFailed;

  /// No description provided for @realUnmatched.
  ///
  /// In he, this message translates to:
  /// **'הקשר עם {name} הוסר'**
  String realUnmatched(String name);

  /// No description provided for @realNotFree.
  ///
  /// In he, this message translates to:
  /// **'אין זמינות כרגע'**
  String get realNotFree;

  /// No description provided for @realTestIntro.
  ///
  /// In he, this message translates to:
  /// **'כאן רואים שהכול עובד. אם משהו לא עובד — \"להעתיק מידע לבדיקה\" ושולחים לי.'**
  String get realTestIntro;

  /// No description provided for @realTestSteps.
  ///
  /// In he, this message translates to:
  /// **'1. להזמין חבר\n2. שניכם: בוחרים מה עושים עכשיו (למשל \"סתם זמן פנוי\")\n3. שניכם: \"לדבר עכשיו\"'**
  String get realTestSteps;

  /// No description provided for @realStatusServer.
  ///
  /// In he, this message translates to:
  /// **'שרת'**
  String get realStatusServer;

  /// No description provided for @realStatusAccount.
  ///
  /// In he, this message translates to:
  /// **'חשבון'**
  String get realStatusAccount;

  /// No description provided for @realStatusLive.
  ///
  /// In he, this message translates to:
  /// **'עדכון מיידי'**
  String get realStatusLive;

  /// No description provided for @realStatusFriends.
  ///
  /// In he, this message translates to:
  /// **'חברים'**
  String get realStatusFriends;

  /// No description provided for @realStatusMe.
  ///
  /// In he, this message translates to:
  /// **'הזמינות שלי'**
  String get realStatusMe;

  /// No description provided for @realStatusFreeFriends.
  ///
  /// In he, this message translates to:
  /// **'חברים פנויים עכשיו'**
  String get realStatusFreeFriends;

  /// No description provided for @realStatusLastOffer.
  ///
  /// In he, this message translates to:
  /// **'הצעה אחרונה'**
  String get realStatusLastOffer;

  /// No description provided for @realStatusVersion.
  ///
  /// In he, this message translates to:
  /// **'גרסה'**
  String get realStatusVersion;

  /// No description provided for @realStatusLastError.
  ///
  /// In he, this message translates to:
  /// **'שגיאה אחרונה'**
  String get realStatusLastError;

  /// No description provided for @realStatusPhone.
  ///
  /// In he, this message translates to:
  /// **'מספר לשיחה רגילה'**
  String get realStatusPhone;

  /// No description provided for @realOk.
  ///
  /// In he, this message translates to:
  /// **'תקין'**
  String get realOk;

  /// No description provided for @realNotConnected.
  ///
  /// In he, this message translates to:
  /// **'לא מחובר'**
  String get realNotConnected;

  /// No description provided for @realLiveError.
  ///
  /// In he, this message translates to:
  /// **'לא יציב — מתעדכן כל כמה שניות'**
  String get realLiveError;

  /// No description provided for @realNone.
  ///
  /// In he, this message translates to:
  /// **'אין'**
  String get realNone;

  /// No description provided for @realShared.
  ///
  /// In he, this message translates to:
  /// **'משותף'**
  String get realShared;

  /// No description provided for @realNotShared.
  ///
  /// In he, this message translates to:
  /// **'אין מספר · להוסיף'**
  String get realNotShared;

  /// No description provided for @realMeNotAvailable.
  ///
  /// In he, this message translates to:
  /// **'אין זמינות'**
  String get realMeNotAvailable;

  /// No description provided for @realOfferPending.
  ///
  /// In he, this message translates to:
  /// **'מחכה לתשובה'**
  String get realOfferPending;

  /// No description provided for @realOfferAccepted.
  ///
  /// In he, this message translates to:
  /// **'שניכם אמרתם כן'**
  String get realOfferAccepted;

  /// No description provided for @realOfferDeclined.
  ///
  /// In he, this message translates to:
  /// **'לא הסתדר'**
  String get realOfferDeclined;

  /// No description provided for @realOfferExpired.
  ///
  /// In he, this message translates to:
  /// **'פג הזמן'**
  String get realOfferExpired;

  /// No description provided for @realOfferCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטל'**
  String get realOfferCancelled;

  /// No description provided for @realCopyDiagnostics.
  ///
  /// In he, this message translates to:
  /// **'להעתיק מידע לבדיקה'**
  String get realCopyDiagnostics;

  /// No description provided for @realCopied.
  ///
  /// In he, this message translates to:
  /// **'הועתק. אפשר להדביק ולשלוח'**
  String get realCopied;

  /// No description provided for @realRefresh.
  ///
  /// In he, this message translates to:
  /// **'רענון'**
  String get realRefresh;

  /// No description provided for @realTestModeToggle.
  ///
  /// In he, this message translates to:
  /// **'מסך בדיקה (Test Mode)'**
  String get realTestModeToggle;

  /// No description provided for @realTestModeBody.
  ///
  /// In he, this message translates to:
  /// **'מציג את הלשונית \"בדיקה\" עם מצב החיבור'**
  String get realTestModeBody;

  /// No description provided for @realMyNumber.
  ///
  /// In he, this message translates to:
  /// **'המספר שלי לשיחה רגילה'**
  String get realMyNumber;

  /// No description provided for @realStartOver.
  ///
  /// In he, this message translates to:
  /// **'להתחיל מחדש כמשתמש חדש'**
  String get realStartOver;

  /// No description provided for @realStartOverConfirm.
  ///
  /// In he, this message translates to:
  /// **'החברים וההזמנות של המשתמש הנוכחי לא יעברו. להמשיך?'**
  String get realStartOverConfirm;

  /// No description provided for @realDownloadLink.
  ///
  /// In he, this message translates to:
  /// **'קישור להורדת האפליקציה'**
  String get realDownloadLink;

  /// No description provided for @realShareApp.
  ///
  /// In he, this message translates to:
  /// **'שיתוף'**
  String get realShareApp;

  /// No description provided for @realNameTitle.
  ///
  /// In he, this message translates to:
  /// **'השם שלי'**
  String get realNameTitle;

  /// No description provided for @realPhotoTitle.
  ///
  /// In he, this message translates to:
  /// **'התמונה שלי'**
  String get realPhotoTitle;

  /// No description provided for @realPhotoSaved.
  ///
  /// In he, this message translates to:
  /// **'התמונה נשמרה'**
  String get realPhotoSaved;

  /// No description provided for @realPhotoRemoved.
  ///
  /// In he, this message translates to:
  /// **'התמונה הוסרה'**
  String get realPhotoRemoved;

  /// No description provided for @realPrivacyNote.
  ///
  /// In he, this message translates to:
  /// **'בלי מיקום ובלי הקלטות. בשרת נשמר רק מה שהאפליקציה צריכה: שם, מספר ותמונה (אם הוספת), החברים שלך ומתי יש לך זמן. הפירוט המלא במדיניות הפרטיות.'**
  String get realPrivacyNote;

  /// No description provided for @realVoiceOffer.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} פנויה. לדבר?} male{{name} פנוי. לדבר?} other{ל{name} יש זמן. לדבר?}}'**
  String realVoiceOffer(String name, String gender);

  /// No description provided for @realVoiceCalling.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name}.'**
  String realVoiceCalling(String name);

  /// No description provided for @realNotifChannelStatus.
  ///
  /// In he, this message translates to:
  /// **'זמינות בנסיעה'**
  String get realNotifChannelStatus;

  /// No description provided for @realNotifChannelOffers.
  ///
  /// In he, this message translates to:
  /// **'חבר פנוי לשיחה'**
  String get realNotifChannelOffers;

  /// No description provided for @realNotifStatusTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveBond · זמינות לשיחה בנסיעה'**
  String get realNotifStatusTitle;

  /// No description provided for @realNotifStatusBody.
  ///
  /// In he, this message translates to:
  /// **'נסיעה טובה! נודיע כשחבר פנוי.'**
  String get realNotifStatusBody;

  /// No description provided for @realAutoDriving.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה'**
  String get realAutoDriving;

  /// No description provided for @realAutoDrivingBody.
  ///
  /// In he, this message translates to:
  /// **'כשהטלפון מזהה שהוא ברכב, החברים יכולים לקבל הצעה לדבר איתך. נכבה לבד בסוף הנסיעה. בלי GPS ובלי מיקום.'**
  String get realAutoDrivingBody;

  /// No description provided for @realAutoDrivingUnsupported.
  ///
  /// In he, this message translates to:
  /// **'לא זמין במכשיר הזה'**
  String get realAutoDrivingUnsupported;

  /// No description provided for @realAutoDrivingDialogTitle.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה'**
  String get realAutoDrivingDialogTitle;

  /// No description provided for @realAutoDrivingDialogBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון מזהה נסיעה לבד (בלי GPS) ומסמן שיש לך זמן עד סוף הנסיעה.\n\nשיחה מתחילה רק אם שניכם אומרים כן (או בחיבור מהיר ששניכם הפעלתם).\n\nיתבקשו הרשאות \"פעילות גופנית\" והתראות.'**
  String get realAutoDrivingDialogBody;

  /// No description provided for @realAutoDrivingOn.
  ///
  /// In he, this message translates to:
  /// **'מעולה. בנסיעה הבאה הזמינות תידלק לבד.'**
  String get realAutoDrivingOn;

  /// No description provided for @realAutoDrivingOff.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה כובתה'**
  String get realAutoDrivingOff;

  /// No description provided for @realAutoDrivingNoPermission.
  ///
  /// In he, this message translates to:
  /// **'צריך הרשאת \"פעילות גופנית\": הגדרות הטלפון ← אפליקציות ← DriveBond ← הרשאות.'**
  String get realAutoDrivingNoPermission;

  /// No description provided for @realAutoDrivingFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו להפעיל זיהוי נסיעה. אפשר לנסות שוב.'**
  String get realAutoDrivingFailed;

  /// No description provided for @realStatusAutoDriving.
  ///
  /// In he, this message translates to:
  /// **'זיהוי נסיעה'**
  String get realStatusAutoDriving;

  /// No description provided for @realAutoOn.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get realAutoOn;

  /// No description provided for @realAutoOff.
  ///
  /// In he, this message translates to:
  /// **'כבוי'**
  String get realAutoOff;

  /// No description provided for @realInVehicleNow.
  ///
  /// In he, this message translates to:
  /// **'ברכב עכשיו'**
  String get realInVehicleNow;

  /// No description provided for @realSimEnter.
  ///
  /// In he, this message translates to:
  /// **'דמה: נכנסתי לרכב'**
  String get realSimEnter;

  /// No description provided for @realSimExit.
  ///
  /// In he, this message translates to:
  /// **'דמה: יצאתי מהרכב'**
  String get realSimExit;

  /// No description provided for @realVoiceQuick.
  ///
  /// In he, this message translates to:
  /// **'מתחברים ל{name}. אפשר לבטל בכפתור.'**
  String realVoiceQuick(String name);

  /// No description provided for @realUnblocked.
  ///
  /// In he, this message translates to:
  /// **'החסימה של {name} בוטלה'**
  String realUnblocked(String name);

  /// No description provided for @realUnblockedBack.
  ///
  /// In he, this message translates to:
  /// **'החסימה של {name} בוטלה — {name} שוב ברשימה שלך'**
  String realUnblockedBack(String name);

  /// No description provided for @realBlockedTitle.
  ///
  /// In he, this message translates to:
  /// **'חסומים'**
  String get realBlockedTitle;

  /// No description provided for @realBlockedEmpty.
  ///
  /// In he, this message translates to:
  /// **'לא חסמת אף אחד'**
  String get realBlockedEmpty;

  /// No description provided for @realUnblock.
  ///
  /// In he, this message translates to:
  /// **'ביטול חסימה'**
  String get realUnblock;

  /// No description provided for @realCirclesTitle.
  ///
  /// In he, this message translates to:
  /// **'קבוצות'**
  String get realCirclesTitle;

  /// No description provided for @realCirclesIntro.
  ///
  /// In he, this message translates to:
  /// **'קבוצה היא כמה חברים יחד, למשל משפחה או עבודה. לכל קבוצה בוחרים מתי היא רואה שיש לך זמן — למשל, עבודה רק בנסיעה. מי שלא רואה, גם לא מקבל הצעה לדבר איתך.'**
  String get realCirclesIntro;

  /// No description provided for @circleSeesAll.
  ///
  /// In he, this message translates to:
  /// **'רואים שיש לך זמן: בכל מצב'**
  String get circleSeesAll;

  /// No description provided for @circleSeesSome.
  ///
  /// In he, this message translates to:
  /// **'רואים שיש לך זמן: {modes}'**
  String circleSeesSome(String modes);

  /// No description provided for @circleSeesNone.
  ///
  /// In he, this message translates to:
  /// **'מוסתר מהקבוצה שיש לך זמן'**
  String get circleSeesNone;

  /// No description provided for @circleRuleQuestion.
  ///
  /// In he, this message translates to:
  /// **'מתי חברי הקבוצה יראו שיש לך זמן?'**
  String get circleRuleQuestion;

  /// No description provided for @modeInDriving.
  ///
  /// In he, this message translates to:
  /// **'בנסיעה'**
  String get modeInDriving;

  /// No description provided for @modeInWalking.
  ///
  /// In he, this message translates to:
  /// **'בהליכה'**
  String get modeInWalking;

  /// No description provided for @modeInBreak.
  ///
  /// In he, this message translates to:
  /// **'בהפסקה'**
  String get modeInBreak;

  /// No description provided for @modeInFree.
  ///
  /// In he, this message translates to:
  /// **'בזמן פנוי'**
  String get modeInFree;

  /// No description provided for @realCircleNew.
  ///
  /// In he, this message translates to:
  /// **'קבוצה חדשה'**
  String get realCircleNew;

  /// No description provided for @realCircleName.
  ///
  /// In he, this message translates to:
  /// **'שם הקבוצה (למשל: שכנים)'**
  String get realCircleName;

  /// No description provided for @realCircleMembers.
  ///
  /// In he, this message translates to:
  /// **'מי בקבוצה'**
  String get realCircleMembers;

  /// No description provided for @realCircleCount.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{עוד אין אנשים} =1{אדם אחד} other{{count} אנשים}}'**
  String realCircleCount(int count);

  /// No description provided for @realCircleDelete.
  ///
  /// In he, this message translates to:
  /// **'מחיקת הקבוצה'**
  String get realCircleDelete;

  /// No description provided for @realCircleNoFriends.
  ///
  /// In he, this message translates to:
  /// **'קודם צריך להזמין חברים'**
  String get realCircleNoFriends;

  /// No description provided for @circleFamily.
  ///
  /// In he, this message translates to:
  /// **'משפחה'**
  String get circleFamily;

  /// No description provided for @circleFriends.
  ///
  /// In he, this message translates to:
  /// **'חברים'**
  String get circleFriends;

  /// No description provided for @circleWork.
  ///
  /// In he, this message translates to:
  /// **'עבודה'**
  String get circleWork;

  /// No description provided for @whoSeesTitle.
  ///
  /// In he, this message translates to:
  /// **'מי רואה שיש לי זמן'**
  String get whoSeesTitle;

  /// No description provided for @whoSeesSubtitle.
  ///
  /// In he, this message translates to:
  /// **'קבוצות: מי רואה, ומתי'**
  String get whoSeesSubtitle;

  /// No description provided for @whoSeesTwo.
  ///
  /// In he, this message translates to:
  /// **'מי שנמצא בשתי קבוצות רואה רק אם שתיהן מרשות.'**
  String get whoSeesTwo;

  /// No description provided for @whoSeesOthers.
  ///
  /// In he, this message translates to:
  /// **'כל השאר (חברים שלא בשום קבוצה)'**
  String get whoSeesOthers;

  /// No description provided for @showAlways.
  ///
  /// In he, this message translates to:
  /// **'תמיד'**
  String get showAlways;

  /// No description provided for @showNever.
  ///
  /// In he, this message translates to:
  /// **'אף פעם'**
  String get showNever;

  /// No description provided for @showOnly.
  ///
  /// In he, this message translates to:
  /// **'רק במצבים שמסומנים:'**
  String get showOnly;

  /// No description provided for @showOnlyModes.
  ///
  /// In he, this message translates to:
  /// **'רק: {modes}'**
  String showOnlyModes(String modes);

  /// No description provided for @friendCirclesTitle.
  ///
  /// In he, this message translates to:
  /// **'קבוצות'**
  String get friendCirclesTitle;

  /// No description provided for @friendCirclesBody.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה קובעת אם רואים שאפשר לדבר איתך.'**
  String get friendCirclesBody;

  /// No description provided for @hiddenUnhide.
  ///
  /// In he, this message translates to:
  /// **'לבטל את ההסתרה'**
  String get hiddenUnhide;

  /// No description provided for @homeWhatNow.
  ///
  /// In he, this message translates to:
  /// **'בוחרים מה עושים עכשיו, ונמצא חבר שגם פנוי לדבר'**
  String get homeWhatNow;

  /// No description provided for @permIntroTitle.
  ///
  /// In he, this message translates to:
  /// **'רגע לפני'**
  String get permIntroTitle;

  /// No description provided for @permIntroBody.
  ///
  /// In he, this message translates to:
  /// **'כדי שהשיחה תתחיל מיד כששניכם אומרים \"כן\", ושנוכל להודיע כשחבר מתפנה, הטלפון ישאל כמה שאלות:\n\n• שיחות טלפון — כדי לחייג בלחיצה אחת.\n• התראות — כדי להודיע גם כשהאפליקציה סגורה.\n• מיקרופון (בנסיעה) — כדי לענות \"כן\" או \"לא\" בקול. שום דבר לא מוקלט.'**
  String get permIntroBody;

  /// No description provided for @permIntroGo.
  ///
  /// In he, this message translates to:
  /// **'הבנתי, ממשיכים'**
  String get permIntroGo;

  /// No description provided for @realPhoneRequired.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון (לא חובה)'**
  String get realPhoneRequired;

  /// No description provided for @realPhoneRequiredHelp.
  ///
  /// In he, this message translates to:
  /// **'למה כדאי: חברים ששמרו את המספר שלך יוכלו למצוא ולהוסיף אותך, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל את המספר רק כששניכם אמרתם \"כן\". אפשר גם להוסיף אחר כך.'**
  String get realPhoneRequiredHelp;

  /// No description provided for @realContactsTitle.
  ///
  /// In he, this message translates to:
  /// **'חברים מאנשי הקשר'**
  String get realContactsTitle;

  /// No description provided for @realContactsBody.
  ///
  /// In he, this message translates to:
  /// **'מוצאים מי מאנשי הקשר כבר כאן, ובוחרים את מי להוסיף. לא צריך את המספר שלך.'**
  String get realContactsBody;

  /// No description provided for @realContactsButton.
  ///
  /// In he, this message translates to:
  /// **'חיפוש באנשי הקשר'**
  String get realContactsButton;

  /// No description provided for @realContactsFound.
  ///
  /// In he, this message translates to:
  /// **'{names} — עכשיו ברשימה שלך'**
  String realContactsFound(String names);

  /// No description provided for @realContactsNone.
  ///
  /// In he, this message translates to:
  /// **'עוד אין כאן מאנשי הקשר שלך. אפשר להזמין עם קישור.'**
  String get realContactsNone;

  /// No description provided for @realContactsNoPermission.
  ///
  /// In he, this message translates to:
  /// **'בלי הרשאה לאנשי קשר — אפשר להזמין עם קישור.'**
  String get realContactsNoPermission;

  /// No description provided for @realNotifManualTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveBond · זמינות לשיחה'**
  String get realNotifManualTitle;

  /// No description provided for @realNotifManualBody.
  ///
  /// In he, this message translates to:
  /// **'נודיע כשחבר פנוי — גם כשהאפליקציה סגורה.'**
  String get realNotifManualBody;

  /// No description provided for @realOfferName.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} פנויה עכשיו} male{{name} פנוי עכשיו} other{ל{name} יש זמן עכשיו}}'**
  String realOfferName(String name, String gender);

  /// No description provided for @realOfferAsk.
  ///
  /// In he, this message translates to:
  /// **'רוצה לדבר?'**
  String get realOfferAsk;

  /// No description provided for @realOfferAskShort.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{פנויה. לדבר?} male{פנוי. לדבר?} other{יש זמן. לדבר?}}'**
  String realOfferAskShort(String gender);

  /// No description provided for @realGreetMorning.
  ///
  /// In he, this message translates to:
  /// **'בוקר טוב'**
  String get realGreetMorning;

  /// No description provided for @realGreetNoon.
  ///
  /// In he, this message translates to:
  /// **'צהריים טובים'**
  String get realGreetNoon;

  /// No description provided for @realGreetEvening.
  ///
  /// In he, this message translates to:
  /// **'ערב טוב'**
  String get realGreetEvening;

  /// No description provided for @realGreetNight.
  ///
  /// In he, this message translates to:
  /// **'לילה טוב'**
  String get realGreetNight;

  /// No description provided for @realHomeTitle.
  ///
  /// In he, this message translates to:
  /// **'{name}, עם מי\nמדברים היום?'**
  String realHomeTitle(String name);

  /// No description provided for @realFreeCount.
  ///
  /// In he, this message translates to:
  /// **'יש זמן: {count}'**
  String realFreeCount(int count);

  /// No description provided for @realGroupAccount.
  ///
  /// In he, this message translates to:
  /// **'החשבון שלי'**
  String get realGroupAccount;

  /// No description provided for @realWelcomeHeadline.
  ///
  /// In he, this message translates to:
  /// **'זמן מת?\nשיחה טובה.'**
  String get realWelcomeHeadline;

  /// No description provided for @realWelcomeSub.
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים באותו רגע — נציע לכם לדבר.'**
  String get realWelcomeSub;

  /// No description provided for @realInviteSimple.
  ///
  /// In he, this message translates to:
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה: {apkUrl}\nעזרה בהתקנה: {guideUrl}'**
  String realInviteSimple(String apkUrl, String guideUrl);

  /// No description provided for @realQuickOff.
  ///
  /// In he, this message translates to:
  /// **'יש לי זמן'**
  String get realQuickOff;

  /// No description provided for @realQuickOn.
  ///
  /// In he, this message translates to:
  /// **'יש לי זמן · לעצירה'**
  String get realQuickOn;

  /// No description provided for @realCarTitle.
  ///
  /// In he, this message translates to:
  /// **'הרכב שלי (בלוטות׳)'**
  String get realCarTitle;

  /// No description provided for @realCarBody.
  ///
  /// In he, this message translates to:
  /// **'כשהטלפון מתחבר לבלוטות׳ של הרכב, זה סימן שהנסיעה התחילה. עוזר לזהות נסיעה מהר יותר.'**
  String get realCarBody;

  /// No description provided for @realCarPick.
  ///
  /// In he, this message translates to:
  /// **'בחירת הרכב'**
  String get realCarPick;

  /// No description provided for @realCarNoDevices.
  ///
  /// In he, this message translates to:
  /// **'לא נמצאו מכשירי בלוטות׳ מחוברים. חברו את הטלפון לרכב פעם אחת ונסו שוב.'**
  String get realCarNoDevices;

  /// No description provided for @realCarRemove.
  ///
  /// In he, this message translates to:
  /// **'בלי רכב'**
  String get realCarRemove;

  /// No description provided for @realWeekTitle.
  ///
  /// In he, this message translates to:
  /// **'השבוע שלך'**
  String get realWeekTitle;

  /// No description provided for @realWeekTalks.
  ///
  /// In he, this message translates to:
  /// **'{talks, plural, =0{עוד אין שיחות השבוע} =1{שיחה אחת} other{{talks} שיחות}}'**
  String realWeekTalks(int talks);

  /// No description provided for @realWeekFriends.
  ///
  /// In he, this message translates to:
  /// **'{friends, plural, =1{עם חבר אחד} other{עם {friends} חברים}}'**
  String realWeekFriends(int friends);

  /// No description provided for @realRoutinesIntro.
  ///
  /// In he, this message translates to:
  /// **'בזמנים האלה הזמינות נדלקת לבד, גם כשהאפליקציה סגורה.'**
  String get realRoutinesIntro;

  /// No description provided for @realRoutineNotifTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveBond · השגרה שלך'**
  String get realRoutineNotifTitle;

  /// No description provided for @realRoutineNotifBody.
  ///
  /// In he, this message translates to:
  /// **'הזמינות לשיחה נדלקה. \"לעצור\" בהתראה מבטל.'**
  String get realRoutineNotifBody;

  /// No description provided for @done.
  ///
  /// In he, this message translates to:
  /// **'סיום'**
  String get done;

  /// No description provided for @ratingNever.
  ///
  /// In he, this message translates to:
  /// **'לא להציע'**
  String get ratingNever;

  /// No description provided for @ratingLabel.
  ///
  /// In he, this message translates to:
  /// **'דירוג {rating} מתוך 5'**
  String ratingLabel(int rating);

  /// No description provided for @ratingTitle.
  ///
  /// In he, this message translates to:
  /// **'כמה בא לי לדבר?'**
  String get ratingTitle;

  /// No description provided for @ratingHelp.
  ///
  /// In he, this message translates to:
  /// **'0 = לא להציע בכלל · 5 = הכי חשוב. רק לך זה מוצג.'**
  String get ratingHelp;

  /// No description provided for @contactsPickTitle.
  ///
  /// In he, this message translates to:
  /// **'מאנשי הקשר שלך כבר כאן'**
  String get contactsPickTitle;

  /// No description provided for @contactsPickBody.
  ///
  /// In he, this message translates to:
  /// **'בוחרים רק את מי שבא לדבר איתו. מי שלא נבחר לא יודע על זה.'**
  String get contactsPickBody;

  /// No description provided for @contactsAdd.
  ///
  /// In he, this message translates to:
  /// **'להוסיף'**
  String get contactsAdd;

  /// No description provided for @contactsNo.
  ///
  /// In he, this message translates to:
  /// **'לא'**
  String get contactsNo;

  /// No description provided for @newContactTitle.
  ///
  /// In he, this message translates to:
  /// **'{name} מאנשי הקשר שלך כבר כאן'**
  String newContactTitle(String name);

  /// No description provided for @newContactBody.
  ///
  /// In he, this message translates to:
  /// **'להוסיף לאנשים שלי?'**
  String get newContactBody;

  /// No description provided for @hiddenNote.
  ///
  /// In he, this message translates to:
  /// **'המצב שלך מוסתר, ולכן גם לא רואים כאן מי פנוי. הצעות לדבר ממשיכות.'**
  String get hiddenNote;

  /// No description provided for @realLaterButton.
  ///
  /// In he, this message translates to:
  /// **'עכשיו לא, אבל אשמח בהמשך'**
  String get realLaterButton;

  /// No description provided for @realLaterNote.
  ///
  /// In he, this message translates to:
  /// **'מ{name}: עכשיו לא מתאים, אולי אחר כך.'**
  String realLaterNote(String name);

  /// No description provided for @backgroundTitle.
  ///
  /// In he, this message translates to:
  /// **'לא לפספס אף שיחה'**
  String get backgroundTitle;

  /// No description provided for @backgroundBody.
  ///
  /// In he, this message translates to:
  /// **'כך נוכל להודיע לך ברגע שחבר מתפנה, ולזהות נסיעה, גם כשהאפליקציה סגורה. ברקע היא עובדת רק כשסימנת שיש לך זמן או בזמן נסיעה.'**
  String get backgroundBody;

  /// No description provided for @backgroundAllow.
  ///
  /// In he, this message translates to:
  /// **'להפעיל'**
  String get backgroundAllow;

  /// No description provided for @addNumberTitle.
  ///
  /// In he, this message translates to:
  /// **'שחברים ימצאו אותך'**
  String get addNumberTitle;

  /// No description provided for @addNumberBody.
  ///
  /// In he, this message translates to:
  /// **'בלי מספר טלפון חברים לא ימצאו אותך באנשי הקשר, ואי אפשר להתקשר אליך בשיחה רגילה. המספר נמסר לחבר רק אחרי ששניכם אמרתם \"כן\".'**
  String get addNumberBody;

  /// No description provided for @addNumberGo.
  ///
  /// In he, this message translates to:
  /// **'להוסיף מספר'**
  String get addNumberGo;

  /// No description provided for @newFriendTitle.
  ///
  /// In he, this message translates to:
  /// **'חדש ברשימה שלך: {name}'**
  String newFriendTitle(String name);

  /// No description provided for @newFriendBody.
  ///
  /// In he, this message translates to:
  /// **'התחברתם — מאנשי הקשר או מהזמנה. מעכשיו תוכלו לקבל הצעה לדבר כששניכם פנויים.'**
  String get newFriendBody;

  /// No description provided for @newFriendGroup.
  ///
  /// In he, this message translates to:
  /// **'לבחור קבוצה'**
  String get newFriendGroup;

  /// No description provided for @newFriendOk.
  ///
  /// In he, this message translates to:
  /// **'מעולה'**
  String get newFriendOk;

  /// No description provided for @notNowShort.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get notNowShort;

  /// No description provided for @firstRunRoutineTitle.
  ///
  /// In he, this message translates to:
  /// **'באילו שעות יש לך בדרך כלל נסיעה?'**
  String get firstRunRoutineTitle;

  /// No description provided for @firstRunRoutineBody.
  ///
  /// In he, this message translates to:
  /// **'מסמנים שעה אחת או יותר. בימים א׳–ה׳, בשעה הזו, נסמן שיש לך זמן — לחצי שעה. את השעה משנים בלחיצה על העיפרון, ואפשר לשנות הכול גם בהגדרות ← השגרה שלי.'**
  String get firstRunRoutineBody;

  /// No description provided for @firstRunRoutineMorning.
  ///
  /// In he, this message translates to:
  /// **'בוקר · {time} · בדרך לעבודה'**
  String firstRunRoutineMorning(String time);

  /// No description provided for @firstRunRoutineEvening.
  ///
  /// In he, this message translates to:
  /// **'ערב · {time} · בדרך הביתה'**
  String firstRunRoutineEvening(String time);

  /// No description provided for @firstRunRoutineNone.
  ///
  /// In he, this message translates to:
  /// **'לא קבוע'**
  String get firstRunRoutineNone;

  /// No description provided for @statsTitle.
  ///
  /// In he, this message translates to:
  /// **'מספרים'**
  String get statsTitle;

  /// No description provided for @statsFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לטעון. אם זה חוזר, צריך להכניס שוב את קוד הניהול (לחיצה ארוכה על \"בדיקת עדכון\").'**
  String get statsFailed;

  /// No description provided for @statsWeek.
  ///
  /// In he, this message translates to:
  /// **'7 ימים'**
  String get statsWeek;

  /// No description provided for @statsMonth.
  ///
  /// In he, this message translates to:
  /// **'30 ימים'**
  String get statsMonth;

  /// No description provided for @statsUsers.
  ///
  /// In he, this message translates to:
  /// **'אנשים באפליקציה'**
  String get statsUsers;

  /// No description provided for @statsNewUsers.
  ///
  /// In he, this message translates to:
  /// **'הצטרפו'**
  String get statsNewUsers;

  /// No description provided for @statsActiveUsers.
  ///
  /// In he, this message translates to:
  /// **'נכנסו לאפליקציה'**
  String get statsActiveUsers;

  /// No description provided for @statsFriendships.
  ///
  /// In he, this message translates to:
  /// **'חברויות'**
  String get statsFriendships;

  /// No description provided for @statsFreeTimes.
  ///
  /// In he, this message translates to:
  /// **'\"יש לי זמן\"'**
  String get statsFreeTimes;

  /// No description provided for @statsOffers.
  ///
  /// In he, this message translates to:
  /// **'הצעות לדבר'**
  String get statsOffers;

  /// No description provided for @statsQuick.
  ///
  /// In he, this message translates to:
  /// **'חיבורים מהירים'**
  String get statsQuick;

  /// No description provided for @statsBothYes.
  ///
  /// In he, this message translates to:
  /// **'שניהם אמרו כן'**
  String get statsBothYes;

  /// No description provided for @statsTalked.
  ///
  /// In he, this message translates to:
  /// **'דיברו בפועל'**
  String get statsTalked;

  /// No description provided for @statsDeclined.
  ///
  /// In he, this message translates to:
  /// **'\"לא עכשיו\"'**
  String get statsDeclined;

  /// No description provided for @statsLater.
  ///
  /// In he, this message translates to:
  /// **'\"אחזור אליך\"'**
  String get statsLater;

  /// No description provided for @statsNoAnswer.
  ///
  /// In he, this message translates to:
  /// **'בלי תשובה'**
  String get statsNoAnswer;

  /// No description provided for @statsDialMs.
  ///
  /// In he, this message translates to:
  /// **'כמה מהר מתחיל החיוג'**
  String get statsDialMs;

  /// No description provided for @statsSeconds.
  ///
  /// In he, this message translates to:
  /// **'שנ׳'**
  String get statsSeconds;

  /// No description provided for @statsNote.
  ///
  /// In he, this message translates to:
  /// **'רק סכומים. בלי שמות, בלי מספרים, ובלי שום מידע על אדם מסוים.'**
  String get statsNote;

  /// No description provided for @statsReports.
  ///
  /// In he, this message translates to:
  /// **'דיווחים'**
  String get statsReports;

  /// No description provided for @realInviteStore.
  ///
  /// In he, this message translates to:
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveBond — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה מ-Google Play: {url}'**
  String realInviteStore(String url);

  /// No description provided for @inactiveDays.
  ///
  /// In he, this message translates to:
  /// **'בלי כניסה כבר {days} ימים'**
  String inactiveDays(int days);

  /// No description provided for @inactiveMonth.
  ///
  /// In he, this message translates to:
  /// **'בלי כניסה יותר מחודש'**
  String get inactiveMonth;

  /// No description provided for @feedbackTitle.
  ///
  /// In he, this message translates to:
  /// **'שליחת משוב'**
  String get feedbackTitle;

  /// No description provided for @feedbackBody.
  ///
  /// In he, this message translates to:
  /// **'משהו לא עובד? רעיון? זה מגיע ישר אלינו.'**
  String get feedbackBody;

  /// No description provided for @feedbackHint.
  ///
  /// In he, this message translates to:
  /// **'מה כדאי לשפר?'**
  String get feedbackHint;

  /// No description provided for @feedbackSend.
  ///
  /// In he, this message translates to:
  /// **'לשלוח'**
  String get feedbackSend;

  /// No description provided for @statsFeedback.
  ///
  /// In he, this message translates to:
  /// **'משובים'**
  String get statsFeedback;

  /// No description provided for @statsReportsTitle.
  ///
  /// In he, this message translates to:
  /// **'דיווחים אחרונים'**
  String get statsReportsTitle;

  /// No description provided for @statsFeedbackTitle.
  ///
  /// In he, this message translates to:
  /// **'משובים אחרונים'**
  String get statsFeedbackTitle;

  /// No description provided for @statsNotesEmpty.
  ///
  /// In he, this message translates to:
  /// **'עוד אין כאן כלום'**
  String get statsNotesEmpty;

  /// No description provided for @statsNotesFailed.
  ///
  /// In he, this message translates to:
  /// **'אין גישה. צריך להכניס שוב את קוד הניהול: הגדרות ← לחיצה ארוכה על \"בדיקת עדכון\".'**
  String get statsNotesFailed;

  /// No description provided for @firstRunRoutineChangeTime.
  ///
  /// In he, this message translates to:
  /// **'לשנות שעה'**
  String get firstRunRoutineChangeTime;

  /// A friend who is free but on a call right now
  ///
  /// In he, this message translates to:
  /// **'בשיחה'**
  String get inCall;

  /// No description provided for @close.
  ///
  /// In he, this message translates to:
  /// **'סגירה'**
  String get close;

  /// No description provided for @firstRunPhotoTitle.
  ///
  /// In he, this message translates to:
  /// **'תמונה, כדי שיזהו אותך'**
  String get firstRunPhotoTitle;

  /// No description provided for @firstRunPhotoBody.
  ///
  /// In he, this message translates to:
  /// **'רשות. רק החברים שלך רואים אותה.'**
  String get firstRunPhotoBody;

  /// No description provided for @firstRunPhotoGo.
  ///
  /// In he, this message translates to:
  /// **'לבחור תמונה'**
  String get firstRunPhotoGo;

  /// No description provided for @firstRunPhotoLater.
  ///
  /// In he, this message translates to:
  /// **'אפשר להוסיף או להחליף בכל זמן: הגדרות ← לחיצה על השם שלך ← \"התמונה שלי\".'**
  String get firstRunPhotoLater;

  /// No description provided for @peopleAsleepTitle.
  ///
  /// In he, this message translates to:
  /// **'לא פתחו את האפליקציה חודש ({count})'**
  String peopleAsleepTitle(int count);

  /// No description provided for @peopleAsleepBody.
  ///
  /// In he, this message translates to:
  /// **'חוזרים לרשימה לבד כשהם פותחים שוב.'**
  String get peopleAsleepBody;

  /// No description provided for @removedTitle.
  ///
  /// In he, this message translates to:
  /// **'אנשים שהסרתי'**
  String get removedTitle;

  /// No description provided for @removedBody.
  ///
  /// In he, this message translates to:
  /// **'אפשר להחזיר — וחוזרים להיות חברים מיד.'**
  String get removedBody;

  /// No description provided for @removedEmpty.
  ///
  /// In he, this message translates to:
  /// **'לא הסרת אף אחד.'**
  String get removedEmpty;

  /// No description provided for @removedRestore.
  ///
  /// In he, this message translates to:
  /// **'להחזיר'**
  String get removedRestore;

  /// No description provided for @statsUsersHint.
  ///
  /// In he, this message translates to:
  /// **'כל מי שנרשם אי פעם (אדם אחד לכל מספר טלפון)'**
  String get statsUsersHint;

  /// No description provided for @statsNewUsersHint.
  ///
  /// In he, this message translates to:
  /// **'נרשמו לראשונה בתקופה הזו'**
  String get statsNewUsersHint;

  /// No description provided for @statsActiveUsersHint.
  ///
  /// In he, this message translates to:
  /// **'פתחו אותה לפחות פעם אחת בתקופה'**
  String get statsActiveUsersHint;

  /// No description provided for @statsFriendshipsHint.
  ///
  /// In he, this message translates to:
  /// **'כמה זוגות חברים מחוברים באפליקציה (בסך הכול)'**
  String get statsFriendshipsHint;

  /// No description provided for @statsFreeTimesHint.
  ///
  /// In he, this message translates to:
  /// **'כמה פעמים מישהו סימן שהוא פנוי'**
  String get statsFreeTimesHint;

  /// No description provided for @statsOffersHint.
  ///
  /// In he, this message translates to:
  /// **'כמה פעמים הצענו לשני חברים פנויים לדבר'**
  String get statsOffersHint;

  /// No description provided for @statsQuickHint.
  ///
  /// In he, this message translates to:
  /// **'שיחות שהתחילו בלי לשאול (שני הצדדים הסכימו מראש)'**
  String get statsQuickHint;

  /// No description provided for @statsBothYesHint.
  ///
  /// In he, this message translates to:
  /// **'הצעות שהפכו לשיחה'**
  String get statsBothYesHint;

  /// No description provided for @statsTalkedHint.
  ///
  /// In he, this message translates to:
  /// **'לפי מה שענו אחרי השיחה'**
  String get statsTalkedHint;

  /// No description provided for @statsDeclinedHint.
  ///
  /// In he, this message translates to:
  /// **'אחד הצדדים סירב להצעה'**
  String get statsDeclinedHint;

  /// No description provided for @statsLaterHint.
  ///
  /// In he, this message translates to:
  /// **'מתוך ה\"לא עכשיו\"'**
  String get statsLaterHint;

  /// No description provided for @statsNoAnswerHint.
  ///
  /// In he, this message translates to:
  /// **'אף אחד לא ענה בזמן'**
  String get statsNoAnswerHint;

  /// No description provided for @statsReportsHint.
  ///
  /// In he, this message translates to:
  /// **'דיווחים על משתמשים. לחיצה לפרטים'**
  String get statsReportsHint;

  /// No description provided for @statsFeedbackHint.
  ///
  /// In he, this message translates to:
  /// **'הודעות שנשלחו אליך מתוך האפליקציה. לחיצה לפרטים'**
  String get statsFeedbackHint;

  /// No description provided for @statsCrashes.
  ///
  /// In he, this message translates to:
  /// **'קריסות'**
  String get statsCrashes;

  /// No description provided for @statsCrashesHint.
  ///
  /// In he, this message translates to:
  /// **'תקלות שהאפליקציה דיווחה עליהן לבד. לחיצה לפרטים'**
  String get statsCrashesHint;

  /// No description provided for @statsDialMsHint.
  ///
  /// In he, this message translates to:
  /// **'מה\"כן\" השני ועד שהטלפון מחייג (בדרך כלל)'**
  String get statsDialMsHint;

  /// No description provided for @statsCrashesTitle.
  ///
  /// In he, this message translates to:
  /// **'קריסות אחרונות'**
  String get statsCrashesTitle;

  /// No description provided for @askTitle.
  ///
  /// In he, this message translates to:
  /// **'לדבר עם {name} עכשיו?'**
  String askTitle(String name);

  /// No description provided for @askBody.
  ///
  /// In he, this message translates to:
  /// **'נשאל אם מתאים עכשיו. אם כן, מתחילים לדבר.'**
  String get askBody;

  /// No description provided for @askBodyNotFree.
  ///
  /// In he, this message translates to:
  /// **'נסמן שגם לך יש זמן (30 דקות), ונשאל אם מתאים עכשיו.'**
  String get askBodyNotFree;

  /// No description provided for @askYes.
  ///
  /// In he, this message translates to:
  /// **'כן, לשאול'**
  String get askYes;

  /// No description provided for @askNotFree.
  ///
  /// In he, this message translates to:
  /// **'נראה של{name} כבר אין זמן כרגע.'**
  String askNotFree(String name);

  /// No description provided for @askBusy.
  ///
  /// In he, this message translates to:
  /// **'ל{name} לא מתאים ממש עכשיו. נציע כשיתאים.'**
  String askBusy(String name);

  /// No description provided for @askNotNow.
  ///
  /// In he, this message translates to:
  /// **'כבר שאלנו את {name} הפעם. נחכה לפעם הבאה.'**
  String askNotNow(String name);

  /// No description provided for @askCallOpen.
  ///
  /// In he, this message translates to:
  /// **'השיחה האחרונה שלך עם {name} עוד לא נסגרה. ברגע שאחד מכם עונה \"איך היה?\" או שהשיחה מתנתקת, אפשר לפנות שוב.'**
  String askCallOpen(String name);

  /// No description provided for @askNoNumber.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר להתקשר: לאף אחד מכם אין מספר טלפון באפליקציה.'**
  String get askNoNumber;

  /// No description provided for @askMeNotFree.
  ///
  /// In he, this message translates to:
  /// **'קודם צריך לסמן שיש לך זמן.'**
  String get askMeNotFree;

  /// No description provided for @askFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לשאול עכשיו. אפשר לנסות שוב.'**
  String get askFailed;

  /// No description provided for @friendKept.
  ///
  /// In he, this message translates to:
  /// **'{name} ברשימה שלך'**
  String friendKept(String name);

  /// No description provided for @hiddenFreeLine.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{ועוד חבר אחד פנוי, בלי שם} other{ועוד {count} חברים פנויים, בלי שם}}'**
  String hiddenFreeLine(int count);

  /// No description provided for @anonymousSeeNote.
  ///
  /// In he, this message translates to:
  /// **'בחרת להופיע בלי שם, ולכן גם כאן רואים רק כמה פנויים.'**
  String get anonymousSeeNote;

  /// No description provided for @missedTitle.
  ///
  /// In he, this message translates to:
  /// **'לא ענית, אז הפסקנו להציע אותך.'**
  String get missedTitle;

  /// No description provided for @missedBody.
  ///
  /// In he, this message translates to:
  /// **'בינתיים החברים לא רואים שיש לך זמן. עדיין יש לך זמן?'**
  String get missedBody;

  /// No description provided for @missedYes.
  ///
  /// In he, this message translates to:
  /// **'כן, יש לי זמן'**
  String get missedYes;

  /// No description provided for @missedNo.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get missedNo;

  /// No description provided for @autoMissedTitle.
  ///
  /// In he, this message translates to:
  /// **'בנסיעות האחרונות לא ענית.'**
  String get autoMissedTitle;

  /// No description provided for @autoMissedBody.
  ///
  /// In he, this message translates to:
  /// **'להשאיר את הזיהוי האוטומטי של נסיעות?'**
  String get autoMissedBody;

  /// No description provided for @autoMissedKeep.
  ///
  /// In he, this message translates to:
  /// **'להשאיר'**
  String get autoMissedKeep;

  /// No description provided for @autoMissedOff.
  ///
  /// In he, this message translates to:
  /// **'לכבות'**
  String get autoMissedOff;

  /// No description provided for @graceTitle.
  ///
  /// In he, this message translates to:
  /// **'כמה דקות להתארגן'**
  String get graceTitle;

  /// No description provided for @graceBody.
  ///
  /// In he, this message translates to:
  /// **'אחר כך נציע שיחה, אם מישהו פנוי.'**
  String get graceBody;

  /// No description provided for @graceReady.
  ///
  /// In he, this message translates to:
  /// **'אפשר כבר עכשיו'**
  String get graceReady;

  /// No description provided for @graceNotThisTrip.
  ///
  /// In he, this message translates to:
  /// **'לא בנסיעה הזו'**
  String get graceNotThisTrip;

  /// No description provided for @extendButton.
  ///
  /// In he, this message translates to:
  /// **'להאריך'**
  String get extendButton;

  /// No description provided for @extendTitle.
  ///
  /// In he, this message translates to:
  /// **'להאריך בעוד…'**
  String get extendTitle;

  /// No description provided for @extendBy.
  ///
  /// In he, this message translates to:
  /// **'+{minutes} דק׳'**
  String extendBy(int minutes);

  /// No description provided for @durationUntilTime.
  ///
  /// In he, this message translates to:
  /// **'עד שעה…'**
  String get durationUntilTime;

  /// No description provided for @durationUntilTimeCapped.
  ///
  /// In he, this message translates to:
  /// **'אפשר עד 3 שעות, אז סימנו עד {time}.'**
  String durationUntilTimeCapped(String time);

  /// No description provided for @pendingTitle.
  ///
  /// In he, this message translates to:
  /// **'הצטרפת לרשימה של {name}'**
  String pendingTitle(String name);

  /// No description provided for @pendingBody.
  ///
  /// In he, this message translates to:
  /// **'המספר של {name} לא שמור אצלך, ולכן {name} עוד לא רואה מתי יש לך זמן. להשאיר ברשימה?'**
  String pendingBody(String name);

  /// No description provided for @pendingKeep.
  ///
  /// In he, this message translates to:
  /// **'להשאיר'**
  String get pendingKeep;

  /// No description provided for @pendingRemove.
  ///
  /// In he, this message translates to:
  /// **'להסיר'**
  String get pendingRemove;

  /// No description provided for @offerShared.
  ///
  /// In he, this message translates to:
  /// **'שניכם פנויים עוד כ-{minutes} דק׳'**
  String offerShared(int minutes);

  /// No description provided for @offerLastTalkToday.
  ///
  /// In he, this message translates to:
  /// **'כבר דיברתם היום'**
  String get offerLastTalkToday;

  /// No description provided for @offerLastTalkDays.
  ///
  /// In he, this message translates to:
  /// **'{days, plural, =1{דיברתם אתמול} other{דיברתם לפני {days} ימים}}'**
  String offerLastTalkDays(int days);

  /// No description provided for @offerLastTalkDate.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם מאז {date}'**
  String offerLastTalkDate(String date);

  /// No description provided for @offerFirstTalk.
  ///
  /// In he, this message translates to:
  /// **'זו תהיה השיחה הראשונה שלכם כאן'**
  String get offerFirstTalk;

  /// No description provided for @waitOther.
  ///
  /// In he, this message translates to:
  /// **'לדבר עם מישהו אחר'**
  String get waitOther;

  /// No description provided for @settingsAnonymous.
  ///
  /// In he, this message translates to:
  /// **'להופיע בלי שם כשיש לי זמן'**
  String get settingsAnonymous;

  /// No description provided for @settingsAnonymousHint.
  ///
  /// In he, this message translates to:
  /// **'החברים רואים רק כמה חברים פנויים, לא מי. כך גם אצלך: רק כמה פנויים. בהצעה לדבר השם תמיד מופיע.'**
  String get settingsAnonymousHint;

  /// No description provided for @settingsHideInCall.
  ///
  /// In he, this message translates to:
  /// **'להסתיר כשאני בשיחה'**
  String get settingsHideInCall;

  /// No description provided for @settingsHideInCallHint.
  ///
  /// In he, this message translates to:
  /// **'בזמן שיחה החברים לא יראו שיש לך זמן. זה הדדי: גם לך לא יופיעו חברים שנמצאים בשיחה.'**
  String get settingsHideInCallHint;

  /// No description provided for @settingsQuietHours.
  ///
  /// In he, this message translates to:
  /// **'שעות שקטות'**
  String get settingsQuietHours;

  /// No description provided for @settingsQuietOff.
  ///
  /// In he, this message translates to:
  /// **'בלי שעות שקטות. בנסיעה שמזוהה לבד, אפשר לקבל הצעות בכל שעה.'**
  String get settingsQuietOff;

  /// No description provided for @settingsQuietOn.
  ///
  /// In he, this message translates to:
  /// **'בין השעה {from} לשעה {to}, בנסיעה שמזוהה לבד לא נסמן אותך פנוי.'**
  String settingsQuietOn(String from, String to);

  /// No description provided for @quietPickFrom.
  ///
  /// In he, this message translates to:
  /// **'מאיזו שעה?'**
  String get quietPickFrom;

  /// No description provided for @quietPickTo.
  ///
  /// In he, this message translates to:
  /// **'עד איזו שעה?'**
  String get quietPickTo;

  /// No description provided for @quietClear.
  ///
  /// In he, this message translates to:
  /// **'לבטל שעות שקטות'**
  String get quietClear;

  /// No description provided for @quietSet.
  ///
  /// In he, this message translates to:
  /// **'לבחור שעות'**
  String get quietSet;

  /// No description provided for @realNotifChannelTalk.
  ///
  /// In he, this message translates to:
  /// **'הצעות לדבר'**
  String get realNotifChannelTalk;

  /// No description provided for @driverFreeTitle.
  ///
  /// In he, this message translates to:
  /// **'מי פנוי עכשיו'**
  String get driverFreeTitle;

  /// No description provided for @driverFreeHint.
  ///
  /// In he, this message translates to:
  /// **'לוחצים על חבר, ונשאל אותו.'**
  String get driverFreeHint;

  /// No description provided for @driverNobody.
  ///
  /// In he, this message translates to:
  /// **'עוד אין חבר פנוי'**
  String get driverNobody;

  /// No description provided for @driverNobodyBody.
  ///
  /// In he, this message translates to:
  /// **'כשמישהו יתפנה, נציע לכם לדבר.'**
  String get driverNobodyBody;

  /// No description provided for @driverNormalView.
  ///
  /// In he, this message translates to:
  /// **'למסך הרגיל'**
  String get driverNormalView;

  /// No description provided for @driverBack.
  ///
  /// In he, this message translates to:
  /// **'חזרה למסך הנהיגה'**
  String get driverBack;

  /// No description provided for @freeNotNow.
  ///
  /// In he, this message translates to:
  /// **'לא כרגע'**
  String get freeNotNow;

  /// No description provided for @freeNotNowTitle.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר לפנות ל{name} כרגע'**
  String freeNotNowTitle(String name);

  /// No description provided for @freeNotNowBody.
  ///
  /// In he, this message translates to:
  /// **'ממש עכשיו אי אפשר להציע שיחה (למשל בתחילת נסיעה, או כשכבר שאלתם הפעם). כשזה יתאפשר, זה יופיע כרגיל.'**
  String get freeNotNowBody;

  /// No description provided for @freeNotNowMine.
  ///
  /// In he, this message translates to:
  /// **'זה בגלל שעוד לא אישרת את {name} ברשימה שלך. אחרי האישור אפשר לדבר מיד.'**
  String freeNotNowMine(String name);

  /// No description provided for @afterCallTitle.
  ///
  /// In he, this message translates to:
  /// **'מתי להציע לך שוב את {name}?'**
  String afterCallTitle(String name);

  /// No description provided for @afterCallNote.
  ///
  /// In he, this message translates to:
  /// **'בינתיים אפשר תמיד ללחוץ על {name} ולשאול בעצמך.'**
  String afterCallNote(String name);

  /// No description provided for @afterCallAny.
  ///
  /// In he, this message translates to:
  /// **'בכל זמן'**
  String get afterCallAny;

  /// No description provided for @afterCallTomorrow.
  ///
  /// In he, this message translates to:
  /// **'מחר'**
  String get afterCallTomorrow;

  /// No description provided for @afterCall3.
  ///
  /// In he, this message translates to:
  /// **'בעוד 3 ימים'**
  String get afterCall3;

  /// No description provided for @afterCallWeek.
  ///
  /// In he, this message translates to:
  /// **'בעוד שבוע'**
  String get afterCallWeek;

  /// No description provided for @afterCallNoTalk.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לדבר'**
  String get afterCallNoTalk;

  /// No description provided for @directTitle.
  ///
  /// In he, this message translates to:
  /// **'{name} רוצה לדבר איתך'**
  String directTitle(String name);

  /// No description provided for @directAsk.
  ///
  /// In he, this message translates to:
  /// **'מתאים לך עכשיו?'**
  String get directAsk;

  /// No description provided for @directAskShort.
  ///
  /// In he, this message translates to:
  /// **'רוצה לדבר איתך. לענות?'**
  String get directAskShort;

  /// No description provided for @voiceDirect.
  ///
  /// In he, this message translates to:
  /// **'{name} רוצה לדבר איתך. לענות?'**
  String voiceDirect(String name);

  /// On the call screen: leave it for the main screen during the call
  ///
  /// In he, this message translates to:
  /// **'למסך הראשי'**
  String get callToMain;

  /// Banner on the main screen during a call
  ///
  /// In he, this message translates to:
  /// **'בשיחה עם {name} · חזרה למסך השיחה'**
  String callBackToCall(String name);

  /// Spoken in the background (no voice answer possible there)
  ///
  /// In he, this message translates to:
  /// **'ל{name} יש זמן לדבר. אם מתאים — \"לדבר\" בהתראה.'**
  String bgVoiceOffer(String name);

  /// Spoken in the background when a friend tapped me
  ///
  /// In he, this message translates to:
  /// **'{name} רוצה לדבר איתך. אם מתאים — \"לדבר\" בהתראה.'**
  String bgVoiceDirect(String name);

  /// Locked screen: an offer, without the name
  ///
  /// In he, this message translates to:
  /// **'מישהו פנוי לדבר עכשיו'**
  String get notifPublicTalk;

  /// After "Talk" from the notification: they call me
  ///
  /// In he, this message translates to:
  /// **'שיחה מ{name} בדרך. הטלפון יצלצל.'**
  String answeredTheyCall(String name);

  /// After "Talk": I have to dial (tap opens the app)
  ///
  /// In he, this message translates to:
  /// **'גם {name} רוצה לדבר. לחיצה כאן — ומתקשרים.'**
  String answeredYouCall(String name);

  /// After "Talk": the other side has not answered yet
  ///
  /// In he, this message translates to:
  /// **'מחכים לתשובה מ{name}.'**
  String answeredWaiting(String name);

  /// After "Talk": too late / did not work out
  ///
  /// In he, this message translates to:
  /// **'לא הסתדר הפעם. נציע שוב בהזדמנות אחרת.'**
  String get answeredMissed;

  /// Spoken: I have to dial
  ///
  /// In he, this message translates to:
  /// **'גם {name} רוצה לדבר. לחיצה על ההתראה — ומתקשרים.'**
  String voiceYouCall(String name);

  /// Permissions step title
  ///
  /// In he, this message translates to:
  /// **'כדי שזה יעבוד גם בנסיעה'**
  String get permsTitle;

  /// Permissions step body
  ///
  /// In he, this message translates to:
  /// **'כמה אישורים מהטלפון, פעם אחת עכשיו, כדי שלא יקפצו שאלות באמצע נסיעה.'**
  String get permsBody;

  /// Ask for all the permissions one after the other
  ///
  /// In he, this message translates to:
  /// **'לאשר הכול'**
  String get permsAllowAll;

  /// Ask for one permission
  ///
  /// In he, this message translates to:
  /// **'לאשר'**
  String get permsAllowOne;

  /// A permission that is already given
  ///
  /// In he, this message translates to:
  /// **'מאושר'**
  String get permsDone;

  ///
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get permsNotifTitle;

  ///
  ///
  /// In he, this message translates to:
  /// **'כדי לדעת כשחבר פנוי, גם כשהאפליקציה סגורה.'**
  String get permsNotifBody;

  ///
  ///
  /// In he, this message translates to:
  /// **'שיחות טלפון'**
  String get permsCallTitle;

  ///
  ///
  /// In he, this message translates to:
  /// **'כדי שהשיחה תצא מיד כששניכם אומרים כן.'**
  String get permsCallBody;

  ///
  ///
  /// In he, this message translates to:
  /// **'מיקרופון'**
  String get permsMicTitle;

  ///
  ///
  /// In he, this message translates to:
  /// **'כדי לענות \"כן\" או \"לא\" בקול בנהיגה. שום דבר לא מוקלט.'**
  String get permsMicBody;

  ///
  ///
  /// In he, this message translates to:
  /// **'עבודה ברקע'**
  String get permsBgTitle;

  ///
  ///
  /// In he, this message translates to:
  /// **'כדי שחיסכון הסוללה לא יעצור את ההתראות באמצע נסיעה.'**
  String get permsBgBody;

  ///
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה (רשות)'**
  String get permsAutoTitle;

  ///
  ///
  /// In he, this message translates to:
  /// **'כשהטלפון ברכב, נסמן שיש לך זמן. בלי GPS. אפשר לכבות בכל רגע.'**
  String get permsAutoBody;

  /// Settings entry for the permissions screen
  ///
  /// In he, this message translates to:
  /// **'הרשאות'**
  String get permsSettings;

  /// Settings entry subtitle
  ///
  /// In he, this message translates to:
  /// **'התראות, שיחות, מיקרופון, עבודה ברקע'**
  String get permsSettingsBody;

  /// After "Talk": the answer did not go through; tap to answer in the app
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לענות מכאן. לחיצה כאן — עונים באפליקציה.'**
  String get answeredRetry;

  /// Quick connect switch title
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר'**
  String get quickTitle;

  /// quickOffBody
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים, השיחה יוצאת לבד. 5 שניות לבטל.'**
  String get quickOffBody;

  /// quickWaitingBody
  ///
  /// In he, this message translates to:
  /// **'מופעל אצלך. יעבוד כשזה יופעל גם אצל {name}.'**
  String quickWaitingBody(String name);

  /// quickBothBody
  ///
  /// In he, this message translates to:
  /// **'פעיל אצל שניכם. כששניכם פנויים, השיחה יוצאת לבד.'**
  String get quickBothBody;

  /// quickConfirmTitle
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר עם {name}?'**
  String quickConfirmTitle(String name);

  /// quickConfirmBody
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים, השיחה יוצאת לבד, בלי שאלה. יש 5 שניות לבטל: אם אחד מכם מבטל, השיחה לא יוצאת.\n\nבאפליקציה של {name} תופיע הצעה להפעיל גם.'**
  String quickConfirmBody(String name);

  /// quickTurnOn
  ///
  /// In he, this message translates to:
  /// **'להפעיל'**
  String get quickTurnOn;

  /// quickAskTitle
  ///
  /// In he, this message translates to:
  /// **'{name} רוצה חיבור מהיר איתך'**
  String quickAskTitle(String name);

  /// quickAskBody
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים, השיחה תצא לבד, בלי לשאול. לשניכם יש 5 שניות לבטל.'**
  String get quickAskBody;

  /// quickAskYes
  ///
  /// In he, this message translates to:
  /// **'להפעיל גם'**
  String get quickAskYes;

  /// quickIntroTitle
  ///
  /// In he, this message translates to:
  /// **'חדש: חיבור מהיר'**
  String get quickIntroTitle;

  /// quickIntroBody
  ///
  /// In he, this message translates to:
  /// **'לחברים הכי קרובים: כששניכם פנויים, השיחה יוצאת לבד, בלי לשאול. 5 שניות לבטל.'**
  String get quickIntroBody;

  /// quickIntroPick
  ///
  /// In he, this message translates to:
  /// **'לבחור חברים'**
  String get quickIntroPick;

  /// quickPickTitle
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר עם…'**
  String get quickPickTitle;

  /// Switch subtitle: the friend turned it on, I did not
  ///
  /// In he, this message translates to:
  /// **'אצל {name} חיבור מהיר איתך כבר פועל. להפעיל גם?'**
  String quickTheyWantBody(String name);

  /// Friend list: this friend turned quick connect on for me
  ///
  /// In he, this message translates to:
  /// **'רוצה חיבור מהיר'**
  String get quickTheyWantChip;

  /// Friend card: my pause for this friend
  ///
  /// In he, this message translates to:
  /// **'הצעות מושהות {when}'**
  String pauseTitle(String when);

  /// pauseBody
  ///
  /// In he, this message translates to:
  /// **'אפשר תמיד ללחוץ על {name} ולשאול בעצמך.'**
  String pauseBody(String name);

  /// pauseQuickNote
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר עובד גם בזמן ההשהיה.'**
  String get pauseQuickNote;

  /// pauseCancel
  ///
  /// In he, this message translates to:
  /// **'לבטל'**
  String get pauseCancel;

  /// Friend list: suggestions paused
  ///
  /// In he, this message translates to:
  /// **'מושהה {when}'**
  String pauseChip(String when);

  /// pauseUntilTime
  ///
  /// In he, this message translates to:
  /// **'עד {time}'**
  String pauseUntilTime(String time);

  /// pauseUntilTomorrow
  ///
  /// In he, this message translates to:
  /// **'עד מחר'**
  String get pauseUntilTomorrow;

  /// pauseUntilDay
  ///
  /// In he, this message translates to:
  /// **'עד יום {day}'**
  String pauseUntilDay(String day);

  /// pause until a date
  ///
  /// In he, this message translates to:
  /// **'עד {date}'**
  String pauseUntilDate(String date);

  /// No description provided for @settingsPrivacyInfo.
  ///
  /// In he, this message translates to:
  /// **'מה נשמר עליי'**
  String get settingsPrivacyInfo;

  /// No description provided for @permsPhoneNotif.
  ///
  /// In he, this message translates to:
  /// **'הגדרות ההתראות בטלפון'**
  String get permsPhoneNotif;

  /// No description provided for @realCirclesNone.
  ///
  /// In he, this message translates to:
  /// **'משפחה, עבודה, חברים קרובים: מי רואה שיש לך זמן'**
  String get realCirclesNone;

  /// No description provided for @routineAskTitle.
  ///
  /// In he, this message translates to:
  /// **'השגרה שלך: יש לך זמן עכשיו?'**
  String get routineAskTitle;

  /// No description provided for @routineAskBody.
  ///
  /// In he, this message translates to:
  /// **'בלחיצה על \"כן\" נסמן שיש לך זמן ל-{minutes} דק׳.'**
  String routineAskBody(String minutes);

  /// No description provided for @routineAskYes.
  ///
  /// In he, this message translates to:
  /// **'כן, יש לי זמן'**
  String get routineAskYes;

  /// No description provided for @othersRuleTitle.
  ///
  /// In he, this message translates to:
  /// **'חברים שלא בשום קבוצה: מתי הם יראו שיש לך זמן?'**
  String get othersRuleTitle;

  /// No description provided for @pasteCode.
  ///
  /// In he, this message translates to:
  /// **'הדבקה'**
  String get pasteCode;

  /// No description provided for @realCallEnded.
  ///
  /// In he, this message translates to:
  /// **'השיחה הסתיימה'**
  String get realCallEnded;

  /// No description provided for @realTapOrWait.
  ///
  /// In he, this message translates to:
  /// **'אפשר ללחוץ על חבר פנוי, או לחכות שנציע.'**
  String get realTapOrWait;

  /// No description provided for @driverMyTimeLeft.
  ///
  /// In he, this message translates to:
  /// **'הזמן הפנוי שלך: עוד {minutes} דק׳'**
  String driverMyTimeLeft(int minutes);

  /// No description provided for @durationTripNoteDetected.
  ///
  /// In he, this message translates to:
  /// **'נגמר לבד כשהנסיעה נגמרת (ולכל היותר אחרי {hours} שעות).'**
  String durationTripNoteDetected(int hours);

  /// After a call, above "when to suggest X again?"
  ///
  /// In he, this message translates to:
  /// **'מקווים שהשיחה הייתה טובה 🙂'**
  String get afterCallHope;

  /// After a call: opens the feedback note
  ///
  /// In he, this message translates to:
  /// **'יש משוב או תובנה? אפשר לכתוב לנו, ונשפר'**
  String get afterCallWrite;

  /// Waiting screen countdown
  ///
  /// In he, this message translates to:
  /// **'{seconds, plural, =1{עוד שנייה} other{עוד {seconds} שניות}}'**
  String realWaitingLeft(int seconds);

  /// My people: one button for every way to add a friend
  ///
  /// In he, this message translates to:
  /// **'הוספת חבר'**
  String get addFriend;

  /// No description provided for @addFriendInviteBody.
  ///
  /// In he, this message translates to:
  /// **'שולחים קישור בוואטסאפ או בהודעה'**
  String get addFriendInviteBody;

  /// No description provided for @addFriendCodeBody.
  ///
  /// In he, this message translates to:
  /// **'קיבלת הזמנה בלי קישור? מכניסים כאן את הקוד'**
  String get addFriendCodeBody;

  /// No description provided for @addFriendContactsBody.
  ///
  /// In he, this message translates to:
  /// **'רואים מי מאנשי הקשר כבר כאן, ובוחרים'**
  String get addFriendContactsBody;

  /// Android notification channel for "X is on the way" (D-119)
  ///
  /// In he, this message translates to:
  /// **'חברים יוצאים לדרך'**
  String get tripNotifChannel;

  /// No description provided for @tripNotifTitle.
  ///
  /// In he, this message translates to:
  /// **'{name} בדרך'**
  String tripNotifTitle(String name);

  /// No description provided for @tripNotifBody.
  ///
  /// In he, this message translates to:
  /// **'יש זמן לדבר עכשיו'**
  String get tripNotifBody;

  /// No description provided for @tripNotifTalk.
  ///
  /// In he, this message translates to:
  /// **'לדבר'**
  String get tripNotifTalk;

  /// No description provided for @settingsTripNotify.
  ///
  /// In he, this message translates to:
  /// **'להודיע לחברים עם חיבור מהיר כשיוצאים לדרך'**
  String get settingsTripNotify;

  /// No description provided for @settingsTripNotifyBody.
  ///
  /// In he, this message translates to:
  /// **'רק לחברים ששניכם הדלקתם חיבור מהיר, פעם ביום לכל היותר, ולא בשעות השקטות שלהם.'**
  String get settingsTripNotifyBody;

  /// No description provided for @pushTestButton.
  ///
  /// In he, this message translates to:
  /// **'שליחת התראת בדיקה אליי'**
  String get pushTestButton;

  /// No description provided for @pushTestSent.
  ///
  /// In he, this message translates to:
  /// **'נשלחה התראת בדיקה. היא אמורה להופיע בעוד כמה שניות.'**
  String get pushTestSent;

  /// No description provided for @pushTestNoAppPush.
  ///
  /// In he, this message translates to:
  /// **'בגרסה הזו של האפליקציה עוד אין התראות (חסרות הגדרות Firebase ב-GitHub).'**
  String get pushTestNoAppPush;

  /// No description provided for @pushTestNoFunction.
  ///
  /// In he, this message translates to:
  /// **'פונקציית ההתראות (smooth-responder) לא נמצאה ב-Supabase.'**
  String get pushTestNoFunction;

  /// No description provided for @pushTestNotConfigured.
  ///
  /// In he, this message translates to:
  /// **'בפונקציה חסר הסוד FCM_SERVICE_ACCOUNT ב-Supabase.'**
  String get pushTestNotConfigured;

  /// No description provided for @pushTestNoServer.
  ///
  /// In he, this message translates to:
  /// **'השרת עוד לא עודכן לחלק 12 (גרסה 44).'**
  String get pushTestNoServer;

  /// No description provided for @pushTestNotAllowed.
  ///
  /// In he, this message translates to:
  /// **'הפונקציה דורשת אימות: צריך לכבות בה את Enforce JWT Verification.'**
  String get pushTestNotAllowed;

  /// No description provided for @pushTestFailed.
  ///
  /// In he, this message translates to:
  /// **'השליחה לא הצליחה ({code}).'**
  String pushTestFailed(String code);

  /// No description provided for @pushTestTitle.
  ///
  /// In he, this message translates to:
  /// **'בדיקה: ההתראות עובדות ✓'**
  String get pushTestTitle;

  /// No description provided for @pushTestNoToken.
  ///
  /// In he, this message translates to:
  /// **'הכתובת של הטלפון הזה לא נמצאה בשרת (no_token).'**
  String get pushTestNoToken;

  /// No description provided for @notifChannelNews.
  ///
  /// In he, this message translates to:
  /// **'עדכונים מ-DriveBond'**
  String get notifChannelNews;

  /// No description provided for @ownerNotifFeedback.
  ///
  /// In he, this message translates to:
  /// **'התקבל משוב חדש'**
  String get ownerNotifFeedback;

  /// No description provided for @ownerNotifCrash.
  ///
  /// In he, this message translates to:
  /// **'האפליקציה קרסה אצל מישהו'**
  String get ownerNotifCrash;

  /// No description provided for @ownerNotifUser.
  ///
  /// In he, this message translates to:
  /// **'משתמש חדש: {name}'**
  String ownerNotifUser(String name);

  /// No description provided for @versionNotifTitle.
  ///
  /// In he, this message translates to:
  /// **'יש גרסה חדשה של DriveBond'**
  String get versionNotifTitle;

  /// No description provided for @versionNotifBody.
  ///
  /// In he, this message translates to:
  /// **'לחיצה לעדכון ב-Google Play'**
  String get versionNotifBody;

  /// No description provided for @friendsSeeMeFree.
  ///
  /// In he, this message translates to:
  /// **'חברים רואים: פנוי · {mode} · {left}'**
  String friendsSeeMeFree(String mode, String left);

  /// No description provided for @friendsSeeMeInCall.
  ///
  /// In he, this message translates to:
  /// **'חברים רואים: בשיחה. בינתיים לא יגיעו שאלות.'**
  String get friendsSeeMeInCall;

  /// No description provided for @friendsSeeMeHidden.
  ///
  /// In he, this message translates to:
  /// **'בשיחה: חברים לא רואים שיש לך זמן (מוסתר בשיחה).'**
  String get friendsSeeMeHidden;

  /// Push: a friend said yes to talking, the question closed before I answered (D-121)
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} ניסתה להשיג אותך} male{{name} ניסה להשיג אותך} other{פספסת שיחה עם {name}}}'**
  String missedNotifTitle(String name, String gender);

  /// No description provided for @missedNotifBody.
  ///
  /// In he, this message translates to:
  /// **'השאלה נסגרה לפני שענית. אפשר להתקשר כשנוח.'**
  String get missedNotifBody;

  /// No description provided for @quietPickDays.
  ///
  /// In he, this message translates to:
  /// **'באילו ימים?'**
  String get quietPickDays;

  /// No description provided for @quietDaysSave.
  ///
  /// In he, this message translates to:
  /// **'שמירה'**
  String get quietDaysSave;

  /// Short day names Sunday..Saturday, comma separated
  ///
  /// In he, this message translates to:
  /// **'א,ב,ג,ד,ה,ו,ש'**
  String get quietDayLetters;

  /// No description provided for @settingsQuietOnDays.
  ///
  /// In he, this message translates to:
  /// **'בימים {days}, בין השעה {from} לשעה {to}, בנסיעה שמזוהה לבד לא נסמן אותך פנוי.'**
  String settingsQuietOnDays(String days, String from, String to);

  /// No description provided for @aboutTitle.
  ///
  /// In he, this message translates to:
  /// **'על DriveBond'**
  String get aboutTitle;

  /// No description provided for @aboutSettingsBody.
  ///
  /// In he, this message translates to:
  /// **'מה מיוחד באפליקציה, אילו הרשאות אישרת ולמה צריך אותם'**
  String get aboutSettingsBody;

  /// No description provided for @aboutHero.
  ///
  /// In he, this message translates to:
  /// **'הזמן המת של היום, בנסיעה, בפקק או בהליכה, הופך לשיחה טובה עם מישהו שחשוב לך.'**
  String get aboutHero;

  /// No description provided for @aboutSpecialTitle.
  ///
  /// In he, this message translates to:
  /// **'מה מיוחד כאן'**
  String get aboutSpecialTitle;

  /// No description provided for @aboutSpecial1Title.
  ///
  /// In he, this message translates to:
  /// **'רגע מת הופך לשיחה'**
  String get aboutSpecial1Title;

  /// No description provided for @aboutSpecial1Body.
  ///
  /// In he, this message translates to:
  /// **'כשיש לכם זמן באותו רגע, האפליקציה מחברת ביניכם. בלי לתאם מראש ובלי \"נדבר מתישהו\".'**
  String get aboutSpecial1Body;

  /// No description provided for @aboutSpecial2Title.
  ///
  /// In he, this message translates to:
  /// **'שיחה רק כששניכם רוצים'**
  String get aboutSpecial2Title;

  /// No description provided for @aboutSpecial2Body.
  ///
  /// In he, this message translates to:
  /// **'אף שיחה לא מתחילה בלי \"כן\" משני הצדדים. גם כשמזוהה נסיעה, זה רק אומר שיש זמן, לא שמישהו יתקשר.'**
  String get aboutSpecial2Body;

  /// No description provided for @aboutSpecial3Title.
  ///
  /// In he, this message translates to:
  /// **'בנהיגה: בקול ובכפתורים גדולים'**
  String get aboutSpecial3Title;

  /// No description provided for @aboutSpecial3Body.
  ///
  /// In he, this message translates to:
  /// **'הטלפון מקריא מי פנוי, ועונים \"כן\" או \"לא\" בקול. בלי הקלדה ובלי רשימות לגלול.'**
  String get aboutSpecial3Body;

  /// No description provided for @aboutSpecial4Title.
  ///
  /// In he, this message translates to:
  /// **'אתם שולטים'**
  String get aboutSpecial4Title;

  /// No description provided for @aboutSpecial4Body.
  ///
  /// In he, this message translates to:
  /// **'מי רואה שיש לכם זמן, שעות וימים שקטים, הסתרה בזמן שיחה, וחסימה. הכול בהגדרות.'**
  String get aboutSpecial4Body;

  /// No description provided for @aboutSpecial5Title.
  ///
  /// In he, this message translates to:
  /// **'בלי פיד ובלי זרים'**
  String get aboutSpecial5Title;

  /// No description provided for @aboutSpecial5Body.
  ///
  /// In he, this message translates to:
  /// **'אין גלילה אינסופית ואין צ\'אט אקראי. רק שיחות עם אנשים שבחרתם.'**
  String get aboutSpecial5Body;

  /// No description provided for @aboutPermsTitle.
  ///
  /// In he, this message translates to:
  /// **'ההרשאות בטלפון'**
  String get aboutPermsTitle;

  /// No description provided for @aboutPermsIntro.
  ///
  /// In he, this message translates to:
  /// **'מה אישרת ולמה צריך את זה. כל הרשאה משמשת רק למה שכתוב כאן.'**
  String get aboutPermsIntro;

  /// No description provided for @aboutPermOn.
  ///
  /// In he, this message translates to:
  /// **'מאושר'**
  String get aboutPermOn;

  /// No description provided for @aboutPermOff.
  ///
  /// In he, this message translates to:
  /// **'לא אושר'**
  String get aboutPermOff;

  /// No description provided for @aboutPermOptional.
  ///
  /// In he, this message translates to:
  /// **'רשות'**
  String get aboutPermOptional;

  /// No description provided for @aboutPermInUse.
  ///
  /// In he, this message translates to:
  /// **'בשימוש'**
  String get aboutPermInUse;

  /// No description provided for @aboutPermNotifBody.
  ///
  /// In he, this message translates to:
  /// **'כדי שתדעו כשחבר פנוי, כשמישהו שואל אם יש לכם זמן, או כשמישהו ניסה להשיג אתכם, גם כשהאפליקציה סגורה.'**
  String get aboutPermNotifBody;

  /// No description provided for @aboutPermCallBody.
  ///
  /// In he, this message translates to:
  /// **'כששניכם אומרים \"כן\", השיחה יוצאת מיד דרך החייגן הרגיל של הטלפון, בלי עוד לחיצה. האפליקציה לא קוראת את יומן השיחות.'**
  String get aboutPermCallBody;

  /// No description provided for @aboutPermMicBody.
  ///
  /// In he, this message translates to:
  /// **'רק כשהאפליקציה שואלת ומחכה ל\"כן\" או \"לא\" בנהיגה. כשהטלפון מחובר לדיבורית של הרכב, משתמשים במיקרופון של הרכב (המוזיקה עלולה להיעצר לשנייה). ההקשבה נעשית בטלפון עצמו, ושום דבר לא מוקלט ולא נשמר.'**
  String get aboutPermMicBody;

  /// No description provided for @aboutPermBgBody.
  ///
  /// In he, this message translates to:
  /// **'חיסכון הסוללה של הטלפון עלול לעצור את האפליקציה באמצע נסיעה. הפטור מאפשר לה להמשיך לעבוד ולהודיע לכם בזמן.\nהאפליקציה עובדת ברקע רק בזמן נסיעה, או כשסימנתם שיש לכם זמן, ולא כל היום. בשאר הזמן היא כבויה, ואנדרואיד מעיר אותה רק כשהטלפון ברכב.\nצריכת הסוללה קטנה מאוד: בלי GPS, ורק בדיקה קצרה מול השרת, בדרך כלל פעם בחצי דקה.'**
  String get aboutPermBgBody;

  /// No description provided for @aboutPermContactsTitle.
  ///
  /// In he, this message translates to:
  /// **'אנשי קשר'**
  String get aboutPermContactsTitle;

  /// No description provided for @aboutPermContactsBody.
  ///
  /// In he, this message translates to:
  /// **'כדי למצוא חברים שכבר משתמשים ב-DriveBond. נקראים רק מספרי הטלפון, והם עוברים הצפנה חד-כיוונית בטלפון עצמו. השמות לא יוצאים מהטלפון, ואף אחד לא מתחבר אליכם בלי שתבחרו.'**
  String get aboutPermContactsBody;

  /// No description provided for @aboutPermActivityTitle.
  ///
  /// In he, this message translates to:
  /// **'פעילות גופנית (זיהוי נסיעה)'**
  String get aboutPermActivityTitle;

  /// No description provided for @aboutPermActivityBody.
  ///
  /// In he, this message translates to:
  /// **'רק אם הדלקתם \"זמינות אוטומטית בנסיעה\". אנדרואיד אומר לאפליקציה \"הטלפון כנראה ברכב\", בלי GPS ובלי מיקום. זה כבוי עד שמדליקים.'**
  String get aboutPermActivityBody;

  /// No description provided for @aboutPermBtTitle.
  ///
  /// In he, this message translates to:
  /// **'בלוטות\' (הרכב)'**
  String get aboutPermBtTitle;

  /// No description provided for @aboutPermBtBody.
  ///
  /// In he, this message translates to:
  /// **'רשות: אם בחרתם את הרכב, האפליקציה שמה לב כשהטלפון מתחבר אליו, וכך מזהה נסיעה מהר יותר. המידע נשאר בטלפון.'**
  String get aboutPermBtBody;

  /// No description provided for @aboutPrivacyTitle.
  ///
  /// In he, this message translates to:
  /// **'מה אנחנו אף פעם לא עושים'**
  String get aboutPrivacyTitle;

  /// No description provided for @aboutNever1.
  ///
  /// In he, this message translates to:
  /// **'לא מקליטים שיחות, לא מתמללים, ואין שום בינה מלאכותית על מה שנאמר.'**
  String get aboutNever1;

  /// No description provided for @aboutNever2.
  ///
  /// In he, this message translates to:
  /// **'לא קוראים את יומן השיחות.'**
  String get aboutNever2;

  /// No description provided for @aboutNever3.
  ///
  /// In he, this message translates to:
  /// **'לא משתמשים ב-GPS. מיקום, מסלול ומהירות לא נשלחים לאף אחד.'**
  String get aboutNever3;

  /// No description provided for @aboutNever4.
  ///
  /// In he, this message translates to:
  /// **'חברים רואים רק אם יש לכם זמן, באיזה מצב (למשל בנסיעה), ועד מתי.'**
  String get aboutNever4;

  /// No description provided for @aboutNever5.
  ///
  /// In he, this message translates to:
  /// **'לא אומרים שאתם הנהגים, רק ש\"הטלפון כנראה ברכב\".'**
  String get aboutNever5;

  /// No description provided for @aboutFeedbackTitle.
  ///
  /// In he, this message translates to:
  /// **'עזרו לנו לשפר'**
  String get aboutFeedbackTitle;

  /// No description provided for @aboutFeedbackBody.
  ///
  /// In he, this message translates to:
  /// **'האפליקציה עדיין בבדיקה. כל הערה עוזרת: מה אהבתם, מה בלבל, ומה לא עבד.'**
  String get aboutFeedbackBody;

  /// Me, first in the row of free people on home
  ///
  /// In he, this message translates to:
  /// **'אני'**
  String get meInRow;

  /// No description provided for @quietEveryDay.
  ///
  /// In he, this message translates to:
  /// **'כל יום'**
  String get quietEveryDay;

  /// No description provided for @quietRangeLine.
  ///
  /// In he, this message translates to:
  /// **'{days}: {from}–{to}'**
  String quietRangeLine(String days, String from, String to);

  /// No description provided for @quietScreenBody.
  ///
  /// In he, this message translates to:
  /// **'בשעות האלה, בנסיעה שמזוהה לבד לא נסמן אותך פנוי. אפשר כמה לוחות זמנים, למשל ראשון–חמישי בלילה ושעות אחרות בשישי ושבת.'**
  String get quietScreenBody;

  /// No description provided for @quietAdd.
  ///
  /// In he, this message translates to:
  /// **'הוספת שעות שקטות'**
  String get quietAdd;

  /// No description provided for @quietNone.
  ///
  /// In he, this message translates to:
  /// **'עוד אין שעות שקטות.'**
  String get quietNone;

  /// No description provided for @quietDelete.
  ///
  /// In he, this message translates to:
  /// **'למחוק'**
  String get quietDelete;

  /// No description provided for @quietMany.
  ///
  /// In he, this message translates to:
  /// **'{count} לוחות זמנים: {lines}'**
  String quietMany(String count, String lines);

  /// No description provided for @waitingSent.
  ///
  /// In he, this message translates to:
  /// **'✓ נשלח ל{name}'**
  String waitingSent(String name);

  /// No description provided for @waitingReached.
  ///
  /// In he, this message translates to:
  /// **'✓✓ הגיע לטלפון של {name}'**
  String waitingReached(String name);

  /// No description provided for @permsFullTitle.
  ///
  /// In he, this message translates to:
  /// **'שאלה על כל המסך בנהיגה'**
  String get permsFullTitle;

  /// No description provided for @permsFullBody.
  ///
  /// In he, this message translates to:
  /// **'כדי לענות \"כן\" בקול גם כשהמסך נעול.'**
  String get permsFullBody;

  /// No description provided for @aboutPermFullBody.
  ///
  /// In he, this message translates to:
  /// **'בנהיגה, כשחבר שואל אם יש לך זמן, האפליקציה נפתחת כמו שיחה נכנסת, גם על מסך נעול, ושואלת בקול. ככה אפשר לענות \"כן\" או \"לא\" בלי לגעת בטלפון. כשהמסך בשימוש (למשל ניווט), מופיעה רק התראה למעלה.'**
  String get aboutPermFullBody;

  /// No description provided for @whyTitle.
  ///
  /// In he, this message translates to:
  /// **'למה מישהו לא מופיע?'**
  String get whyTitle;

  /// No description provided for @whyHint.
  ///
  /// In he, this message translates to:
  /// **'מספר הטלפון שלו'**
  String get whyHint;

  /// No description provided for @whyCheck.
  ///
  /// In he, this message translates to:
  /// **'לבדוק'**
  String get whyCheck;

  /// No description provided for @whyBadNumber.
  ///
  /// In he, this message translates to:
  /// **'זה לא נראה כמו מספר טלפון.'**
  String get whyBadNumber;

  /// No description provided for @whyNumber.
  ///
  /// In he, this message translates to:
  /// **'המספר בצורה אחידה: {number}'**
  String whyNumber(String number);

  /// No description provided for @whyNoContacts.
  ///
  /// In he, this message translates to:
  /// **'אין לאפליקציה גישה לאנשי הקשר, אז היא לא יכולה למצוא אותו משם.'**
  String get whyNoContacts;

  /// No description provided for @whyNotInContacts.
  ///
  /// In he, this message translates to:
  /// **'המספר הזה לא נמצא באנשי הקשר בטלפון הזה (אולי שמור אצלך מספר אחר שלו).'**
  String get whyNotInContacts;

  /// No description provided for @whyInContacts.
  ///
  /// In he, this message translates to:
  /// **'נמצא באנשי הקשר: {name}, שמור כ-{number}.'**
  String whyInContacts(String name, String number);

  /// No description provided for @whyMe.
  ///
  /// In he, this message translates to:
  /// **'זה המספר שלך.'**
  String get whyMe;

  /// No description provided for @whyNotUser.
  ///
  /// In he, this message translates to:
  /// **'אין ב-DriveBond משתמש עם המספר הזה (אולי נרשם בלי מספר, או עם מספר אחר).'**
  String get whyNotUser;

  /// No description provided for @whyUser.
  ///
  /// In he, this message translates to:
  /// **'הוא משתמש ב-DriveBond. בהוספת חבר ← אנשי קשר הוא אמור להופיע; אם לא, לחפש שוב.'**
  String get whyUser;

  /// No description provided for @whyFriend.
  ///
  /// In he, this message translates to:
  /// **'הוא כבר חבר שלך.'**
  String get whyFriend;

  /// No description provided for @whyRemoved.
  ///
  /// In he, this message translates to:
  /// **'אחד מכם הסיר את השני בעבר, ולכן הוא לא חוזר מאנשי הקשר. מי שהסיר יכול להחזיר: האנשים שלי ← אנשים שהסרתי ← להחזיר.'**
  String get whyRemoved;

  /// No description provided for @whyBlocked.
  ///
  /// In he, this message translates to:
  /// **'יש חסימה ביניכם, ולכן הוא לא מופיע.'**
  String get whyBlocked;

  /// No description provided for @whyRateLimited.
  ///
  /// In he, this message translates to:
  /// **'היום כבר חיפשו הרבה. אפשר לנסות שוב מחר.'**
  String get whyRateLimited;

  /// No description provided for @whyOldServer.
  ///
  /// In he, this message translates to:
  /// **'השרת עוד לא עודכן לבדיקה הזו (חלק 21).'**
  String get whyOldServer;

  /// No description provided for @widgetTitle.
  ///
  /// In he, this message translates to:
  /// **'פנויים עכשיו'**
  String get widgetTitle;

  /// No description provided for @widgetEmpty.
  ///
  /// In he, this message translates to:
  /// **'אף אחד לא פנוי כרגע'**
  String get widgetEmpty;

  /// No description provided for @widgetLeft.
  ///
  /// In he, this message translates to:
  /// **'עוד {m} דק׳'**
  String widgetLeft(String m);

  /// No description provided for @voiceHeardYes.
  ///
  /// In he, this message translates to:
  /// **'קיבלתי, מחברים.'**
  String get voiceHeardYes;

  /// No description provided for @voiceHeardNo.
  ///
  /// In he, this message translates to:
  /// **'בסדר.'**
  String get voiceHeardNo;

  /// No description provided for @voiceNotHeard.
  ///
  /// In he, this message translates to:
  /// **'לא שמעתי. אפשר ללחוץ.'**
  String get voiceNotHeard;

  /// No description provided for @healthMissing.
  ///
  /// In he, this message translates to:
  /// **'חסר אישור בטלפון: {what}. בלעדיו DriveBond לא עובדת כמו שצריך.'**
  String healthMissing(String what);

  /// No description provided for @healthFix.
  ///
  /// In he, this message translates to:
  /// **'לתקן'**
  String get healthFix;

  /// No description provided for @whatsNewTitle.
  ///
  /// In he, this message translates to:
  /// **'מה חדש בעדכון'**
  String get whatsNewTitle;

  /// No description provided for @whatsNewBody.
  ///
  /// In he, this message translates to:
  /// **'• \"כן\" בקול: צפצוף כשמקשיבים, יותר זמן לענות, ואישור בקול\n• אחרי שיחה אפשר לפנות שוב מיד\n• ווידג\'ט למסך הבית: מי פנוי עכשיו'**
  String get whatsNewBody;

  /// No description provided for @problemTitle.
  ///
  /// In he, this message translates to:
  /// **'דיווח על בעיה'**
  String get problemTitle;

  /// No description provided for @problemBody.
  ///
  /// In he, this message translates to:
  /// **'משהו לא עבד? כתבו מה קרה, ונקבל גם את הפרטים הטכניים.'**
  String get problemBody;

  /// No description provided for @problemHint.
  ///
  /// In he, this message translates to:
  /// **'מה קרה? בערך מתי?'**
  String get problemHint;

  /// No description provided for @problemDetails.
  ///
  /// In he, this message translates to:
  /// **'יחד עם ההודעה יישלחו פרטים טכניים מהטלפון (גרסה, מצב, יומן). בלי שמות של חברים, בלי מספרים ובלי שום דבר מהקול.'**
  String get problemDetails;

  /// No description provided for @ownerLookupTitle.
  ///
  /// In he, this message translates to:
  /// **'מצב של משתמש בשרת'**
  String get ownerLookupTitle;

  /// No description provided for @ownerLookupHint.
  ///
  /// In he, this message translates to:
  /// **'שם או מספר טלפון'**
  String get ownerLookupHint;

  /// No description provided for @ownerLookupNone.
  ///
  /// In he, this message translates to:
  /// **'לא נמצא אף אחד.'**
  String get ownerLookupNone;

  /// No description provided for @ownerDetails.
  ///
  /// In he, this message translates to:
  /// **'פרטים טכניים'**
  String get ownerDetails;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
