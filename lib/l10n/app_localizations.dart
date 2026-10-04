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

  /// No description provided for @appTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveTalk'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In he, this message translates to:
  /// **'בית'**
  String get tabHome;

  /// No description provided for @tabConnections.
  ///
  /// In he, this message translates to:
  /// **'קשרים'**
  String get tabConnections;

  /// No description provided for @tabDiscover.
  ///
  /// In he, this message translates to:
  /// **'גילוי'**
  String get tabDiscover;

  /// No description provided for @tabSettings.
  ///
  /// In he, this message translates to:
  /// **'הגדרות'**
  String get tabSettings;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In he, this message translates to:
  /// **'הזמן המת שלך יכול להפוך לשיחה טובה'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In he, this message translates to:
  /// **'בנסיעה, בהליכה או בהפסקה — נמצא את האדם הנכון לדבר איתו דווקא עכשיו.'**
  String get onbWelcomeBody;

  /// No description provided for @onbHowTitle.
  ///
  /// In he, this message translates to:
  /// **'איך זה עובד'**
  String get onbHowTitle;

  /// No description provided for @onbHow1.
  ///
  /// In he, this message translates to:
  /// **'מסמנים שפנויים, ולכמה זמן.'**
  String get onbHow1;

  /// No description provided for @onbHow2.
  ///
  /// In he, this message translates to:
  /// **'מקבלים כמה הצעות מתאימות — עם הסבר למה כל אחת.'**
  String get onbHow2;

  /// No description provided for @onbHow3.
  ///
  /// In he, this message translates to:
  /// **'שיחה מתחילה רק כשגם הצד השני מסכים, או עם מי ששניכם סימנתם מראש ל\"חיבור מהיר\".'**
  String get onbHow3;

  /// No description provided for @onbPrivacyTitle.
  ///
  /// In he, this message translates to:
  /// **'פרטיות ובטיחות'**
  String get onbPrivacyTitle;

  /// No description provided for @onbPrivacy1.
  ///
  /// In he, this message translates to:
  /// **'לא משתפים מיקום, מסלול או מהירות — עם אף אחד.'**
  String get onbPrivacy1;

  /// No description provided for @onbPrivacy2.
  ///
  /// In he, this message translates to:
  /// **'שיחות לא מוקלטות ולא מתומללות.'**
  String get onbPrivacy2;

  /// No description provided for @onbPrivacy3.
  ///
  /// In he, this message translates to:
  /// **'בנהיגה — רק דיבורית ומתקן לרכב. אפשר לענות \"כן\" או \"לא\" בקול.'**
  String get onbPrivacy3;

  /// No description provided for @onbSetupTitle.
  ///
  /// In he, this message translates to:
  /// **'כמה פרטים קטנים'**
  String get onbSetupTitle;

  /// No description provided for @onbNameLabel.
  ///
  /// In he, this message translates to:
  /// **'איך קוראים לך?'**
  String get onbNameLabel;

  /// No description provided for @onbGenderLabel.
  ///
  /// In he, this message translates to:
  /// **'איך לפנות אליך?'**
  String get onbGenderLabel;

  /// No description provided for @genderMale.
  ///
  /// In he, this message translates to:
  /// **'בלשון זכר'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In he, this message translates to:
  /// **'בלשון נקבה'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In he, this message translates to:
  /// **'ניטרלי'**
  String get genderOther;

  /// No description provided for @onbOpennessLabel.
  ///
  /// In he, this message translates to:
  /// **'מה מתאים לך שנציע?'**
  String get onbOpennessLabel;

  /// No description provided for @onbNext.
  ///
  /// In he, this message translates to:
  /// **'המשך'**
  String get onbNext;

  /// No description provided for @onbStart.
  ///
  /// In he, this message translates to:
  /// **'בואו נתחיל'**
  String get onbStart;

  /// No description provided for @onbPrototypeNote.
  ///
  /// In he, this message translates to:
  /// **'זהו אב-טיפוס: כל האנשים והשיחות מדומים.'**
  String get onbPrototypeNote;

  /// No description provided for @homeGreeting.
  ///
  /// In he, this message translates to:
  /// **'שלום {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingNoName.
  ///
  /// In he, this message translates to:
  /// **'שלום'**
  String get homeGreetingNoName;

  /// No description provided for @homeStatusUnavailable.
  ///
  /// In he, this message translates to:
  /// **'כרגע לא זמין לשיחות'**
  String get homeStatusUnavailable;

  /// No description provided for @homeImFreeNow.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{אני פנויה עכשיו} male{אני פנוי עכשיו} other{אני פנוי/ה עכשיו}}'**
  String homeImFreeNow(String gender);

  /// No description provided for @homeAvailableCount.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{כרגע אף אחד שמתאים לך לא פנוי — אפשר לסמן זמינות ונשלח הזמנה למעטים} =1{אדם אחד שמתאים לך פנוי עכשיו} other{{count} אנשים שמתאימים לך פנויים עכשיו}}'**
  String homeAvailableCount(int count);

  /// No description provided for @homeRestingTitle.
  ///
  /// In he, this message translates to:
  /// **'הזמינות שלך פעילה'**
  String get homeRestingTitle;

  /// No description provided for @timeLeftMinutes.
  ///
  /// In he, this message translates to:
  /// **'עוד {minutes} דק׳'**
  String timeLeftMinutes(int minutes);

  /// No description provided for @homeFindAnother.
  ///
  /// In he, this message translates to:
  /// **'מצא מישהו לדבר איתו'**
  String get homeFindAnother;

  /// No description provided for @stopAvailability.
  ///
  /// In he, this message translates to:
  /// **'עצור זמינות'**
  String get stopAvailability;

  /// No description provided for @homeAutoDrivingOn.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה פעילה'**
  String get homeAutoDrivingOn;

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
  /// **'סתם פנוי'**
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

  /// No description provided for @searchingTitle.
  ///
  /// In he, this message translates to:
  /// **'מחפשים מישהו שמתאים לדבר איתך עכשיו'**
  String get searchingTitle;

  /// No description provided for @searchingNoOneYet.
  ///
  /// In he, this message translates to:
  /// **'אם אף אחד לא פנוי, נשלח הודעה לכמה אנשים שעשויים להתאים.'**
  String get searchingNoOneYet;

  /// No description provided for @beaconSent.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{אף אחד לא פנוי בדיוק עכשיו. נמשיך לחפש כל עוד את/ה זמין/ה.} =1{אף אחד לא פנוי בדיוק עכשיו, אז שלחנו הודעה לאדם אחד שעשוי להתאים.} other{אף אחד לא פנוי בדיוק עכשיו, אז שלחנו הודעה ל-{count} אנשים שעשויים להתאים.}}'**
  String beaconSent(int count);

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

  /// No description provided for @explorationBadge.
  ///
  /// In he, this message translates to:
  /// **'הפתעה קטנה'**
  String get explorationBadge;

  /// No description provided for @talkNow.
  ///
  /// In he, this message translates to:
  /// **'לדבר עכשיו'**
  String get talkNow;

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

  /// No description provided for @reasonAvailable.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}} עכשיו לעוד כ-{minutes} דקות'**
  String reasonAvailable(String name, String gender, int minutes);

  /// No description provided for @reasonDormant.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם כאן {duration}'**
  String reasonDormant(String duration);

  /// No description provided for @reasonNeverTalked.
  ///
  /// In he, this message translates to:
  /// **'עוד לא דיברתם כאן אף פעם'**
  String get reasonNeverTalked;

  /// No description provided for @reasonMutualFriends.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{יש לכם חבר משותף} other{יש לכם {count} חברים משותפים}}'**
  String reasonMutualFriends(int count);

  /// No description provided for @reasonSharedGroup.
  ///
  /// In he, this message translates to:
  /// **'שניכם בקבוצה \"{group}\"'**
  String reasonSharedGroup(String group);

  /// No description provided for @reasonSharedInterests.
  ///
  /// In he, this message translates to:
  /// **'לשניכם יש עניין ב{interests}'**
  String reasonSharedInterests(String interests);

  /// No description provided for @reasonBothFof.
  ///
  /// In he, this message translates to:
  /// **'שניכם פתוחים להכיר חברים של חברים'**
  String get reasonBothFof;

  /// No description provided for @reasonEnjoyedLastTime.
  ///
  /// In he, this message translates to:
  /// **'בפעם הקודמת נהניתם מהשיחה'**
  String get reasonEnjoyedLastTime;

  /// No description provided for @reasonAnswered.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{אישרה} male{אישר} other{אישר/ה}} שמתאים לדבר עכשיו'**
  String reasonAnswered(String name, String gender);

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

  /// No description provided for @waitingTitle.
  ///
  /// In he, this message translates to:
  /// **'שאלנו את {name} אם מתאים לדבר עכשיו'**
  String waitingTitle(String name);

  /// No description provided for @waitingSubtitle.
  ///
  /// In he, this message translates to:
  /// **'השיחה תתחיל רק אחרי אישור'**
  String get waitingSubtitle;

  /// No description provided for @cancel.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get cancel;

  /// No description provided for @noticeDeclined.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{לא יכולה} male{לא יכול} other{לא יכול/ה}} עכשיו. אפשר להשאיר הודעה קולית.'**
  String noticeDeclined(String name, String gender);

  /// No description provided for @noticeAvailabilityEnded.
  ///
  /// In he, this message translates to:
  /// **'זמן הזמינות הסתיים'**
  String get noticeAvailabilityEnded;

  /// No description provided for @noticeInvitationMuted.
  ///
  /// In he, this message translates to:
  /// **'השתקנו הזמנות כאלה ל-{hours} שעות'**
  String noticeInvitationMuted(int hours);

  /// No description provided for @noticeBlocked.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{נחסמה} male{נחסם} other{נחסם/ה}}'**
  String noticeBlocked(String name, String gender);

  /// No description provided for @noticeReported.
  ///
  /// In he, this message translates to:
  /// **'תודה, הדיווח התקבל'**
  String get noticeReported;

  /// No description provided for @noticePausedToday.
  ///
  /// In he, this message translates to:
  /// **'לא נציע את {name} היום'**
  String noticePausedToday(String name);

  /// No description provided for @noticePausedWhile.
  ///
  /// In he, this message translates to:
  /// **'לא נציע את {name} בתקופה הקרובה'**
  String noticePausedWhile(String name);

  /// No description provided for @callSimulated.
  ///
  /// In he, this message translates to:
  /// **'סימולציה — אין שיחה אמיתית בשלב זה'**
  String get callSimulated;

  /// No description provided for @callMute.
  ///
  /// In he, this message translates to:
  /// **'השתק'**
  String get callMute;

  /// No description provided for @callUnmute.
  ///
  /// In he, this message translates to:
  /// **'בטל השתקה'**
  String get callUnmute;

  /// No description provided for @callEnd.
  ///
  /// In he, this message translates to:
  /// **'סיום'**
  String get callEnd;

  /// No description provided for @callAudioOnly.
  ///
  /// In he, this message translates to:
  /// **'שיחת קול בלבד · לא מוקלטת'**
  String get callAudioOnly;

  /// No description provided for @feedbackQuestion.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{שמחה} male{שמח} other{שמח/ה}} שדיברתם?'**
  String feedbackQuestion(String gender);

  /// No description provided for @feedbackVeryGood.
  ///
  /// In he, this message translates to:
  /// **'מאוד'**
  String get feedbackVeryGood;

  /// No description provided for @feedbackGood.
  ///
  /// In he, this message translates to:
  /// **'כן'**
  String get feedbackGood;

  /// No description provided for @feedbackNotReally.
  ///
  /// In he, this message translates to:
  /// **'לא במיוחד'**
  String get feedbackNotReally;

  /// No description provided for @feedbackAgainQuestion.
  ///
  /// In he, this message translates to:
  /// **'שנחבר ביניכם שוב בעתיד?'**
  String get feedbackAgainQuestion;

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

  /// No description provided for @invitationText.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}} עכשיו לכ-{minutes} דקות. מתאים לך לדבר?'**
  String invitationText(String name, String gender, int minutes);

  /// No description provided for @invitationNotNow.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get invitationNotNow;

  /// No description provided for @invitationMute.
  ///
  /// In he, this message translates to:
  /// **'להשתיק הצעות כאלה ל-{hours} שעות'**
  String invitationMute(int hours);

  /// No description provided for @driverSearching.
  ///
  /// In he, this message translates to:
  /// **'מחפשים...'**
  String get driverSearching;

  /// No description provided for @driverCall.
  ///
  /// In he, this message translates to:
  /// **'שיחה'**
  String get driverCall;

  /// No description provided for @driverNext.
  ///
  /// In he, this message translates to:
  /// **'הבא'**
  String get driverNext;

  /// No description provided for @driverStop.
  ///
  /// In he, this message translates to:
  /// **'עצור'**
  String get driverStop;

  /// No description provided for @driverWaiting.
  ///
  /// In he, this message translates to:
  /// **'מחכים לאישור של {name}'**
  String driverWaiting(String name);

  /// No description provided for @driverInVehicle.
  ///
  /// In he, this message translates to:
  /// **'נראה שהמכשיר ברכב'**
  String get driverInVehicle;

  /// No description provided for @driverBecomeAvailable.
  ///
  /// In he, this message translates to:
  /// **'זמין לשיחה'**
  String get driverBecomeAvailable;

  /// No description provided for @driverFindAnother.
  ///
  /// In he, this message translates to:
  /// **'שיחה נוספת'**
  String get driverFindAnother;

  /// No description provided for @driverSafety.
  ///
  /// In he, this message translates to:
  /// **'בנהיגה: רק דיבורית ומתקן לרכב'**
  String get driverSafety;

  /// No description provided for @driverNotNow.
  ///
  /// In he, this message translates to:
  /// **'לא עכשיו'**
  String get driverNotNow;

  /// No description provided for @connTabClose.
  ///
  /// In he, this message translates to:
  /// **'קרובים'**
  String get connTabClose;

  /// No description provided for @connTabReconnect.
  ///
  /// In he, this message translates to:
  /// **'לחדש קשר'**
  String get connTabReconnect;

  /// No description provided for @connTabColleagues.
  ///
  /// In he, this message translates to:
  /// **'קולגות ומכרים'**
  String get connTabColleagues;

  /// No description provided for @connTabFof.
  ///
  /// In he, this message translates to:
  /// **'חברים של חברים'**
  String get connTabFof;

  /// No description provided for @connLastTalked.
  ///
  /// In he, this message translates to:
  /// **'דיברתם כאן לפני {duration}'**
  String connLastTalked(String duration);

  /// No description provided for @connLastTalkedToday.
  ///
  /// In he, this message translates to:
  /// **'דיברתם כאן היום'**
  String get connLastTalkedToday;

  /// No description provided for @connNeverTalked.
  ///
  /// In he, this message translates to:
  /// **'עוד לא דיברתם כאן'**
  String get connNeverTalked;

  /// No description provided for @connEmpty.
  ///
  /// In he, this message translates to:
  /// **'אין כאן אף אחד כרגע'**
  String get connEmpty;

  /// No description provided for @connFofOff.
  ///
  /// In he, this message translates to:
  /// **'כדי לראות חברים של חברים, צריך להפעיל את האפשרות במסך גילוי. יופיעו רק מי שגם הפעילו אותה.'**
  String get connFofOff;

  /// No description provided for @addFriend.
  ///
  /// In he, this message translates to:
  /// **'הוספת חבר'**
  String get addFriend;

  /// No description provided for @addFriendInviteLink.
  ///
  /// In he, this message translates to:
  /// **'קישור הזמנה'**
  String get addFriendInviteLink;

  /// No description provided for @addFriendInviteLinkBody.
  ///
  /// In he, this message translates to:
  /// **'שולחים את הקישור למי שרוצים. אחרי שיצטרפו — תהיו מחוברים.'**
  String get addFriendInviteLinkBody;

  /// No description provided for @addFriendCopy.
  ///
  /// In he, this message translates to:
  /// **'העתק קישור'**
  String get addFriendCopy;

  /// No description provided for @addFriendCopied.
  ///
  /// In he, this message translates to:
  /// **'הקישור הועתק (קישור לדוגמה בלבד)'**
  String get addFriendCopied;

  /// No description provided for @addFriendQrSoon.
  ///
  /// In he, this message translates to:
  /// **'קוד QR יתווסף בהמשך'**
  String get addFriendQrSoon;

  /// No description provided for @addFriendSearch.
  ///
  /// In he, this message translates to:
  /// **'חיפוש לפי שם'**
  String get addFriendSearch;

  /// No description provided for @addFriendAdd.
  ///
  /// In he, this message translates to:
  /// **'הוסף'**
  String get addFriendAdd;

  /// No description provided for @addFriendConnected.
  ///
  /// In he, this message translates to:
  /// **'מחובר'**
  String get addFriendConnected;

  /// No description provided for @addFriendGroups.
  ///
  /// In he, this message translates to:
  /// **'קבוצות הזמנה'**
  String get addFriendGroups;

  /// No description provided for @addFriendGroupInvite.
  ///
  /// In he, this message translates to:
  /// **'הזמן לקבוצה'**
  String get addFriendGroupInvite;

  /// No description provided for @mutualFriendsShort.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{אין חברים משותפים} =1{חבר משותף אחד} other{{count} חברים משותפים}}'**
  String mutualFriendsShort(int count);

  /// No description provided for @personRelationship.
  ///
  /// In he, this message translates to:
  /// **'סוג הקשר (לא חובה)'**
  String get personRelationship;

  /// No description provided for @personCalls.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{עוד לא דיברתם כאן} =1{שיחה אחת כאן} other{{count} שיחות כאן}}'**
  String personCalls(int count);

  /// No description provided for @personPausedUntil.
  ///
  /// In he, this message translates to:
  /// **'לא יוצע עד {date}'**
  String personPausedUntil(DateTime date);

  /// No description provided for @personAllow.
  ///
  /// In he, this message translates to:
  /// **'להציע שוב'**
  String get personAllow;

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

  /// No description provided for @discoverIntro.
  ///
  /// In he, this message translates to:
  /// **'כאן קובעים כמה פתוח להיות. כל רמה פועלת רק אם גם הצד השני בחר בה.'**
  String get discoverIntro;

  /// No description provided for @discoverFofTitle.
  ///
  /// In he, this message translates to:
  /// **'פתוח להצעות של חברים של חברים'**
  String get discoverFofTitle;

  /// No description provided for @discoverFofBody.
  ///
  /// In he, this message translates to:
  /// **'תוצעו זה לזה רק אם שניכם הפעלתם. נציג כמה חברים משותפים יש לכם — בלי שמות.'**
  String get discoverFofBody;

  /// No description provided for @discoverInterests.
  ///
  /// In he, this message translates to:
  /// **'תחומי עניין'**
  String get discoverInterests;

  /// No description provided for @discoverInterestsBody.
  ///
  /// In he, this message translates to:
  /// **'עוזרים להתאמה ולהסבר למה מישהו הוצע.'**
  String get discoverInterestsBody;

  /// No description provided for @discoverLanguages.
  ///
  /// In he, this message translates to:
  /// **'שפות שיחה'**
  String get discoverLanguages;

  /// No description provided for @langHe.
  ///
  /// In he, this message translates to:
  /// **'עברית'**
  String get langHe;

  /// No description provided for @langEn.
  ///
  /// In he, this message translates to:
  /// **'אנגלית'**
  String get langEn;

  /// No description provided for @settingsDriving.
  ///
  /// In he, this message translates to:
  /// **'נסיעה'**
  String get settingsDriving;

  /// No description provided for @settingsAutoDriving.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה'**
  String get settingsAutoDriving;

  /// No description provided for @settingsAutoDrivingBody.
  ///
  /// In he, this message translates to:
  /// **'כשנזהה שהמכשיר כנראה ברכב, נסמן אותך כזמין. שיחה מתחילה רק באישור — או בחיבור מהיר ששניכם סימנתם מראש.'**
  String get settingsAutoDrivingBody;

  /// No description provided for @settingsAutoDrivingDialogTitle.
  ///
  /// In he, this message translates to:
  /// **'לפני שמפעילים'**
  String get settingsAutoDrivingDialogTitle;

  /// No description provided for @settingsAutoDrivingDialogBody.
  ///
  /// In he, this message translates to:
  /// **'• זמינות אוטומטית היא לא אישור לשיחה — שיחה דורשת אישור של שני הצדדים, או חיבור מהיר ששניכם סימנתם מראש.\n• הזיהוי נעשה בטלפון בלבד. לא נשלח מיקום.\n• המערכת יודעת רק שהמכשיר כנראה ברכב — לא מי נוהג.\n• באב-הטיפוס, הנסיעה מדומה דרך כלי המפתחים.'**
  String get settingsAutoDrivingDialogBody;

  /// No description provided for @enable.
  ///
  /// In he, this message translates to:
  /// **'הפעל'**
  String get enable;

  /// No description provided for @settingsCarBluetooth.
  ///
  /// In he, this message translates to:
  /// **'Bluetooth של הרכב'**
  String get settingsCarBluetooth;

  /// No description provided for @settingsCarBluetoothSoon.
  ///
  /// In he, this message translates to:
  /// **'יתווסף בשלב 4 — לזיהוי בביטחון גבוה יותר'**
  String get settingsCarBluetoothSoon;

  /// No description provided for @settingsRelPrefs.
  ///
  /// In he, this message translates to:
  /// **'את מי להציע לי'**
  String get settingsRelPrefs;

  /// No description provided for @settingsNotifications.
  ///
  /// In he, this message translates to:
  /// **'הזמנות מאחרים'**
  String get settingsNotifications;

  /// No description provided for @beaconOff.
  ///
  /// In he, this message translates to:
  /// **'לא לשלוח לי הזמנות'**
  String get beaconOff;

  /// No description provided for @beaconLow.
  ///
  /// In he, this message translates to:
  /// **'מעט — עד הזמנה אחת ביום מכל אדם'**
  String get beaconLow;

  /// No description provided for @beaconNormal.
  ///
  /// In he, this message translates to:
  /// **'רגיל — עד שתיים ביום מכל אדם'**
  String get beaconNormal;

  /// No description provided for @settingsMutedUntil.
  ///
  /// In he, this message translates to:
  /// **'מושתק עד {time}'**
  String settingsMutedUntil(DateTime time);

  /// No description provided for @unmute.
  ///
  /// In he, this message translates to:
  /// **'בטל השתקה'**
  String get unmute;

  /// No description provided for @settingsPrivacy.
  ///
  /// In he, this message translates to:
  /// **'פרטיות'**
  String get settingsPrivacy;

  /// No description provided for @privacyTitle.
  ///
  /// In he, this message translates to:
  /// **'מה אנחנו יודעים ומה לא'**
  String get privacyTitle;

  /// No description provided for @privacyShared.
  ///
  /// In he, this message translates to:
  /// **'מה רואים אחרים: שם, תמונה, שאת/ה זמין/ה ולכמה זמן. מספר הטלפון שלך משמש רק לחיוג אחרי ששניכם הסכמתם — וחברים של חברים מקבלים אותו רק אם אישרת.'**
  String get privacyShared;

  /// No description provided for @privacyServer.
  ///
  /// In he, this message translates to:
  /// **'מה השרת יודע: זמין/לא זמין, מצב (למשל נסיעה) ועד מתי.'**
  String get privacyServer;

  /// No description provided for @privacyNever.
  ///
  /// In he, this message translates to:
  /// **'מה לא נשמר ולא משותף: מיקום, מסלול, מהירות, הקלטות, תמלולים, יומן השיחות ואנשי הקשר בטלפון.'**
  String get privacyNever;

  /// No description provided for @privacyLocal.
  ///
  /// In he, this message translates to:
  /// **'זיהוי נסיעה נעשה בטלפון עצמו.'**
  String get privacyLocal;

  /// No description provided for @privacyExpiry.
  ///
  /// In he, this message translates to:
  /// **'לזמינות יש תמיד זמן סיום — גם אם האפליקציה נסגרת.'**
  String get privacyExpiry;

  /// No description provided for @settingsBlocked.
  ///
  /// In he, this message translates to:
  /// **'משתמשים חסומים'**
  String get settingsBlocked;

  /// No description provided for @blockedEmpty.
  ///
  /// In he, this message translates to:
  /// **'אין משתמשים חסומים'**
  String get blockedEmpty;

  /// No description provided for @unblock.
  ///
  /// In he, this message translates to:
  /// **'בטל חסימה'**
  String get unblock;

  /// No description provided for @settingsDevTools.
  ///
  /// In he, this message translates to:
  /// **'כלי מפתחים'**
  String get settingsDevTools;

  /// No description provided for @settingsAbout.
  ///
  /// In he, this message translates to:
  /// **'אב-טיפוס · שלב 1 · כל הנתונים מדומים'**
  String get settingsAbout;

  /// No description provided for @debugTitle.
  ///
  /// In he, this message translates to:
  /// **'כלי מפתחים'**
  String get debugTitle;

  /// No description provided for @debugSubtitle.
  ///
  /// In he, this message translates to:
  /// **'לא יופיע בגרסה לחנות'**
  String get debugSubtitle;

  /// No description provided for @debugVehicle.
  ///
  /// In he, this message translates to:
  /// **'רכב'**
  String get debugVehicle;

  /// No description provided for @debugEnterVehicle.
  ///
  /// In he, this message translates to:
  /// **'נכנסתי לרכב'**
  String get debugEnterVehicle;

  /// No description provided for @debugEnterVehicleBt.
  ///
  /// In he, this message translates to:
  /// **'נכנסתי לרכב + Bluetooth'**
  String get debugEnterVehicleBt;

  /// No description provided for @debugExitVehicle.
  ///
  /// In he, this message translates to:
  /// **'יצאתי מהרכב'**
  String get debugExitVehicle;

  /// No description provided for @debugInVehicleYes.
  ///
  /// In he, this message translates to:
  /// **'מצב: המכשיר כנראה ברכב'**
  String get debugInVehicleYes;

  /// No description provided for @debugInVehicleNo.
  ///
  /// In he, this message translates to:
  /// **'מצב: לא ברכב'**
  String get debugInVehicleNo;

  /// No description provided for @debugAutoOffWarning.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית כבויה בהגדרות — כניסה לרכב רק תעביר למצב נהג.'**
  String get debugAutoOffWarning;

  /// No description provided for @debugTime.
  ///
  /// In he, this message translates to:
  /// **'זמן'**
  String get debugTime;

  /// No description provided for @debugFakeClock.
  ///
  /// In he, this message translates to:
  /// **'{date} {time}'**
  String debugFakeClock(String date, String time);

  /// No description provided for @debugResetTime.
  ///
  /// In he, this message translates to:
  /// **'אפס זמן'**
  String get debugResetTime;

  /// No description provided for @debugPlus5m.
  ///
  /// In he, this message translates to:
  /// **'5 דק׳ קדימה'**
  String get debugPlus5m;

  /// No description provided for @debugPlus15m.
  ///
  /// In he, this message translates to:
  /// **'15 דק׳ קדימה'**
  String get debugPlus15m;

  /// No description provided for @debugPlus1h.
  ///
  /// In he, this message translates to:
  /// **'שעה קדימה'**
  String get debugPlus1h;

  /// No description provided for @debugPlus1d.
  ///
  /// In he, this message translates to:
  /// **'יום קדימה'**
  String get debugPlus1d;

  /// No description provided for @debugPlus30d.
  ///
  /// In he, this message translates to:
  /// **'30 יום קדימה'**
  String get debugPlus30d;

  /// No description provided for @debugMatching.
  ///
  /// In he, this message translates to:
  /// **'התאמות'**
  String get debugMatching;

  /// No description provided for @debugSimulateMatch.
  ///
  /// In he, this message translates to:
  /// **'דמה התאמה'**
  String get debugSimulateMatch;

  /// No description provided for @debugForceNoMatch.
  ///
  /// In he, this message translates to:
  /// **'דמה אין-התאמה'**
  String get debugForceNoMatch;

  /// No description provided for @debugEveryoneUnavailable.
  ///
  /// In he, this message translates to:
  /// **'כולם לא זמינים'**
  String get debugEveryoneUnavailable;

  /// No description provided for @debugAnswers.
  ///
  /// In he, this message translates to:
  /// **'תשובת הצד השני'**
  String get debugAnswers;

  /// No description provided for @debugAnswerAuto.
  ///
  /// In he, this message translates to:
  /// **'לפי הסתברות'**
  String get debugAnswerAuto;

  /// No description provided for @debugAnswerAccept.
  ///
  /// In he, this message translates to:
  /// **'תמיד מאשר'**
  String get debugAnswerAccept;

  /// No description provided for @debugAnswerDecline.
  ///
  /// In he, this message translates to:
  /// **'תמיד דוחה'**
  String get debugAnswerDecline;

  /// No description provided for @debugInvitation.
  ///
  /// In he, this message translates to:
  /// **'הזמנה נכנסת'**
  String get debugInvitation;

  /// No description provided for @debugSimulateInvitation.
  ///
  /// In he, this message translates to:
  /// **'דמה הזמנה נכנסת'**
  String get debugSimulateInvitation;

  /// No description provided for @debugInvitationMuted.
  ///
  /// In he, this message translates to:
  /// **'ההזמנה לא נמסרה — הזמנות מושתקות בהגדרות'**
  String get debugInvitationMuted;

  /// No description provided for @debugWhoIsFree.
  ///
  /// In he, this message translates to:
  /// **'מי פנוי'**
  String get debugWhoIsFree;

  /// No description provided for @debugNotAvailable.
  ///
  /// In he, this message translates to:
  /// **'לא פנוי'**
  String get debugNotAvailable;

  /// No description provided for @debugInspector.
  ///
  /// In he, this message translates to:
  /// **'מנוע ההתאמה — מאחורי הקלעים'**
  String get debugInspector;

  /// No description provided for @debugInspectorNote.
  ///
  /// In he, this message translates to:
  /// **'מבוסס על המצב הנוכחי. אנשים שלא זמינים מופיעים כאן בדירוג להזמנות.'**
  String get debugInspectorNote;

  /// No description provided for @debugInspectorRanked.
  ///
  /// In he, this message translates to:
  /// **'מדורגים'**
  String get debugInspectorRanked;

  /// No description provided for @debugInspectorRejected.
  ///
  /// In he, this message translates to:
  /// **'סוננו'**
  String get debugInspectorRejected;

  /// No description provided for @debugScore.
  ///
  /// In he, this message translates to:
  /// **'ציון {score}'**
  String debugScore(String score);

  /// No description provided for @filterBlocked.
  ///
  /// In he, this message translates to:
  /// **'חסום'**
  String get filterBlocked;

  /// No description provided for @filterSkipped.
  ///
  /// In he, this message translates to:
  /// **'דולג בחלון הנוכחי'**
  String get filterSkipped;

  /// No description provided for @filterSafety.
  ///
  /// In he, this message translates to:
  /// **'מגבלת בטיחות'**
  String get filterSafety;

  /// No description provided for @filterNotToday.
  ///
  /// In he, this message translates to:
  /// **'לא היום'**
  String get filterNotToday;

  /// No description provided for @filterDoNotSuggest.
  ///
  /// In he, this message translates to:
  /// **'לא להציע בתקופה הקרובה'**
  String get filterDoNotSuggest;

  /// No description provided for @filterRelExcluded.
  ///
  /// In he, this message translates to:
  /// **'סוג קשר שביקשת לא להציע'**
  String get filterRelExcluded;

  /// No description provided for @filterLanguage.
  ///
  /// In he, this message translates to:
  /// **'אין שפה משותפת'**
  String get filterLanguage;

  /// No description provided for @filterNotAvailable.
  ///
  /// In he, this message translates to:
  /// **'לא זמין עכשיו'**
  String get filterNotAvailable;

  /// No description provided for @filterFof.
  ///
  /// In he, this message translates to:
  /// **'חבר של חבר — לא שניכם הפעלתם'**
  String get filterFof;

  /// No description provided for @filterTier.
  ///
  /// In he, this message translates to:
  /// **'רמת התאמה שלא שניכם פתוחים אליה'**
  String get filterTier;

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
  /// **'זמין עכשיו'**
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

  /// No description provided for @debugAnalytics.
  ///
  /// In he, this message translates to:
  /// **'מדדים (נשמרים במכשיר בלבד)'**
  String get debugAnalytics;

  /// No description provided for @debugAnalyticsEmpty.
  ///
  /// In he, this message translates to:
  /// **'עוד אין אירועים'**
  String get debugAnalyticsEmpty;

  /// No description provided for @debugReset.
  ///
  /// In he, this message translates to:
  /// **'אפס את כל הנתונים'**
  String get debugReset;

  /// No description provided for @debugResetDone.
  ///
  /// In he, this message translates to:
  /// **'הנתונים אופסו'**
  String get debugResetDone;

  /// No description provided for @optionsTitle.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =1{מישהו פנוי עכשיו} other{{count} פנויים עכשיו}}'**
  String optionsTitle(int count);

  /// No description provided for @moreOptions.
  ///
  /// In he, this message translates to:
  /// **'אפשרויות נוספות'**
  String get moreOptions;

  /// No description provided for @talkNowAccepted.
  ///
  /// In he, this message translates to:
  /// **'לדבר — כבר אישר/ה'**
  String get talkNowAccepted;

  /// No description provided for @starterLine.
  ///
  /// In he, this message translates to:
  /// **'נושא לפתיחה: {text}'**
  String starterLine(String text);

  /// No description provided for @routineDue.
  ///
  /// In he, this message translates to:
  /// **'זה הזמן הרגיל שלך ל{mode}. להיות זמין ל-{minutes} דק׳?'**
  String routineDue(String mode, int minutes);

  /// No description provided for @routineStart.
  ///
  /// In he, this message translates to:
  /// **'כן'**
  String get routineStart;

  /// No description provided for @availableTo.
  ///
  /// In he, this message translates to:
  /// **'זמין ל:'**
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

  /// No description provided for @quickConnectTitle.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name}'**
  String quickConnectTitle(String name);

  /// No description provided for @quickConnectIn.
  ///
  /// In he, this message translates to:
  /// **'{seconds, plural, =0{מחייג…} =1{בעוד שנייה} other{בעוד {seconds} שניות}}'**
  String quickConnectIn(int seconds);

  /// No description provided for @quickConnectWhy.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר — שניכם אישרתם מראש. אפשר לבטל עכשיו או לומר \"בטל\".'**
  String get quickConnectWhy;

  /// No description provided for @voiceMessageSimulated.
  ///
  /// In he, this message translates to:
  /// **'הדמיה — שום דבר לא מוקלט או נשלח'**
  String get voiceMessageSimulated;

  /// No description provided for @voiceMessageTitle.
  ///
  /// In he, this message translates to:
  /// **'הודעה קולית ל{name}'**
  String voiceMessageTitle(String name);

  /// No description provided for @voiceMessageHint.
  ///
  /// In he, this message translates to:
  /// **'עד {max} שניות. למשל: \"היי, חשבתי עליך, נדבר בקרוב\".'**
  String voiceMessageHint(int max);

  /// No description provided for @voiceMessageSend.
  ///
  /// In he, this message translates to:
  /// **'שליחה'**
  String get voiceMessageSend;

  /// No description provided for @voiceMessageAction.
  ///
  /// In he, this message translates to:
  /// **'הודעה קולית'**
  String get voiceMessageAction;

  /// No description provided for @callViaPhone.
  ///
  /// In he, this message translates to:
  /// **'שיחת טלפון רגילה'**
  String get callViaPhone;

  /// No description provided for @callInApp.
  ///
  /// In he, this message translates to:
  /// **'שיחה באפליקציה · המספרים נשארים פרטיים'**
  String get callInApp;

  /// No description provided for @callWeakSignal.
  ///
  /// In he, this message translates to:
  /// **'קליטה חלשה'**
  String get callWeakSignal;

  /// No description provided for @callWindowEndedKeepTalking.
  ///
  /// In he, this message translates to:
  /// **'זמן הזמינות הסתיים — השיחה ממשיכה כרגיל'**
  String get callWindowEndedKeepTalking;

  /// No description provided for @callPhoneSimulated.
  ///
  /// In he, this message translates to:
  /// **'באפליקציה האמיתית הטלפון מחייג עכשיו ל{name}. כאן — אם הוגדר מספר בדיקה, הוא מחויג במקומו.'**
  String callPhoneSimulated(String name);

  /// No description provided for @callDialTestNumber.
  ///
  /// In he, this message translates to:
  /// **'חייג באמת למספר הבדיקה'**
  String get callDialTestNumber;

  /// No description provided for @callDialUnsupported.
  ///
  /// In he, this message translates to:
  /// **'אי אפשר לחייג מכאן (למשל בדפדפן)'**
  String get callDialUnsupported;

  /// No description provided for @callSetTestNumberHint.
  ///
  /// In he, this message translates to:
  /// **'אפשר להגדיר מספר לבדיקת חיוג אמיתי בכלי המפתחים'**
  String get callSetTestNumberHint;

  /// No description provided for @callDropped.
  ///
  /// In he, this message translates to:
  /// **'השיחה נותקה'**
  String get callDropped;

  /// No description provided for @callRetry.
  ///
  /// In he, this message translates to:
  /// **'לנסות שוב'**
  String get callRetry;

  /// No description provided for @callOnHold.
  ///
  /// In he, this message translates to:
  /// **'השיחה בהמתנה — נכנסה שיחת טלפון'**
  String get callOnHold;

  /// No description provided for @callResume.
  ///
  /// In he, this message translates to:
  /// **'להמשיך'**
  String get callResume;

  /// No description provided for @callWeAreDone.
  ///
  /// In he, this message translates to:
  /// **'סיימנו'**
  String get callWeAreDone;

  /// No description provided for @feedbackDidNotTalk.
  ///
  /// In he, this message translates to:
  /// **'לא דיברנו בסוף'**
  String get feedbackDidNotTalk;

  /// No description provided for @offlineBanner.
  ///
  /// In he, this message translates to:
  /// **'אין חיבור לאינטרנט — ננסה שוב אוטומטית'**
  String get offlineBanner;

  /// No description provided for @noticeNoAnswer.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{לא ענתה} male{לא ענה} other{לא ענה/תה}}. אפשר להשאיר הודעה קולית.'**
  String noticeNoAnswer(String name, String gender);

  /// No description provided for @noticeNoLongerAvailable.
  ///
  /// In he, this message translates to:
  /// **'{name} כבר {gender, select, female{לא פנויה} male{לא פנוי} other{לא פנוי/ה}}. ממשיכים.'**
  String noticeNoLongerAvailable(String name, String gender);

  /// No description provided for @noticeVoiceMessageSent.
  ///
  /// In he, this message translates to:
  /// **'ההודעה ל{name} נשלחה (הדמיה)'**
  String noticeVoiceMessageSent(String name);

  /// No description provided for @noticeMicDenied.
  ///
  /// In he, this message translates to:
  /// **'אין הרשאת מיקרופון, אז אי אפשר לענות בקול. אפשר לאשר בהגדרות הטלפון ‹ אפליקציות ‹ DriveTalk ‹ הרשאות. הכפתורים תמיד עובדים.'**
  String get noticeMicDenied;

  /// No description provided for @noticeQuickConnectCancelled.
  ///
  /// In he, this message translates to:
  /// **'בוטל. לא נתקשר ל{name} עכשיו.'**
  String noticeQuickConnectCancelled(String name);

  /// No description provided for @voiceQuickConnect.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name}.'**
  String voiceQuickConnect(String name, int seconds);

  /// No description provided for @voiceInvitation.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}}. לדבר?'**
  String voiceInvitation(String name, String gender, int minutes);

  /// No description provided for @voiceSuggestion.
  ///
  /// In he, this message translates to:
  /// **'{name}. לדבר?'**
  String voiceSuggestion(String name, String gender, int minutes, String who);

  /// No description provided for @settingsProfile.
  ///
  /// In he, this message translates to:
  /// **'הפרופיל שלי'**
  String get settingsProfile;

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

  /// No description provided for @photoPrivacyNote.
  ///
  /// In he, this message translates to:
  /// **'באב-הטיפוס התמונה נשמרת רק בטלפון הזה. בגרסה האמיתית תמונות ייבדקו לפני שיוצגו לאחרים.'**
  String get photoPrivacyNote;

  /// No description provided for @myPhoneNumber.
  ///
  /// In he, this message translates to:
  /// **'המספר שלי'**
  String get myPhoneNumber;

  /// No description provided for @myPhoneNumberHelp.
  ///
  /// In he, this message translates to:
  /// **'משמש רק לחיוג רגיל אחרי ששניכם הסכמתם. לא מוצג לאף אחד על המסך.'**
  String get myPhoneNumberHelp;

  /// No description provided for @shareNumberWithFof.
  ///
  /// In he, this message translates to:
  /// **'לאפשר חיוג רגיל גם עם חברים של חברים'**
  String get shareNumberWithFof;

  /// No description provided for @shareNumberWithFofBody.
  ///
  /// In he, this message translates to:
  /// **'רק אם גם הצד השני הסכים. אחרת השיחה איתם תהיה בתוך האפליקציה, והמספרים יישארו פרטיים.'**
  String get shareNumberWithFofBody;

  /// No description provided for @settingsVoiceReadout.
  ///
  /// In he, this message translates to:
  /// **'הקראה בקול בנסיעה'**
  String get settingsVoiceReadout;

  /// No description provided for @settingsVoiceReadoutBody.
  ///
  /// In he, this message translates to:
  /// **'הטלפון מקריא מי פנוי ושואל אם לדבר'**
  String get settingsVoiceReadoutBody;

  /// No description provided for @settingsVoiceCommands.
  ///
  /// In he, this message translates to:
  /// **'לענות \"כן\" / \"לא\" בקול'**
  String get settingsVoiceCommands;

  /// No description provided for @settingsVoiceCommandsBody.
  ///
  /// In he, this message translates to:
  /// **'דורש הרשאת מיקרופון. הזיהוי נעשה דרך הטלפון ושום דבר לא נשמר.'**
  String get settingsVoiceCommandsBody;

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

  /// No description provided for @routinesIntro.
  ///
  /// In he, this message translates to:
  /// **'ספרו לנו מתי אתם בדרך כלל בדרכים. בזמנים האלה נציע בלחיצה אחת להפוך לזמינים.'**
  String get routinesIntro;

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

  /// No description provided for @circlesTitle.
  ///
  /// In he, this message translates to:
  /// **'המעגלים שלי'**
  String get circlesTitle;

  /// No description provided for @circlesCount.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{אין מעגלים} =1{מעגל אחד} other{{count} מעגלים}}'**
  String circlesCount(int count);

  /// No description provided for @circlesIntro.
  ///
  /// In he, this message translates to:
  /// **'מעגלים פרטיים שרק את/ה רואה. כשנהיים זמינים אפשר לבחור להיות זמינים רק למעגל אחד.'**
  String get circlesIntro;

  /// No description provided for @circleAdd.
  ///
  /// In he, this message translates to:
  /// **'מעגל חדש'**
  String get circleAdd;

  /// No description provided for @circleMembers.
  ///
  /// In he, this message translates to:
  /// **'{count, plural, =0{אין חברים במעגל} =1{אדם אחד} other{{count} אנשים}}'**
  String circleMembers(int count);

  /// No description provided for @circleDelete.
  ///
  /// In he, this message translates to:
  /// **'מחיקת המעגל'**
  String get circleDelete;

  /// No description provided for @circleNameHint.
  ///
  /// In he, this message translates to:
  /// **'למשל: חברים מהצבא'**
  String get circleNameHint;

  /// No description provided for @filterNotInCircle.
  ///
  /// In he, this message translates to:
  /// **'לא במעגל שבחרת'**
  String get filterNotInCircle;

  /// No description provided for @quickConnectToggle.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר'**
  String get quickConnectToggle;

  /// No description provided for @quickConnectExplain.
  ///
  /// In he, this message translates to:
  /// **'כששניכם פנויים — מתקשרים מיד, בלי לחכות לאישור (עם 5 שניות לביטול). עובד רק אם גם {name} יסמן אותך.'**
  String quickConnectExplain(String name);

  /// No description provided for @quickConnectMutual.
  ///
  /// In he, this message translates to:
  /// **'פעיל — גם {name} סימן אותך.'**
  String quickConnectMutual(String name);

  /// No description provided for @quickConnectWaiting.
  ///
  /// In he, this message translates to:
  /// **'סימנת. יופעל כשגם {name} יסמן אותך.'**
  String quickConnectWaiting(String name);

  /// No description provided for @debugScenarios.
  ///
  /// In he, this message translates to:
  /// **'תרחישי תקלות והפרעות'**
  String get debugScenarios;

  /// No description provided for @debugVoice.
  ///
  /// In he, this message translates to:
  /// **'קול'**
  String get debugVoice;

  /// No description provided for @debugVoiceBody.
  ///
  /// In he, this message translates to:
  /// **'בדפדפן אין מיקרופון — כאן אפשר לדמות תשובה קולית במצב נהג.'**
  String get debugVoiceBody;

  /// No description provided for @debugVoiceYes.
  ///
  /// In he, this message translates to:
  /// **'דמה \"כן\"'**
  String get debugVoiceYes;

  /// No description provided for @debugVoiceNo.
  ///
  /// In he, this message translates to:
  /// **'דמה \"לא\"'**
  String get debugVoiceNo;

  /// No description provided for @debugTestDial.
  ///
  /// In he, this message translates to:
  /// **'חיוג אמיתי לבדיקה'**
  String get debugTestDial;

  /// No description provided for @debugTestDialLabel.
  ///
  /// In he, this message translates to:
  /// **'מספר לבדיקה (למשל המספר שלך)'**
  String get debugTestDialLabel;

  /// No description provided for @debugTestDialHelp.
  ///
  /// In he, this message translates to:
  /// **'האנשים המדומים לעולם לא מחויגים. במקומם יחויג המספר שכאן (למשל המספר שלך או של מישהו שמסכים).'**
  String get debugTestDialHelp;

  /// No description provided for @debugAnswerNone.
  ///
  /// In he, this message translates to:
  /// **'לא עונה'**
  String get debugAnswerNone;

  /// No description provided for @scRun.
  ///
  /// In he, this message translates to:
  /// **'הפעל'**
  String get scRun;

  /// No description provided for @scNoAnswerTitle.
  ///
  /// In he, this message translates to:
  /// **'הצד השני לא עונה'**
  String get scNoAnswerTitle;

  /// No description provided for @scNoAnswerBody.
  ///
  /// In he, this message translates to:
  /// **'לחצו \"לדבר\" על מישהו — אחרי 30 שניות בלי תשובה ממשיכים הלאה.'**
  String get scNoAnswerBody;

  /// No description provided for @scNoAnswerArmed.
  ///
  /// In he, this message translates to:
  /// **'מעכשיו אף אחד לא עונה. אפשר להחזיר ב\"תשובת הצד השני\".'**
  String get scNoAnswerArmed;

  /// No description provided for @scGoneTitle.
  ///
  /// In he, this message translates to:
  /// **'הפסיק להיות זמין בזמן ההמתנה'**
  String get scGoneTitle;

  /// No description provided for @scGoneBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בזמן שמחכים לתשובה.'**
  String get scGoneBody;

  /// No description provided for @scBlockedTitle.
  ///
  /// In he, this message translates to:
  /// **'חסם אותי בזמן ההמתנה'**
  String get scBlockedTitle;

  /// No description provided for @scBlockedBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בזמן שמחכים. נראה כמו \"לא יכול עכשיו\" — בלי לחשוף.'**
  String get scBlockedBody;

  /// No description provided for @scInviteWhileWaitingTitle.
  ///
  /// In he, this message translates to:
  /// **'הזמנה נכנסת בזמן המתנה'**
  String get scInviteWhileWaitingTitle;

  /// No description provided for @scInviteWhileWaitingBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בזמן שמחכים. אפשר לבחור בהזמנה במקום.'**
  String get scInviteWhileWaitingBody;

  /// No description provided for @scDroppedTitle.
  ///
  /// In he, this message translates to:
  /// **'השיחה נותקה'**
  String get scDroppedTitle;

  /// No description provided for @scDroppedBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בשיחה בתוך האפליקציה (עם חבר של חבר שלא שיתף מספר).'**
  String get scDroppedBody;

  /// No description provided for @scHoldTitle.
  ///
  /// In he, this message translates to:
  /// **'שיחת טלפון נכנסת באמצע'**
  String get scHoldTitle;

  /// No description provided for @scHoldBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בשיחה בתוך האפליקציה. השיחה עוברת להמתנה.'**
  String get scHoldBody;

  /// No description provided for @scWeakSignalTitle.
  ///
  /// In he, this message translates to:
  /// **'קליטה חלשה'**
  String get scWeakSignalTitle;

  /// No description provided for @scWeakSignalOff.
  ///
  /// In he, this message translates to:
  /// **'להחזיר קליטה טובה'**
  String get scWeakSignalOff;

  /// No description provided for @scWeakSignalBody.
  ///
  /// In he, this message translates to:
  /// **'מופיע סימן קטן בשיחה בתוך האפליקציה.'**
  String get scWeakSignalBody;

  /// No description provided for @scExpireInCallTitle.
  ///
  /// In he, this message translates to:
  /// **'הזמינות נגמרת באמצע שיחה'**
  String get scExpireInCallTitle;

  /// No description provided for @scExpireInCallBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בשיחה. השיחה ממשיכה, הזמינות נסגרת אחריה.'**
  String get scExpireInCallBody;

  /// No description provided for @scExitCarInCallTitle.
  ///
  /// In he, this message translates to:
  /// **'יציאה מהרכב באמצע שיחה'**
  String get scExitCarInCallTitle;

  /// No description provided for @scExitCarInCallBody.
  ///
  /// In he, this message translates to:
  /// **'זמין בשיחה. מצב הנהג נגמר רק כשהשיחה מסתיימת.'**
  String get scExitCarInCallBody;

  /// No description provided for @scEnterCarChoosingTitle.
  ///
  /// In he, this message translates to:
  /// **'כניסה לרכב בזמן בחירה'**
  String get scEnterCarChoosingTitle;

  /// No description provided for @scEnterCarChoosingBody.
  ///
  /// In he, this message translates to:
  /// **'זמין כשמוצגות אפשרויות. עוברים מיד למצב נהג.'**
  String get scEnterCarChoosingBody;

  /// No description provided for @scOfflineTitle.
  ///
  /// In he, this message translates to:
  /// **'אין אינטרנט'**
  String get scOfflineTitle;

  /// No description provided for @scOfflineOff.
  ///
  /// In he, this message translates to:
  /// **'להחזיר אינטרנט'**
  String get scOfflineOff;

  /// No description provided for @scOfflineBody.
  ///
  /// In he, this message translates to:
  /// **'מופיע פס עליון והחיפוש ממתין עד שהחיבור חוזר.'**
  String get scOfflineBody;

  /// No description provided for @scMicDeniedTitle.
  ///
  /// In he, this message translates to:
  /// **'אין הרשאת מיקרופון'**
  String get scMicDeniedTitle;

  /// No description provided for @scMicDeniedBody.
  ///
  /// In he, this message translates to:
  /// **'מוצג הסבר איך לאשר. הכפתורים ממשיכים לעבוד.'**
  String get scMicDeniedBody;

  /// No description provided for @scAppClosedTitle.
  ///
  /// In he, this message translates to:
  /// **'האפליקציה נסגרה לכמה שעות'**
  String get scAppClosedTitle;

  /// No description provided for @scAppClosedBody.
  ///
  /// In he, this message translates to:
  /// **'הזמינות נגמרת לבד — אף אחד לא נשאר \"זמין\" לנצח.'**
  String get scAppClosedBody;

  /// No description provided for @scQuickConnectTitle.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר עם אבא'**
  String get scQuickConnectTitle;

  /// No description provided for @scQuickConnectBody.
  ///
  /// In he, this message translates to:
  /// **'אבא נהיה פנוי. אם גם את/ה זמין/ה — מתחילה ספירה של 5 שניות עם ביטול.'**
  String get scQuickConnectBody;

  /// No description provided for @scQuickConnectHint.
  ///
  /// In he, this message translates to:
  /// **'קודם להפוך לזמין/ה, ואז להפעיל שוב.'**
  String get scQuickConnectHint;

  /// No description provided for @debugDialOnEveryCall.
  ///
  /// In he, this message translates to:
  /// **'לחייג באמת בכל שיחה'**
  String get debugDialOnEveryCall;

  /// No description provided for @debugDialOnEveryCallBody.
  ///
  /// In he, this message translates to:
  /// **'כשמגיעים לשיחת טלפון עם אדם מדומה — הטלפון יחייג באמת למספר הבדיקה'**
  String get debugDialOnEveryCallBody;

  /// No description provided for @debugDialNow.
  ///
  /// In he, this message translates to:
  /// **'חייג עכשיו לבדיקה'**
  String get debugDialNow;

  /// No description provided for @talkShort.
  ///
  /// In he, this message translates to:
  /// **'לדבר'**
  String get talkShort;

  /// No description provided for @realBadge.
  ///
  /// In he, this message translates to:
  /// **'בדיקה אמיתית'**
  String get realBadge;

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

  /// No description provided for @realBackToDemo.
  ///
  /// In he, this message translates to:
  /// **'למצב הדגמה'**
  String get realBackToDemo;

  /// No description provided for @realToReal.
  ///
  /// In he, this message translates to:
  /// **'בדיקה עם חבר אמיתי'**
  String get realToReal;

  /// No description provided for @realToRealBody.
  ///
  /// In he, this message translates to:
  /// **'חברים אמיתיים, שיחות אמיתיות. בלי אנשים מדומים.'**
  String get realToRealBody;

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

  /// No description provided for @realWelcomeBody.
  ///
  /// In he, this message translates to:
  /// **'בלי סיסמה ובלי מייל. רק שם, כדי שחברים יזהו אותך.'**
  String get realWelcomeBody;

  /// No description provided for @realPhoneLabel.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון (לא חובה)'**
  String get realPhoneLabel;

  /// No description provided for @realPhoneHelp.
  ///
  /// In he, this message translates to:
  /// **'נמסר רק לחבר ששניכם הסכמתם לדבר, ברגע השיחה — כדי לדבר בשיחה רגילה. בלי מספר: שיחה מדומה.'**
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
  /// **'{gender, select, female{את פנויה לשיחה} male{אתה פנוי לשיחה} other{את/ה פנוי/ה לשיחה}}'**
  String realMeAvailableTitle(String gender);

  /// No description provided for @realWaitingForFriends.
  ///
  /// In he, this message translates to:
  /// **'כשחבר יהיה פנוי — נשאל את שניכם.'**
  String get realWaitingForFriends;

  /// No description provided for @realFreeFriendsTitle.
  ///
  /// In he, this message translates to:
  /// **'פנויים עכשיו'**
  String get realFreeFriendsTitle;

  /// No description provided for @realNobodyFree.
  ///
  /// In he, this message translates to:
  /// **'אף חבר לא פנוי כרגע'**
  String get realNobodyFree;

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
  /// **'הזמן חבר'**
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
  /// **'אני בודק אפליקציה חדשה שמחברת בין חברים כששניהם פנויים לשיחה. בא לך לבדוק אותה איתי?'**
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
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}} עכשיו. רוצה לדבר?'**
  String realOfferTitle(String name, String gender);

  /// No description provided for @realTalkNow.
  ///
  /// In he, this message translates to:
  /// **'דבר עכשיו'**
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
  /// **'ברגע ש{name} {gender, select, female{תאשר} male{יאשר} other{יאשר/תאשר}} — מתחברים.'**
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

  /// No description provided for @realVoiceDidNotWorkOut.
  ///
  /// In he, this message translates to:
  /// **'לא הסתדר הפעם.'**
  String get realVoiceDidNotWorkOut;

  /// No description provided for @realVoiceTheyCall.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{מתקשרת} male{מתקשר} other{מתקשר/ת}} אליך.'**
  String realVoiceTheyCall(String name, String gender);

  /// No description provided for @realBothSaidYes.
  ///
  /// In he, this message translates to:
  /// **'שניכם אמרתם כן!'**
  String get realBothSaidYes;

  /// No description provided for @realConnecting.
  ///
  /// In he, this message translates to:
  /// **'מתחברים…'**
  String get realConnecting;

  /// No description provided for @realCallingIn.
  ///
  /// In he, this message translates to:
  /// **'מתקשרים ל{name} בעוד {seconds}…'**
  String realCallingIn(String name, int seconds);

  /// No description provided for @realCallNow.
  ///
  /// In he, this message translates to:
  /// **'להתקשר עכשיו'**
  String get realCallNow;

  /// No description provided for @realDialedTitle.
  ///
  /// In he, this message translates to:
  /// **'השיחה נפתחה בטלפון'**
  String get realDialedTitle;

  /// No description provided for @realDialedBody.
  ///
  /// In he, this message translates to:
  /// **'כשתסיימו — חזרו לכאן.'**
  String get realDialedBody;

  /// No description provided for @realTheyCallTitle.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{מתקשרת} male{מתקשר} other{מתקשר/ת}} אליך עכשיו'**
  String realTheyCallTitle(String name, String gender);

  /// No description provided for @realTheyCallBody.
  ///
  /// In he, this message translates to:
  /// **'שיחה רגילה, מהטלפון. אם לא הגיעה שיחה תוך דקה — לחצו למטה.'**
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
  /// **'לא שותפו מספרי טלפון, לכן זו שיחה מדומה. בשלב הבא תהיה כאן שיחת קול אמיתית.'**
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
  /// **'{name} {gender, select, female{הזמינה} male{הזמין} other{הזמין/ה}} אותך'**
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

  /// No description provided for @realFreeFor.
  ///
  /// In he, this message translates to:
  /// **'פנוי/ה · {minutes} דק׳'**
  String realFreeFor(int minutes);

  /// No description provided for @realNotFree.
  ///
  /// In he, this message translates to:
  /// **'לא פנוי/ה כרגע'**
  String get realNotFree;

  /// No description provided for @realTestIntro.
  ///
  /// In he, this message translates to:
  /// **'כאן רואים שהכל עובד. אם משהו לא עובד — \"העתק מידע לבדיקה\" ושלחו לי.'**
  String get realTestIntro;

  /// No description provided for @realTestSteps.
  ///
  /// In he, this message translates to:
  /// **'1. הזמינו חבר\n2. שניכם: \"אני פנוי עכשיו\"\n3. שניכם: \"דבר עכשיו\"'**
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
  /// **'לא פנוי'**
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
  /// **'העתק מידע לבדיקה'**
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

  /// No description provided for @realSettingsMode.
  ///
  /// In he, this message translates to:
  /// **'מצב האפליקציה'**
  String get realSettingsMode;

  /// No description provided for @realModeReal.
  ///
  /// In he, this message translates to:
  /// **'בדיקה אמיתית עם חברים'**
  String get realModeReal;

  /// No description provided for @realModeDemo.
  ///
  /// In he, this message translates to:
  /// **'הדגמה עם אנשים מדומים'**
  String get realModeDemo;

  /// No description provided for @realSwitchToDemo.
  ///
  /// In he, this message translates to:
  /// **'מעבר להדגמה'**
  String get realSwitchToDemo;

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

  /// No description provided for @realPhotoNone.
  ///
  /// In he, this message translates to:
  /// **'בלי תמונה. לחיצה כדי להוסיף'**
  String get realPhotoNone;

  /// No description provided for @realPhotoSet.
  ///
  /// In he, this message translates to:
  /// **'רק החברים שלך רואים אותה'**
  String get realPhotoSet;

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
  /// **'השרת יודע רק: שם, מי החברים שלך, ואם את/ה פנוי/ה עכשיו (עם תוקף). בלי מיקום, בלי הקלטות.'**
  String get realPrivacyNote;

  /// No description provided for @realVoiceOffer.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}}. לדבר?'**
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
  /// **'DriveTalk · זמין לשיחה בנסיעה'**
  String get realNotifStatusTitle;

  /// No description provided for @realNotifStatusBody.
  ///
  /// In he, this message translates to:
  /// **'נסיעה טובה! נודיע כשחבר פנוי.'**
  String get realNotifStatusBody;

  /// No description provided for @realAutoDriving.
  ///
  /// In he, this message translates to:
  /// **'זמין אוטומטית בנסיעה'**
  String get realAutoDriving;

  /// No description provided for @realAutoDrivingBody.
  ///
  /// In he, this message translates to:
  /// **'כשהטלפון מזהה נסיעה — תהיה זמין לשיחה עד סוף הנסיעה. בלי GPS.'**
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
  /// **'הטלפון מזהה לבד שהוא כנראה ברכב (לפי חיישני התנועה — בלי GPS ובלי מיקום) ומסמן אותך כזמין עד סוף הנסיעה.\n\nכשחבר פנוי — תקבל התראה \"רוצה לדבר?\". שיחה מתחילה רק אם שניכם אומרים כן.\n\nיתבקשו הרשאות \"פעילות גופנית\" והתראות.'**
  String get realAutoDrivingDialogBody;

  /// No description provided for @realAutoDrivingOn.
  ///
  /// In he, this message translates to:
  /// **'מעולה. בנסיעה הבאה תהיה זמין לבד.'**
  String get realAutoDrivingOn;

  /// No description provided for @realAutoDrivingOff.
  ///
  /// In he, this message translates to:
  /// **'זמינות אוטומטית בנסיעה כובתה'**
  String get realAutoDrivingOff;

  /// No description provided for @realAutoDrivingNoPermission.
  ///
  /// In he, this message translates to:
  /// **'בלי הרשאת \"פעילות גופנית\" אי אפשר לזהות נסיעה. אפשר לאשר בהגדרות הטלפון ‹ אפליקציות ‹ DriveTalk ‹ הרשאות.'**
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
  /// **'מתחברים ל{name}. לביטול — בטל.'**
  String realVoiceQuick(String name);

  /// No description provided for @realQuickIn.
  ///
  /// In he, this message translates to:
  /// **'מתחברים ל{name} בעוד {seconds}…'**
  String realQuickIn(String name, int seconds);

  /// No description provided for @realQuickWhy.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר — שניכם במעגל הקרוב אחד של השני'**
  String get realQuickWhy;

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
  /// **'קבוצות פרטיות שרק את/ה רואה. אפשר להיות זמין רק למעגל, ובמעגל \"חיבור מהיר\" מתחברים מיד בלי לשאול.'**
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
  /// **'אם גם הם שמו אותך במעגל מהיר — כששניכם פנויים מתחברים מיד (עם 5 שניות לביטול). עד פעם ביום לכל אדם.'**
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

  /// No description provided for @realAvailableTo.
  ///
  /// In he, this message translates to:
  /// **'זמין ל:'**
  String get realAvailableTo;

  /// No description provided for @realAvailableToAll.
  ///
  /// In he, this message translates to:
  /// **'כל החברים'**
  String get realAvailableToAll;

  /// No description provided for @realPhoneRequired.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון'**
  String get realPhoneRequired;

  /// No description provided for @realPhoneRequiredHelp.
  ///
  /// In he, this message translates to:
  /// **'כדי לדבר בשיחה רגילה. החבר מקבל את המספר רק ברגע ששניכם אמרתם \"כן\".'**
  String get realPhoneRequiredHelp;

  /// No description provided for @realQuickNotif.
  ///
  /// In he, this message translates to:
  /// **'{name} — חיבור מהיר. לחצו כדי להתחבר'**
  String realQuickNotif(String name);

  /// No description provided for @realContactsTitle.
  ///
  /// In he, this message translates to:
  /// **'חברים מאנשי הקשר'**
  String get realContactsTitle;

  /// No description provided for @realContactsBody.
  ///
  /// In he, this message translates to:
  /// **'מי ששמור אצלך ושומר גם אותך — מתחבר אוטומטית. רק מספרים מוצפנים יוצאים מהטלפון, בלי שמות.'**
  String get realContactsBody;

  /// No description provided for @realContactsButton.
  ///
  /// In he, this message translates to:
  /// **'חיפוש באנשי הקשר'**
  String get realContactsButton;

  /// No description provided for @realContactsFound.
  ///
  /// In he, this message translates to:
  /// **'מצאנו: {names} — כבר ברשימה שלך'**
  String realContactsFound(String names);

  /// No description provided for @realContactsNone.
  ///
  /// In he, this message translates to:
  /// **'עוד אין כאן מאנשי הקשר שלך. אפשר להזמין עם קישור.'**
  String get realContactsNone;

  /// No description provided for @realContactsNoPermission.
  ///
  /// In he, this message translates to:
  /// **'בלי הרשאה לאנשי קשר אי אפשר למצוא חברים אוטומטית. אפשר תמיד להזמין עם קישור.'**
  String get realContactsNoPermission;

  /// No description provided for @realNotifManualTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveTalk · זמין לשיחה'**
  String get realNotifManualTitle;

  /// No description provided for @realNotifManualBody.
  ///
  /// In he, this message translates to:
  /// **'נודיע כשחבר פנוי — גם כשהאפליקציה סגורה.'**
  String get realNotifManualBody;

  /// No description provided for @realOfferName.
  ///
  /// In he, this message translates to:
  /// **'{name} {gender, select, female{פנויה} male{פנוי} other{פנוי/ה}} עכשיו'**
  String realOfferName(String name, String gender);

  /// No description provided for @realOfferAsk.
  ///
  /// In he, this message translates to:
  /// **'רוצה לדבר?'**
  String get realOfferAsk;

  /// No description provided for @realOfferAskShort.
  ///
  /// In he, this message translates to:
  /// **'{gender, select, female{פנויה. לדבר?} male{פנוי. לדבר?} other{פנוי/ה. לדבר?}}'**
  String realOfferAskShort(String gender);

  /// No description provided for @realQuickWhyShort.
  ///
  /// In he, this message translates to:
  /// **'חיבור מהיר'**
  String get realQuickWhyShort;

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

  /// No description provided for @realFreeUntil.
  ///
  /// In he, this message translates to:
  /// **'פנוי · {time}'**
  String realFreeUntil(String time);

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
  /// **'כשאתה ומישהו קרוב פנויים באותו רגע — נציע לכם לדבר.'**
  String get realWelcomeSub;

  /// No description provided for @realInviteSimple.
  ///
  /// In he, this message translates to:
  /// **'אני בודק אפליקציה חדשה שמחברת בין חברים כששניהם פנויים לשיחה. בא לך לבדוק אותה איתי?\nלהורדה: {apkUrl}\n(אם אנחנו שמורים זה אצל זה בטלפון — נתחבר לבד)'**
  String realInviteSimple(String apkUrl);

  /// No description provided for @realInviteWithCode.
  ///
  /// In he, this message translates to:
  /// **'הזמנה עם קוד (למי שלא שמור אצלך)'**
  String get realInviteWithCode;

  /// No description provided for @realQuickOff.
  ///
  /// In he, this message translates to:
  /// **'אני פנוי'**
  String get realQuickOff;

  /// No description provided for @realQuickOn.
  ///
  /// In he, this message translates to:
  /// **'פנוי · לעצירה'**
  String get realQuickOn;

  /// No description provided for @realCarTitle.
  ///
  /// In he, this message translates to:
  /// **'הרכב שלי (בלוטות׳)'**
  String get realCarTitle;

  /// No description provided for @realCarBody.
  ///
  /// In he, this message translates to:
  /// **'כשהטלפון מתחבר לרכב — נסיעה מתחילה. מהיר ומדויק יותר מזיהוי התנועה.'**
  String get realCarBody;

  /// No description provided for @realCarNone.
  ///
  /// In he, this message translates to:
  /// **'לא נבחר'**
  String get realCarNone;

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

  /// No description provided for @realReasonNever.
  ///
  /// In he, this message translates to:
  /// **'עוד לא דיברתם כאן'**
  String get realReasonNever;

  /// No description provided for @realReasonDays.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם {count} ימים'**
  String realReasonDays(int count);

  /// No description provided for @realReasonWeeks.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם {count} שבועות'**
  String realReasonWeeks(int count);

  /// No description provided for @realReasonMonths.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם {count} חודשים'**
  String realReasonMonths(int count);

  /// No description provided for @realReasonMonth.
  ///
  /// In he, this message translates to:
  /// **'לא דיברתם כבר חודש'**
  String get realReasonMonth;

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

  /// No description provided for @realWeekNudge.
  ///
  /// In he, this message translates to:
  /// **'לחיצה על \"אני פנוי\" בדרך הבאה — ונמצא לך עם מי'**
  String get realWeekNudge;

  /// No description provided for @realRoutinesIntro.
  ///
  /// In he, this message translates to:
  /// **'בזמנים האלה הטלפון יסמן אותך כזמין לבד — גם כשהאפליקציה סגורה (בערך בזמן, אנדרואיד יכול להזיז בכמה דקות).'**
  String get realRoutinesIntro;

  /// No description provided for @realRoutineNotifTitle.
  ///
  /// In he, this message translates to:
  /// **'DriveTalk · השגרה שלך'**
  String get realRoutineNotifTitle;

  /// No description provided for @realRoutineNotifBody.
  ///
  /// In he, this message translates to:
  /// **'סימנו אותך כזמין לשיחה. \"עצור\" בהתראה כדי לבטל.'**
  String get realRoutineNotifBody;
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
