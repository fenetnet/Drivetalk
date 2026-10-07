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
  /// **'{gender, select, female{יש לי זמן עכשיו} male{יש לי זמן עכשיו} other{יש לי זמן עכשיו}}'**
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

  /// No description provided for @pickModeTitle.
  ///
  /// In he, this message translates to:
  /// **'מה המצב?'**
  String get pickModeTitle;

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
  /// **'עד שאסיים את הנסיעה'**
  String get durationUntilTripEnds;

  /// No description provided for @durationTripNote.
  ///
  /// In he, this message translates to:
  /// **'מסתיים ביציאה מהרכב, ולכל היותר אחרי {hours} שעות.'**
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
  /// **'הסרה מהקשרים'**
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

  /// No description provided for @callAudioOnly.
  ///
  /// In he, this message translates to:
  /// **'שיחת קול בלבד · לא מוקלטת'**
  String get callAudioOnly;

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
  /// **'דלג'**
  String get skip;

  /// No description provided for @driverSearching.
  ///
  /// In he, this message translates to:
  /// **'מחפשים...'**
  String get driverSearching;

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
  /// **'להסיר את {name} מהקשרים? אפשר יהיה להתחבר שוב רק בהזמנה חדשה.'**
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

  /// No description provided for @availableToEveryone.
  ///
  /// In he, this message translates to:
  /// **'כולם'**
  String get availableToEveryone;

  /// No description provided for @driverListening.
  ///
  /// In he, this message translates to:
  /// **'מקשיב… אפשר לומר \"כן\" או \"לא\"'**
  String get driverListening;

  /// No description provided for @callWeAreDone.
  ///
  /// In he, this message translates to:
  /// **'סיימנו'**
  String get callWeAreDone;

  /// No description provided for @noticeMicDenied.
  ///
  /// In he, this message translates to:
  /// **'אין הרשאת מיקרופון, אז אי אפשר לענות בקול. אפשר לאשר בהגדרות הטלפון ‹ אפליקציות ‹ DriveTalk ‹ הרשאות. הכפתורים תמיד עובדים.'**
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
  /// **'בנסיעה, הטלפון אומר בקול מי פנוי, ואפשר לענות \"כן\" או \"לא\" בלי לגעת במסך.'**
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
  /// **'הבדיקה עם חבר עוד לא מחוברת'**
  String get realNotConfiguredTitle;

  /// No description provided for @realNotConfiguredBody.
  ///
  /// In he, this message translates to:
  /// **'בגרסה הזו השרת עוד לא הוגדר. בינתיים אפשר להמשיך בהדגמה.'**
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
  /// **'חברים ששמרו את המספר שלך יתחברו אליך לבד, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל אותו רק כששניכם אמרתם \"כן\".'**
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

  /// No description provided for @realWaitingForFriends.
  ///
  /// In he, this message translates to:
  /// **'כשחבר יהיה פנוי — נשאל את שניכם.'**
  String get realWaitingForFriends;

  /// No description provided for @realFreeFriendsTitle.
  ///
  /// In he, this message translates to:
  /// **'עכשיו'**
  String get realFreeFriendsTitle;

  /// No description provided for @realNobodyFree.
  ///
  /// In he, this message translates to:
  /// **'יש לך 20 דקות? לוחצים \"יש לי זמן\" ונחפש עם מי לדבר.'**
  String get realNobodyFree;

  /// No description provided for @realNobodyFreeYet.
  ///
  /// In he, this message translates to:
  /// **'נעדכן ברגע שמישהו מתאים יתפנה.'**
  String get realNobodyFreeYet;

  /// No description provided for @homeIntentsTitle.
  ///
  /// In he, this message translates to:
  /// **'אשמח לדבר'**
  String get homeIntentsTitle;

  /// No description provided for @homeIntentsBody.
  ///
  /// In he, this message translates to:
  /// **'כשתהיו פנויים יחד — נציע אותם קודם.'**
  String get homeIntentsBody;

  /// No description provided for @realNoFriendsTitle.
  ///
  /// In he, this message translates to:
  /// **'עוד אין פה חברים'**
  String get realNoFriendsTitle;

  /// No description provided for @realNoFriendsBody.
  ///
  /// In he, this message translates to:
  /// **'הזמינו חבר — וכששניכם פנויים, נציע לכם לדבר.'**
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
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveTalk. כששנינו פנויים היא פשוט מציעה לנו לדבר.'**
  String get realInviteMessage;

  /// No description provided for @realInviteMessageNoSite.
  ///
  /// In he, this message translates to:
  /// **'להורדה: {apkUrl}\nואז באפליקציה: האנשים שלי ← יש לי קוד הזמנה ← {code}'**
  String realInviteMessageNoSite(String apkUrl, String code);

  /// No description provided for @realInviteShareSubject.
  ///
  /// In he, this message translates to:
  /// **'הזמנה ל-DriveTalk'**
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
  /// **'מה נשמר ומה לא. אפשר גם למחוק את אנשי הקשר.'**
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

  /// No description provided for @realQuickCancelled.
  ///
  /// In he, this message translates to:
  /// **'החיבור בוטל'**
  String get realQuickCancelled;

  /// No description provided for @widgetTip.
  ///
  /// In he, this message translates to:
  /// **'אפשר לסמן \"יש לי זמן\" בלחיצה אחת, בלי לפתוח את האפליקציה: לחיצה ארוכה על מסך הבית ← ווידג\'טים ← DriveTalk.'**
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

  /// No description provided for @adminEnter.
  ///
  /// In he, this message translates to:
  /// **'ניהול'**
  String get adminEnter;

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
  /// **'יש גרסה חדשה של DriveTalk'**
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

  /// No description provided for @realBgFailedTitle.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו להדליק זמינות ברקע'**
  String get realBgFailedTitle;

  /// No description provided for @realBgFailedBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון חסם את זה. פותחים את DriveTalk ולוחצים \"יש לי זמן\".'**
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

  /// No description provided for @realVoiceOfferAnon.
  ///
  /// In he, this message translates to:
  /// **'חבר פנוי עכשיו. לדבר?'**
  String get realVoiceOfferAnon;

  /// No description provided for @realVoiceQuickAnon.
  ///
  /// In he, this message translates to:
  /// **'מתחברים לחבר. אפשר לבטל בכפתור.'**
  String get realVoiceQuickAnon;

  /// No description provided for @realVoiceCallingAnon.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים.'**
  String get realVoiceCallingAnon;

  /// No description provided for @realVoiceTheyCallAnon.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים אליך עכשיו.'**
  String get realVoiceTheyCallAnon;

  /// No description provided for @settingsSpeakNames.
  ///
  /// In he, this message translates to:
  /// **'להקריא שמות'**
  String get settingsSpeakNames;

  /// No description provided for @settingsSpeakNamesBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון אומר בקול את שם החבר. כבוי: רק \"חבר פנוי\", בלי שם (טוב כשיש עוד אנשים ברכב).'**
  String get settingsSpeakNamesBody;

  /// No description provided for @realDeleteAccount.
  ///
  /// In he, this message translates to:
  /// **'למחוק את החשבון והמידע שלי'**
  String get realDeleteAccount;

  /// No description provided for @realDeleteAccountConfirm.
  ///
  /// In he, this message translates to:
  /// **'הכול נמחק מהשרת: שם, מספר, חברים, מעגלים ותמונה. אי אפשר לבטל.'**
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
  /// **'יש הצעה חדשה ב-DriveTalk'**
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
  /// **'כדי לנסות את DriveTalk צריך לפחות חבר אחד'**
  String get firstRunNoneTitle;

  /// No description provided for @firstRunNoneBody.
  ///
  /// In he, this message translates to:
  /// **'שולחים קישור למישהו שאוהבים לדבר איתו. אחרי ההתקנה — מתחברים לבד.'**
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
  /// **'כששניכם פנויים, DriveTalk מציעה לכם לדבר. לא צריך לתאם מראש.'**
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

  /// No description provided for @outcomeQuestion.
  ///
  /// In he, this message translates to:
  /// **'איך היה?'**
  String get outcomeQuestion;

  /// No description provided for @outcomeGood.
  ///
  /// In he, this message translates to:
  /// **'היה טוב'**
  String get outcomeGood;

  /// No description provided for @outcomeNotSoon.
  ///
  /// In he, this message translates to:
  /// **'לא להציע בקרוב'**
  String get outcomeNotSoon;

  /// No description provided for @outcomeNoTalk.
  ///
  /// In he, this message translates to:
  /// **'לא דיברנו בפועל'**
  String get outcomeNoTalk;

  /// No description provided for @intentTitle.
  ///
  /// In he, this message translates to:
  /// **'אשמח לדבר'**
  String get intentTitle;

  /// No description provided for @intentExplain.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} לא תקבל שום הודעה. כששניכם תהיו פנויים — היא תוצע לך קודם.} male{{name} לא יקבל שום הודעה. כששניכם תהיו פנויים — הוא יוצע לך קודם.} other{שום הודעה לא נשלחת ל{name}. כששניכם תהיו פנויים — נציע את {name} קודם.}}'**
  String intentExplain(String name, String gender);

  /// No description provided for @intentToday.
  ///
  /// In he, this message translates to:
  /// **'היום'**
  String get intentToday;

  /// No description provided for @intentWeek.
  ///
  /// In he, this message translates to:
  /// **'השבוע'**
  String get intentWeek;

  /// No description provided for @intentAlways.
  ///
  /// In he, this message translates to:
  /// **'עד שאבטל'**
  String get intentAlways;

  /// No description provided for @intentRemove.
  ///
  /// In he, this message translates to:
  /// **'להסיר'**
  String get intentRemove;

  /// No description provided for @intentBadgeToday.
  ///
  /// In he, this message translates to:
  /// **'אשמח לדבר · היום'**
  String get intentBadgeToday;

  /// No description provided for @intentBadgeWeek.
  ///
  /// In he, this message translates to:
  /// **'אשמח לדבר · השבוע'**
  String get intentBadgeWeek;

  /// No description provided for @intentBadgeAlways.
  ///
  /// In he, this message translates to:
  /// **'אשמח לדבר'**
  String get intentBadgeAlways;

  /// No description provided for @realCallingNow.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name}…'**
  String realCallingNow(String name);

  /// No description provided for @realDialedBody.
  ///
  /// In he, this message translates to:
  /// **'כשתסיימו — חזרו לכאן.'**
  String get realDialedBody;

  /// No description provided for @realTheyCallTitle.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{{name} מתקשרת אליך עכשיו} male{{name} מתקשר אליך עכשיו} other{שיחה מ{name} מגיעה עכשיו}}'**
  String realTheyCallTitle(String name, String gender);

  /// No description provided for @realTheyCallBody.
  ///
  /// In he, this message translates to:
  /// **'אם השיחה לא מגיעה תוך דקה — לחצו למטה.'**
  String get realTheyCallBody;

  /// No description provided for @realTheyDidNotCall.
  ///
  /// In he, this message translates to:
  /// **'לא הגיעה שיחה'**
  String get realTheyDidNotCall;

  /// No description provided for @realInAppTitle.
  ///
  /// In he, this message translates to:
  /// **'מדברים עם {name}'**
  String realInAppTitle(String name);

  /// No description provided for @realInAppBody.
  ///
  /// In he, this message translates to:
  /// **'לא שותפו מספרים, לכן זו שיחה מדומה.'**
  String get realInAppBody;

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
  /// **'ההזמנה הזו כבר נוצלה. בקשו הזמנה חדשה.'**
  String get realInviteProblemUsed;

  /// No description provided for @realInviteProblemExpired.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף ההזמנה. בקשו הזמנה חדשה.'**
  String get realInviteProblemExpired;

  /// No description provided for @realInviteProblemOwn.
  ///
  /// In he, this message translates to:
  /// **'זו הזמנה ששלחת בעצמך 🙂 שלחו אותה לחבר.'**
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
  /// **'משהו השתבש ({code}). נסו שוב.'**
  String realErrorGeneric(String code);

  /// No description provided for @realErrorAnonymousDisabled.
  ///
  /// In he, this message translates to:
  /// **'בשרת עוד לא הופעלה כניסה בלי סיסמה (Anonymous sign-ins).'**
  String get realErrorAnonymousDisabled;

  /// No description provided for @realErrorSchema.
  ///
  /// In he, this message translates to:
  /// **'השרת עוד לא הוכן (צריך להריץ את קובץ ההגדרה).'**
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
  /// **'יותר מדי ניסיונות. נסו שוב בעוד כמה דקות.'**
  String get realErrorRateLimited;

  /// No description provided for @realErrorTooManyInvites.
  ///
  /// In he, this message translates to:
  /// **'יש כבר הרבה הזמנות פתוחות. נסו שוב מחר.'**
  String get realErrorTooManyInvites;

  /// No description provided for @realSaved.
  ///
  /// In he, this message translates to:
  /// **'נשמר'**
  String get realSaved;

  /// No description provided for @realDialFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו לפתוח את החייגן — עוברים לשיחה מדומה'**
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
  /// **'כאן רואים שהכל עובד. אם משהו לא עובד — \"להעתיק מידע לבדיקה\" ושולחים לי.'**
  String get realTestIntro;

  /// No description provided for @realTestSteps.
  ///
  /// In he, this message translates to:
  /// **'1. להזמין חבר\n2. שניכם: \"יש לי זמן\"\n3. שניכם: \"לדבר עכשיו\"'**
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
  /// **'לא משותף'**
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
  /// **'בלי מיקום ובלי הקלטות. השרת יודע רק את השם שלך, מי החברים שלך, ואם יש לך זמן עכשיו.'**
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
  /// **'DriveTalk · זמינות לשיחה בנסיעה'**
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
  /// **'הטלפון מזהה נסיעה לבד (בלי GPS) ומסמן שיש לך זמן עד סוף הנסיעה.\n\nשיחה מתחילה רק אם שניכם אומרים כן.\n\nיתבקשו הרשאות \"פעילות גופנית\" והתראות.'**
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
  /// **'צריך הרשאת \"פעילות גופנית\": הגדרות הטלפון ‹ אפליקציות ‹ DriveTalk ‹ הרשאות.'**
  String get realAutoDrivingNoPermission;

  /// No description provided for @realAutoDrivingFailed.
  ///
  /// In he, this message translates to:
  /// **'לא הצלחנו להפעיל זיהוי נסיעה. נסו שוב.'**
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
  /// **'מעגלים'**
  String get realCirclesTitle;

  /// No description provided for @realCirclesIntro.
  ///
  /// In he, this message translates to:
  /// **'קבוצות פרטיות. אפשר לסמן זמן פנוי רק לקבוצה.'**
  String get realCirclesIntro;

  /// No description provided for @realCircleNew.
  ///
  /// In he, this message translates to:
  /// **'מעגל חדש'**
  String get realCircleNew;

  /// No description provided for @realCircleName.
  ///
  /// In he, this message translates to:
  /// **'שם המעגל (למשל: משפחה)'**
  String get realCircleName;

  /// No description provided for @realCircleQuick.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר'**
  String get realCircleQuick;

  /// No description provided for @realCircleQuickBody.
  ///
  /// In he, this message translates to:
  /// **'אם גם הם שמו אותך בחיבור מהיר — מתחברים מיד, עם 5 שניות לביטול.'**
  String get realCircleQuickBody;

  /// No description provided for @realCircleMembers.
  ///
  /// In he, this message translates to:
  /// **'מי במעגל'**
  String get realCircleMembers;

  /// No description provided for @realCircleCount.
  ///
  /// In he, this message translates to:
  /// **'{count} אנשים'**
  String realCircleCount(int count);

  /// No description provided for @realCircleDelete.
  ///
  /// In he, this message translates to:
  /// **'מחיקת המעגל'**
  String get realCircleDelete;

  /// No description provided for @realCircleNoFriends.
  ///
  /// In he, this message translates to:
  /// **'קודם צריך להזמין חברים'**
  String get realCircleNoFriends;

  /// No description provided for @realPhoneRequired.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון (לא חובה)'**
  String get realPhoneRequired;

  /// No description provided for @realPhoneRequiredHelp.
  ///
  /// In he, this message translates to:
  /// **'למה כדאי: חברים ששמרו את המספר שלך יתחברו אליך לבד, והשיחה תהיה שיחת טלפון רגילה. החבר מקבל אותו רק כששניכם אמרתם \"כן\". אפשר גם להוסיף אחר כך.'**
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
  /// **'DriveTalk · זמינות לשיחה'**
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
  /// **'{count} פנויים'**
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
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveTalk — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה: {apkUrl}\nעזרה בהתקנה: {guideUrl}'**
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
  /// **'DriveTalk · השגרה שלך'**
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

  /// No description provided for @hideStatusTitle.
  ///
  /// In he, this message translates to:
  /// **'להסתיר מתי יש לי זמן'**
  String get hideStatusTitle;

  /// No description provided for @hideStatusBody.
  ///
  /// In he, this message translates to:
  /// **'החברים לא יראו מתי יש לך זמן, וגם לך לא יוצג מי פנוי. הצעות לדבר ממשיכות כרגיל.'**
  String get hideStatusBody;

  /// No description provided for @hiddenNote.
  ///
  /// In he, this message translates to:
  /// **'המצב שלך מוסתר, ולכן גם לא רואים כאן מי פנוי. הצעות לדבר ממשיכות.'**
  String get hiddenNote;

  /// No description provided for @realLaterButton.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו — אחזור אליך'**
  String get realLaterButton;

  /// No description provided for @realLaterNote.
  ///
  /// In he, this message translates to:
  /// **'מ{name}: עכשיו לא מתאים, אחזור אליך.'**
  String realLaterNote(String name);

  /// No description provided for @backgroundTitle.
  ///
  /// In he, this message translates to:
  /// **'שההצעות יגיעו גם כשהאפליקציה סגורה'**
  String get backgroundTitle;

  /// No description provided for @backgroundBody.
  ///
  /// In he, this message translates to:
  /// **'חיסכון הסוללה של הטלפון עלול לעצור את DriveTalk ברקע, ואז זיהוי הנסיעה וההתראות לא עובדים. לחיצה אחת מתקנת.'**
  String get backgroundBody;

  /// No description provided for @backgroundAllow.
  ///
  /// In he, this message translates to:
  /// **'לאפשר פעולה ברקע'**
  String get backgroundAllow;

  /// No description provided for @notNowShort.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get notNowShort;

  /// No description provided for @firstRunRoutineTitle.
  ///
  /// In he, this message translates to:
  /// **'מתי בדרך כלל יש לך זמן בדרך?'**
  String get firstRunRoutineTitle;

  /// No description provided for @firstRunRoutineBody.
  ///
  /// In he, this message translates to:
  /// **'בימים א׳–ה׳ בשעה שבחרת הזמינות תידלק לבד לחצי שעה. השעה ניתנת לשינוי בעיפרון. אפשר לשנות בכל רגע גם בהגדרות ← השגרה שלי.'**
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
  /// **'לא הצלחנו לטעון. אולי השרת צריך עדכון.'**
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
  /// **'משתמשים (סה״כ)'**
  String get statsUsers;

  /// No description provided for @statsNewUsers.
  ///
  /// In he, this message translates to:
  /// **'הצטרפו בתקופה'**
  String get statsNewUsers;

  /// No description provided for @statsActiveUsers.
  ///
  /// In he, this message translates to:
  /// **'פתחו את האפליקציה בתקופה'**
  String get statsActiveUsers;

  /// No description provided for @statsFriendships.
  ///
  /// In he, this message translates to:
  /// **'חיבורים בין אנשים (סה״כ)'**
  String get statsFriendships;

  /// No description provided for @statsFreeTimes.
  ///
  /// In he, this message translates to:
  /// **'פעמים שסימנו \"יש לי זמן\"'**
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
  /// **'דיברו בפועל (לפי המשוב)'**
  String get statsTalked;

  /// No description provided for @statsDeclined.
  ///
  /// In he, this message translates to:
  /// **'\"לא עכשיו\"'**
  String get statsDeclined;

  /// No description provided for @statsLater.
  ///
  /// In he, this message translates to:
  /// **'מתוכם \"אחזור אליך\"'**
  String get statsLater;

  /// No description provided for @statsNoAnswer.
  ///
  /// In he, this message translates to:
  /// **'בלי תשובה'**
  String get statsNoAnswer;

  /// No description provided for @statsDialMs.
  ///
  /// In he, this message translates to:
  /// **'זמן מ\"כן\" שני עד חיוג (חציון)'**
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

  /// No description provided for @notificationsTitle.
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get notificationsTitle;

  /// No description provided for @notificationsOnBody.
  ///
  /// In he, this message translates to:
  /// **'דלוקות: מקבלים הודעה כשלחבר יש זמן ואפשר לדבר. לחיצה לשינוי בהגדרות הטלפון.'**
  String get notificationsOnBody;

  /// No description provided for @notificationsOffBody.
  ///
  /// In he, this message translates to:
  /// **'כבויות: בלי התראות, הצעות לדבר מגיעות רק כשהאפליקציה פתוחה. לחיצה להדלקה.'**
  String get notificationsOffBody;

  /// No description provided for @statsReports.
  ///
  /// In he, this message translates to:
  /// **'דיווחים'**
  String get statsReports;

  /// No description provided for @realInviteStore.
  ///
  /// In he, this message translates to:
  /// **'בא לך שנדבר יותר בלי לקבוע מראש? התקנתי DriveTalk — כששנינו פנויים היא מציעה לנו לדבר.\nלהורדה מ-Google Play: {url}'**
  String realInviteStore(String url);

  /// No description provided for @inactiveTitle.
  ///
  /// In he, this message translates to:
  /// **'{name}: בלי כניסה ל-DriveTalk כבר שבוע'**
  String inactiveTitle(String name);

  /// No description provided for @inactiveBody.
  ///
  /// In he, this message translates to:
  /// **'אולי האפליקציה הוסרה. להסיר מהרשימה שלך?'**
  String get inactiveBody;

  /// No description provided for @inactiveRemove.
  ///
  /// In he, this message translates to:
  /// **'להסיר מהרשימה'**
  String get inactiveRemove;

  /// No description provided for @inactiveKeep.
  ///
  /// In he, this message translates to:
  /// **'להשאיר'**
  String get inactiveKeep;

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
  /// **'אין גישה. צריך שהשרת יתעדכן, ולהכניס שוב את קוד הניהול (הגדרות ← ניהול).'**
  String get statsNotesFailed;

  /// No description provided for @firstRunRoutineChangeTime.
  ///
  /// In he, this message translates to:
  /// **'לשנות שעה'**
  String get firstRunRoutineChangeTime;
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
