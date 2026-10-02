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
  /// **'מקבלים הצעה לאדם אחד מתאים — עם הסבר למה.'**
  String get onbHow2;

  /// No description provided for @onbHow3.
  ///
  /// In he, this message translates to:
  /// **'השיחה מתחילה רק אם שני הצדדים אישרו.'**
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
  /// **'אין שיחות אוטומטיות. בנהיגה — רק דיבורית ומתקן לרכב.'**
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

  /// No description provided for @onbAdultCheckbox.
  ///
  /// In he, this message translates to:
  /// **'אני בן/בת 18 ומעלה'**
  String get onbAdultCheckbox;

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
  /// **'{name} {gender, select, female{לא יכולה} male{לא יכול} other{לא יכול/ה}} עכשיו. נחפש מישהו אחר.'**
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
  /// **'כשנזהה שהמכשיר כנראה ברכב, נסמן אותך כזמין. לעולם לא נתחיל שיחה בלי אישור.'**
  String get settingsAutoDrivingBody;

  /// No description provided for @settingsAutoDrivingDialogTitle.
  ///
  /// In he, this message translates to:
  /// **'לפני שמפעילים'**
  String get settingsAutoDrivingDialogTitle;

  /// No description provided for @settingsAutoDrivingDialogBody.
  ///
  /// In he, this message translates to:
  /// **'• זמינות אוטומטית היא לא אישור לשיחה — כל שיחה דורשת אישור של שני הצדדים.\n• הזיהוי נעשה בטלפון בלבד. לא נשלח מיקום.\n• המערכת יודעת רק שהמכשיר כנראה ברכב — לא מי נוהג.\n• באב-הטיפוס, הנסיעה מדומה דרך כלי המפתחים.'**
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
  /// **'מה רואים אחרים: שם, תמונה, שאת/ה זמין/ה ולכמה זמן.'**
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
