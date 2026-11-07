// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabSettings => 'Settings';

  @override
  String get onbNameLabel => 'What\'s your name?';

  @override
  String get homeGreetingNoName => 'Hi';

  @override
  String homeImFreeNow(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'Got a few minutes to talk?',
      'male': 'Got a few minutes to talk?',
      'other': 'Got a few minutes to talk?',
    });
    return '$_temp0';
  }

  @override
  String timeLeftMinutes(int minutes) {
    return '$minutes min left';
  }

  @override
  String get stopAvailability => 'Stop availability';

  @override
  String get modeDriving => 'Driving';

  @override
  String get modeWalking => 'Walking';

  @override
  String get modeBreak => 'Break';

  @override
  String get modeFree => 'Just free time';

  @override
  String get pickDurationTitle => 'For how long?';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get durationUntilTripEnds => 'The whole trip';

  @override
  String durationTripNote(int hours) {
    return 'Stays on up to $hours hours, or until you tap \"Stop\".';
  }

  @override
  String get tierFamiliar => 'Familiar';

  @override
  String get tierReconnect => 'Reconnect';

  @override
  String get tierWiden => 'Widen the circle';

  @override
  String get tierSurprise => 'Surprise me';

  @override
  String get tierFamiliarDesc =>
      'Close friends, family and people you\'re already in touch with';

  @override
  String get tierReconnectDesc =>
      'People you know but haven\'t talked to here in a while';

  @override
  String get tierWidenDesc =>
      'Acquaintances, colleagues and friends of friends';

  @override
  String get tierSurpriseDesc =>
      'A controlled surprise: a friend of a friend or a shared group — always with a reason';

  @override
  String get next => 'Next';

  @override
  String get notToday => 'Not today';

  @override
  String get doNotSuggest => 'Don\'t suggest for a while';

  @override
  String get more => 'More';

  @override
  String get block => 'Block';

  @override
  String get report => 'Report';

  @override
  String get unmatch => 'Remove from list';

  @override
  String get relFamily => 'Family';

  @override
  String get relCloseFriend => 'Close friend';

  @override
  String get relFriend => 'Friend';

  @override
  String get relChildhoodFriend => 'Childhood friend';

  @override
  String get relColleague => 'Colleague';

  @override
  String get relFormerColleague => 'Former colleague';

  @override
  String get relAcquaintance => 'Acquaintance';

  @override
  String get relFriendOfFriend => 'Friend of friends';

  @override
  String get relSharedGroup => 'From a shared group';

  @override
  String get relUnclassified => 'Connection';

  @override
  String get relNone => 'Unclassified';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      two: 'two days',
      one: 'a day',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      two: 'two months',
      one: 'a month',
    );
    return '$_temp0';
  }

  @override
  String get durationYearPlus => 'More than a year';

  @override
  String get listAnd => ' and ';

  @override
  String get cancel => 'Cancel';

  @override
  String noticeBlocked(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is on your blocked list',
      'male': '$name is on your blocked list',
      'other': '$name is on your blocked list',
    });
    return '$_temp0';
  }

  @override
  String get noticeReported => 'Thanks, the report was received';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get skip => 'Skip';

  @override
  String get driverStop => 'Stop';

  @override
  String get driverSafety => 'While driving: hands-free and a phone mount only';

  @override
  String personUnmatchConfirm(String name) {
    return 'Remove $name from your list? You can bring them back any time in \"People I removed\".';
  }

  @override
  String personBlockConfirm(String name) {
    return 'Block $name? You won\'t be suggested to each other and can\'t talk.';
  }

  @override
  String get confirm => 'OK';

  @override
  String reportTitle(String name) {
    return 'Report $name';
  }

  @override
  String get reportInappropriate => 'Inappropriate behavior';

  @override
  String get reportHarassment => 'Harassment';

  @override
  String get reportSpam => 'Spam or impersonation';

  @override
  String get reportUnderage => 'Seems under 18';

  @override
  String get reportOther => 'Other';

  @override
  String get reportAlsoBlock => 'Also block';

  @override
  String get reportSend => 'Send report';

  @override
  String get settingsDriving => 'Driving';

  @override
  String get enable => 'Turn on';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get unblock => 'Unblock';

  @override
  String get featCloseness => 'Closeness';

  @override
  String get featDormancy => 'Time since last talk';

  @override
  String get featAvailableNow => 'Has time now';

  @override
  String get featOverlap => 'Overlapping time';

  @override
  String get featSharedInterests => 'Interests';

  @override
  String get featSharedGroup => 'Shared group';

  @override
  String get featMutualFriends => 'Mutual friends';

  @override
  String get featRecentlySuggested => 'Suggested recently';

  @override
  String get featFeedback => 'Earlier feedback';

  @override
  String routineDue(String mode, int minutes) {
    return 'It\'s your usual time for $mode. Mark yourself free for $minutes min?';
  }

  @override
  String get routineStart => 'Yes';

  @override
  String get availableTo => 'Who\'s right to talk to now?';

  @override
  String get routineAvailableTo => 'Who\'s right to talk to at this time?';

  @override
  String get availableToEveryone => 'As usual';

  @override
  String get driverListening => 'Listening… you can say \"yes\" or \"no\"';

  @override
  String get callWeAreDone => 'We\'re done';

  @override
  String get noticeMicDenied =>
      'No microphone permission — answer with the buttons. You can allow it in phone Settings → Apps → DriveBond → Permissions.';

  @override
  String get photoFromGallery => 'From gallery';

  @override
  String get photoFromCamera => 'Take photo';

  @override
  String get photoRemove => 'Remove';

  @override
  String get settingsVoiceReadout => 'Read aloud while driving';

  @override
  String get settingsVoiceReadoutBody =>
      'The phone says who\'s free, and you answer by voice.';

  @override
  String get routinesTitle => 'My routine';

  @override
  String routinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regular times',
      one: 'One regular time',
      zero: 'No regular times yet',
    );
    return '$_temp0';
  }

  @override
  String get routinesEmpty => 'No regular times yet';

  @override
  String get routineAdd => 'Add a regular time';

  @override
  String get routineDelete => 'Delete routine';

  @override
  String get routineDeleteConfirm => 'Delete this routine?';

  @override
  String get routineDeleteGo => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get daySun => 'Sun';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get realNotConfiguredTitle =>
      'DriveBond isn\'t connected to a server yet';

  @override
  String get realNotConfiguredBody =>
      'This version has no server set up. Please install an updated version.';

  @override
  String get realStarting => 'Connecting…';

  @override
  String get realWelcomeTitle => 'Test with a friend';

  @override
  String get realPhoneLabel => 'Phone number (optional)';

  @override
  String get realPhoneHelp =>
      'Friends who saved your number can find and add you, and the call will be a regular phone call. A friend gets your number only when you both said \"yes\".';

  @override
  String get realJoin => 'Let\'s go';

  @override
  String get realInviteWaitingAfterJoin =>
      'You have an invitation — it opens right after you sign in';

  @override
  String get realTabPeople => 'My people';

  @override
  String get realTabTest => 'Test';

  @override
  String realMeAvailableTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'You\'re free to talk',
      'male': 'You\'re free to talk',
      'other': 'You have time to talk',
    });
    return '$_temp0';
  }

  @override
  String get realFreeFriendsTitle => 'Now';

  @override
  String get realNobodyFree =>
      'No friend is free right now. When someone marks they have time, they\'ll show up here.';

  @override
  String get realFreeHint =>
      'Want to talk to someone who\'s free? Tap them, and we\'ll ask if now works for them.';

  @override
  String get realNobodyFreeYet =>
      'We\'ll let you know as soon as someone right is free.';

  @override
  String get realNoFriendsTitle => 'No friends here yet';

  @override
  String get realNoFriendsBody =>
      'Invite a friend — and when you\'re both free, we\'ll suggest you talk.';

  @override
  String get realInviteFriend => 'Invite a friend';

  @override
  String get realHaveCode => 'I have an invite code';

  @override
  String get realCodeHint => 'Paste the link or code here';

  @override
  String get realCodeInvalid => 'We didn\'t find an invite code in this text';

  @override
  String get realOpen => 'Open';

  @override
  String get realInviteMessage =>
      'Want to talk more without planning ahead? I installed DriveBond. When we\'re both free, it simply suggests we talk.';

  @override
  String realInviteMessageNoSite(String apkUrl, String code) {
    return 'Download: $apkUrl\nThen in the app: My people → Add a friend → I have an invite code → $code';
  }

  @override
  String get realInviteShareSubject => 'Invitation to DriveBond';

  @override
  String get realInviteCopied => 'Invitation copied — paste it in WhatsApp';

  @override
  String realOfferTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is free now. Want to talk?',
      'male': '$name is free now. Want to talk?',
      'other': '$name has time now. Want to talk?',
    });
    return '$_temp0';
  }

  @override
  String get realTalkNow => 'Talk now';

  @override
  String get realNotNow => 'Not now';

  @override
  String get realOfferNote => 'The call starts only if you both say yes';

  @override
  String realWaitingTitle(String name) {
    return 'Waiting for $name…';
  }

  @override
  String realWaitingBody(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'As soon as $name says yes — you\'re connected.',
      'male': 'As soon as $name says yes — you\'re connected.',
      'other': 'As soon as $name answers — you\'re connected.',
    });
    return '$_temp0';
  }

  @override
  String get realStopWaiting => 'Stop waiting';

  @override
  String get realDidNotWorkOut =>
      'Didn\'t work out this time. We\'ll look for another chance.';

  @override
  String get routinesExplain =>
      'Regular times when availability turns on by itself, e.g. the drive to work.';

  @override
  String get realBlockedBody =>
      'People you blocked won\'t be suggested to you, and they won\'t see when you have time.';

  @override
  String get settingsPrivacyBody =>
      'What\'s stored and what isn\'t. You can also delete from the server what was synced from your contacts.';

  @override
  String get realNoAnswer =>
      'No answer right now. We\'ll suggest again another time.';

  @override
  String get realVoiceDidNotWorkOut => 'Didn\'t work out this time.';

  @override
  String realVoiceTheyCall(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is calling you.',
      'male': '$name is calling you.',
      'other': 'A call from $name is coming.',
    });
    return '$_temp0';
  }

  @override
  String realQuickConnecting(String name) {
    return 'Connecting to $name…';
  }

  @override
  String get realQuickConnectingBody => 'Quick connect — you can cancel';

  @override
  String realQuickSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds more seconds — you can cancel',
      one: 'One more second — you can cancel',
    );
    return '$_temp0';
  }

  @override
  String get realQuickCancelled => 'Connection cancelled';

  @override
  String get realQuickTooLate => 'Too late to cancel — the call is starting';

  @override
  String get widgetTip =>
      'You can mark \"I have time\" with one tap, without opening the app: long-press the home screen → Widgets → DriveBond.';

  @override
  String get gotIt => 'Got it';

  @override
  String get realContactsAgain => 'Search contacts again';

  @override
  String get settingsGeneral => 'General';

  @override
  String get adminTitle => 'Admin';

  @override
  String get adminCode => 'Code';

  @override
  String get adminWrong => 'Wrong code';

  @override
  String get adminLock => 'Lock admin';

  @override
  String get updateAvailable => 'A new version of DriveBond is available';

  @override
  String get updateNow => 'Update';

  @override
  String get updateCheck => 'Check for update';

  @override
  String get updateCurrent => 'Your version:';

  @override
  String get updateNone => 'You have the latest version';

  @override
  String get updateHow =>
      'Download, tap the file → \"Update\". Everything is kept.';

  @override
  String get updateHowStore =>
      'Update on Google Play. Your friends and settings are kept.';

  @override
  String get realBgFailedTitle =>
      'We couldn\'t turn on availability in the background';

  @override
  String get realBgFailedBody =>
      'The phone blocked it. Open DriveBond and choose again what you\'re doing now.';

  @override
  String routineHint(String day, String time) {
    return 'Looks like on $day around $time you usually have time. Turn on availability automatically at that time?';
  }

  @override
  String get routineHintYes => 'Turn on';

  @override
  String get routineHintNo => 'No, thanks';

  @override
  String get realStatusServerVersion => 'Server version';

  @override
  String realServerOutdated(int have, int need) {
    return 'The server needs an update: it has $have, $need is needed';
  }

  @override
  String get realClearContacts => 'Delete info synced from contacts';

  @override
  String get realDeleteAccount => 'Delete my account and data';

  @override
  String get realDeleteAccountConfirm =>
      'Everything is deleted from the server: name, number, friends, groups and photo. This can\'t be undone.';

  @override
  String get realDeleteAccountGo => 'Delete';

  @override
  String get realDeleteAccountDone => 'Your account and data were deleted';

  @override
  String get realNotifPublic => 'There\'s a new suggestion in DriveBond';

  @override
  String get firstRunContactsTitle =>
      'Let\'s see who of your people is already here';

  @override
  String get firstRunContactsBody =>
      'Only numbers, encrypted. Names never leave the phone.';

  @override
  String get firstRunContactsGo => 'Search contacts';

  @override
  String firstRunFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'We found $count people from your contacts',
      one: 'We found one person from your contacts',
    );
    return '$_temp0';
  }

  @override
  String get firstRunNoneTitle =>
      'To try DriveBond you need at least one friend';

  @override
  String get firstRunNoneBody =>
      'Send a link to someone you love talking to. After they install, one of you adds the other: My people → Add a friend → Search contacts.';

  @override
  String get firstRunLater => 'Later';

  @override
  String get firstRunMagicTitle => 'Here\'s how it works';

  @override
  String get firstRunMagicBody =>
      'When you\'re both free, DriveBond suggests you talk. No need to plan ahead.';

  @override
  String get firstRunMagicGo => 'Let\'s go';

  @override
  String get routineNameToWork => 'On the way to work';

  @override
  String get routineNameHome => 'On the way home';

  @override
  String get routineNameWalk => 'Evening walk';

  @override
  String get routineNameBreak => 'Lunch break';

  @override
  String get routineEveryone => 'Everyone';

  @override
  String realCallingNow(String name) {
    return 'Calling $name…';
  }

  @override
  String get realDialedBody => 'When the call ends, come back here.';

  @override
  String realTheyCallTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is calling you now',
      'male': '$name is calling you now',
      'other': 'A call from $name is coming now',
    });
    return '$_temp0';
  }

  @override
  String get realTheyCallBody =>
      'Your phone will ring in a moment. If the call doesn\'t come within a minute — \"No call came\".';

  @override
  String get realTheyDidNotCall => 'No call came';

  @override
  String get realNoNumbersTitle => 'Can\'t call this time';

  @override
  String get realNoNumbersBody =>
      'Neither of you has a phone number in the app. To talk, one of you adds a number: Settings → tap your name → \"My number for regular calls\".';

  @override
  String get realDialFailedTitle => 'We couldn\'t open the dialer';

  @override
  String realDialFailedBody(String name) {
    return 'You can call $name yourself.';
  }

  @override
  String get realFeedbackThanks => 'Thanks!';

  @override
  String realConnected(String name) {
    return 'Great! $name is now on your people list.';
  }

  @override
  String realInviteTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name invited you',
      'male': '$name invited you',
      'other': 'An invitation from $name',
    });
    return '$_temp0';
  }

  @override
  String get realInviteBody =>
      'When you\'re both free — we\'ll suggest you talk. Only if you both agree.';

  @override
  String get realInviteAccept => 'Accept';

  @override
  String get realInviteLoading => 'Checking the invitation…';

  @override
  String get realInviteProblemUsed =>
      'This invitation was already used. A new one is needed.';

  @override
  String get realInviteProblemExpired =>
      'The invitation expired. A new one is needed.';

  @override
  String get realInviteProblemOwn =>
      'This is an invitation you sent yourself 🙂 You can send it to a friend.';

  @override
  String get realInviteProblemNotFound =>
      'We couldn\'t find the invitation. Check that the whole link was copied.';

  @override
  String realInviteAlready(String name) {
    return '$name is already on your people list.';
  }

  @override
  String get realErrorOffline =>
      'No internet connection. We\'ll retry by ourselves.';

  @override
  String realErrorGeneric(String code) {
    return 'Something went wrong ($code). You can try again.';
  }

  @override
  String get realErrorAnonymousDisabled =>
      'Sign-in without a password (Anonymous sign-ins) isn\'t enabled on the server yet.';

  @override
  String get realErrorSchema =>
      'The server isn\'t ready yet. You can try again later.';

  @override
  String get realErrorInvalidPhone => 'The phone number doesn\'t look right';

  @override
  String get realErrorInvalidName => 'The name must be 1–40 characters';

  @override
  String get realErrorRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get realErrorTooManyInvites =>
      'There are already many open invitations. Try again tomorrow.';

  @override
  String get realSaved => 'Saved';

  @override
  String get realDialFailed =>
      'We couldn\'t open the dialer. You can call yourself.';

  @override
  String realUnmatched(String name) {
    return '$name was removed';
  }

  @override
  String get realNotFree => 'Not available right now';

  @override
  String get realTestIntro =>
      'Here you can see that everything works. If something doesn\'t — \"Copy info for testing\" and send it to me.';

  @override
  String get realTestSteps =>
      '1. Invite a friend\n2. Both of you: choose what you\'re doing now (e.g. \"Just free time\")\n3. Both of you: \"Talk now\"';

  @override
  String get realStatusServer => 'Server';

  @override
  String get realStatusAccount => 'Account';

  @override
  String get realStatusLive => 'Live updates';

  @override
  String get realStatusFriends => 'Friends';

  @override
  String get realStatusMe => 'My availability';

  @override
  String get realStatusFreeFriends => 'Friends free now';

  @override
  String get realStatusLastOffer => 'Last suggestion';

  @override
  String get realStatusVersion => 'Version';

  @override
  String get realStatusLastError => 'Last error';

  @override
  String get realStatusPhone => 'Number for regular calls';

  @override
  String get realOk => 'OK';

  @override
  String get realNotConnected => 'Not connected';

  @override
  String get realLiveError => 'Unstable — updates every few seconds';

  @override
  String get realNone => 'None';

  @override
  String get realShared => 'Shared';

  @override
  String get realNotShared => 'No number · add';

  @override
  String get realMeNotAvailable => 'Not available';

  @override
  String get realOfferPending => 'Waiting for an answer';

  @override
  String get realOfferAccepted => 'You both said yes';

  @override
  String get realOfferDeclined => 'Didn\'t work out';

  @override
  String get realOfferExpired => 'Time ran out';

  @override
  String get realOfferCancelled => 'Cancelled';

  @override
  String get realCopyDiagnostics => 'Copy info for testing';

  @override
  String get realCopied => 'Copied. You can paste and send it';

  @override
  String get realRefresh => 'Refresh';

  @override
  String get realTestModeToggle => 'Test screen (Test Mode)';

  @override
  String get realTestModeBody =>
      'Shows the \"Test\" tab with the connection status';

  @override
  String get realMyNumber => 'My number for regular calls';

  @override
  String get realStartOver => 'Start over as a new user';

  @override
  String get realStartOverConfirm =>
      'The current user\'s friends and invitations won\'t carry over. Continue?';

  @override
  String get realDownloadLink => 'Link to download the app';

  @override
  String get realShareApp => 'Share';

  @override
  String get realNameTitle => 'My name';

  @override
  String get realPhotoTitle => 'My photo';

  @override
  String get realPhotoSaved => 'Photo saved';

  @override
  String get realPhotoRemoved => 'Photo removed';

  @override
  String get realPrivacyNote =>
      'No location and no recordings. The server keeps only what the app needs: name, number and photo (if you added one), your friends and when you have time. Full details in the privacy policy.';

  @override
  String realVoiceOffer(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is free. Talk?',
      'male': '$name is free. Talk?',
      'other': '$name has time. Talk?',
    });
    return '$_temp0';
  }

  @override
  String realVoiceCalling(String name) {
    return 'Calling $name.';
  }

  @override
  String get realNotifChannelStatus => 'Availability while driving';

  @override
  String get realNotifChannelOffers => 'A friend is free to talk';

  @override
  String get realNotifStatusTitle =>
      'DriveBond · available to talk while driving';

  @override
  String get realNotifStatusBody =>
      'Have a good drive! We\'ll let you know when a friend is free.';

  @override
  String get realAutoDriving => 'Automatic availability while driving';

  @override
  String get realAutoDrivingBody =>
      'When the phone detects it\'s in a vehicle, friends can get a suggestion to talk with you. Turns off by itself at the end of the trip. No GPS and no location.';

  @override
  String get realAutoDrivingUnsupported => 'Not available on this device';

  @override
  String get realAutoDrivingDialogTitle =>
      'Automatic availability while driving';

  @override
  String get realAutoDrivingDialogBody =>
      'The phone detects a trip by itself (no GPS) and marks that you have time until the end of the trip.\n\nA call starts only if you both say yes (or if a friend turned on ⚡ automatic yes).\n\nYou\'ll be asked for \"Physical activity\" and notification permissions.';

  @override
  String get realAutoDrivingOn =>
      'Great. On your next drive, availability turns on by itself.';

  @override
  String get realAutoDrivingOff =>
      'Automatic availability while driving turned off';

  @override
  String get realAutoDrivingNoPermission =>
      '\"Physical activity\" permission is needed: phone Settings → Apps → DriveBond → Permissions.';

  @override
  String get realAutoDrivingFailed =>
      'We couldn\'t turn on trip detection. You can try again.';

  @override
  String get realStatusAutoDriving => 'Trip detection';

  @override
  String get realAutoOn => 'On';

  @override
  String get realAutoOff => 'Off';

  @override
  String get realInVehicleNow => 'In a vehicle now';

  @override
  String get realSimEnter => 'Simulate: got in the car';

  @override
  String get realSimExit => 'Simulate: got out of the car';

  @override
  String realVoiceQuick(String name) {
    return 'Connecting to $name. You can cancel with the button.';
  }

  @override
  String realUnblocked(String name) {
    return '$name was unblocked';
  }

  @override
  String realUnblockedBack(String name) {
    return '$name was unblocked — $name is back on your list';
  }

  @override
  String get realBlockedTitle => 'Blocked';

  @override
  String get realBlockedEmpty => 'You haven\'t blocked anyone';

  @override
  String get realUnblock => 'Unblock';

  @override
  String get realCirclesTitle => 'Groups';

  @override
  String get realCirclesIntro =>
      'A group is a few friends together, e.g. family or work. When you have time, choose \"Available to…\": only certain groups, or everyone except certain groups.';

  @override
  String get circleSeesAll => 'See that you have time: always';

  @override
  String circleSeesSome(String modes) {
    return 'See that you have time: $modes';
  }

  @override
  String get circleSeesNone => 'Hidden from this group that you have time';

  @override
  String get circleRuleQuestion =>
      'When will this group see that you have time?';

  @override
  String get modeInDriving => 'Driving';

  @override
  String get modeInWalking => 'Walking';

  @override
  String get modeInBreak => 'On a break';

  @override
  String get modeInFree => 'Free time';

  @override
  String get realCircleNew => 'New group';

  @override
  String get realCircleName => 'Group name (e.g. Neighbors)';

  @override
  String get realCircleMembers => 'Who\'s in the group';

  @override
  String realCircleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: 'One person',
      zero: 'No people yet',
    );
    return '$_temp0';
  }

  @override
  String get realCircleDelete => 'Delete group';

  @override
  String get realCircleNoFriends => 'Invite friends first';

  @override
  String get circleFamily => 'Family';

  @override
  String get circleFriends => 'Friends';

  @override
  String get circleWork => 'Work';

  @override
  String get whoSeesTitle => 'Who sees that I have time';

  @override
  String get whoSeesSubtitle => 'Groups: who sees, and when';

  @override
  String get whoSeesTwo => 'Someone in two groups sees only if both allow it.';

  @override
  String get whoSeesOthers => 'Everyone else (friends in no group)';

  @override
  String get showAlways => 'Always';

  @override
  String get showNever => 'Never';

  @override
  String get showOnly => 'Only when marked:';

  @override
  String showOnlyModes(String modes) {
    return 'Only: $modes';
  }

  @override
  String get friendCirclesTitle => 'Groups';

  @override
  String get friendCirclesBody =>
      'The group decides whether they see you can talk.';

  @override
  String get hiddenUnhide => 'Stop hiding';

  @override
  String get homeWhatNow =>
      'Choose what you\'re doing now, and we\'ll find a friend who\'s also free to talk';

  @override
  String get permIntroTitle => 'One moment';

  @override
  String get permIntroBody =>
      'So the call starts right when you both say \"yes\", and so we can let you know when a friend is free, the phone will ask a few questions:\n\n• Phone calls — to dial with one tap.\n• Notifications — to let you know even when the app is closed.\n• Microphone (while driving) — to answer \"yes\" or \"no\" by voice. Nothing is recorded.';

  @override
  String get permIntroGo => 'Got it, continue';

  @override
  String get realPhoneRequired => 'Phone number';

  @override
  String get realPhoneRequiredHelp =>
      'Your number is needed so friends who saved it can find you, and so the call is a regular phone call. A friend gets your number only when you both said \"yes\".';

  @override
  String get realContactsTitle => 'Friends from your contacts';

  @override
  String get realContactsBody =>
      'Find which of your contacts are already here, and choose who to add. Your number isn\'t needed.';

  @override
  String get realContactsButton => 'Search contacts';

  @override
  String realContactsFound(String names) {
    return '$names — now on your list';
  }

  @override
  String get realContactsNone =>
      'None of your contacts are here yet. You can invite with a link.';

  @override
  String get realContactsNoPermission =>
      'No contacts permission — you can invite with a link.';

  @override
  String get realNotifManualTitle => 'DriveBond · available to talk';

  @override
  String get realNotifManualBody =>
      'We\'ll let you know when a friend is free — even when the app is closed.';

  @override
  String realOfferName(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name is free now',
      'male': '$name is free now',
      'other': '$name has time now',
    });
    return '$_temp0';
  }

  @override
  String get realOfferAsk => 'Want to talk?';

  @override
  String realOfferAskShort(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'Free. Talk?',
      'male': 'Free. Talk?',
      'other': 'Has time. Talk?',
    });
    return '$_temp0';
  }

  @override
  String get realGreetMorning => 'Good morning';

  @override
  String get realGreetNoon => 'Good afternoon';

  @override
  String get realGreetEvening => 'Good evening';

  @override
  String get realGreetNight => 'Good night';

  @override
  String realHomeTitle(String name) {
    return '$name, who are\nwe talking to today?';
  }

  @override
  String realFreeCount(int count) {
    return 'Have time: $count';
  }

  @override
  String get realGroupAccount => 'My account';

  @override
  String get realWelcomeHeadline => 'Time on the road —\nwith your people.';

  @override
  String get realWelcomeSub =>
      'When you\'re both free at the same moment — we\'ll suggest you talk.';

  @override
  String realInviteSimple(String apkUrl, String guideUrl) {
    return 'Want to talk more without planning ahead? I installed DriveBond — when we\'re both free, it suggests we talk.\nDownload: $apkUrl\nInstall help: $guideUrl';
  }

  @override
  String get realQuickOff => 'I have time';

  @override
  String get realQuickOn => 'I have time · tap to stop';

  @override
  String get realCarTitle => 'My cars (Bluetooth)';

  @override
  String get realCarBody =>
      'When the phone connects to the car\'s Bluetooth, it\'s a sign the trip started. Helps detect a trip faster.';

  @override
  String get realCarPick => 'Choose cars';

  @override
  String get realCarNoDevices =>
      'No connected Bluetooth devices found. Connect the phone to the car once and try again.';

  @override
  String get realWeekTitle => 'Your week';

  @override
  String realWeekTalks(int talks) {
    String _temp0 = intl.Intl.pluralLogic(
      talks,
      locale: localeName,
      other: '$talks talks',
      one: 'One talk',
      zero: 'No talks this week yet',
    );
    return '$_temp0';
  }

  @override
  String realWeekFriends(int friends) {
    String _temp0 = intl.Intl.pluralLogic(
      friends,
      locale: localeName,
      other: 'with $friends friends',
      one: 'with one friend',
    );
    return '$_temp0';
  }

  @override
  String get realRoutinesIntro =>
      'At these times availability turns on by itself, even when the app is closed.';

  @override
  String get realRoutineNotifTitle => 'DriveBond · your routine';

  @override
  String get realRoutineNotifBody =>
      'Availability to talk is on. \"Stop\" in the notification cancels it.';

  @override
  String get done => 'Done';

  @override
  String get ratingNever => 'Don\'t suggest';

  @override
  String ratingLabel(int rating) {
    return 'Rated $rating of 5';
  }

  @override
  String get ratingTitle => 'How much do I want to talk?';

  @override
  String get ratingHelp =>
      '0 = never suggest · 5 = most important. Only you see this.';

  @override
  String get contactsPickTitle => 'Your contacts already here';

  @override
  String get contactsPickBody =>
      'Pick only who you\'d like to talk to. Anyone you don\'t pick won\'t know.';

  @override
  String get contactsAdd => 'Add';

  @override
  String get contactsNo => 'No';

  @override
  String newContactTitle(String name) {
    return '$name from your contacts is already here';
  }

  @override
  String get newContactBody => 'Add to my people?';

  @override
  String get hiddenNote =>
      'Your status is hidden, so you also don\'t see who\'s free here. Suggestions to talk continue.';

  @override
  String get realLaterButton => 'Not now, but I\'d love to later';

  @override
  String realLaterNote(String name) {
    return 'From $name: now isn\'t good, maybe later.';
  }

  @override
  String get backgroundTitle => 'Don\'t miss a single call';

  @override
  String get backgroundBody =>
      'This way we can let you know the moment a friend is free, and detect a trip, even when the app is closed. In the background it works only when you marked you have time or during a trip.';

  @override
  String get backgroundAllow => 'Turn on';

  @override
  String get addNumberTitle => 'So friends can find you';

  @override
  String get addNumberBody =>
      'Without a phone number friends won\'t find you in their contacts, and you can\'t be called with a regular call. Your number goes to a friend only after you both said \"yes\".';

  @override
  String get addNumberGo => 'Add number';

  @override
  String newFriendTitle(String name) {
    return 'New on your list: $name';
  }

  @override
  String get newFriendBody =>
      'You\'re connected — from contacts or an invitation. From now on you can get a suggestion to talk when you\'re both free.';

  @override
  String get newFriendGroup => 'Choose a group';

  @override
  String get newFriendOk => 'Great';

  @override
  String get notNowShort => 'Not now';

  @override
  String get firstRunRoutineTitle => 'When do you usually drive?';

  @override
  String get firstRunRoutineBody =>
      'Mark one time or more. Sun–Thu at that time we\'ll mark that you have time — for half an hour. Change the time with the pencil, and you can change everything in Settings → My routine.';

  @override
  String firstRunRoutineMorning(String time) {
    return 'Morning · $time · on the way to work';
  }

  @override
  String firstRunRoutineEvening(String time) {
    return 'Evening · $time · on the way home';
  }

  @override
  String get firstRunRoutineNone => 'Not regular';

  @override
  String get statsTitle => 'Numbers';

  @override
  String get statsFailed =>
      'Couldn\'t load. If this repeats, enter the admin code again (long-press \"Check for update\").';

  @override
  String get statsWeek => '7 days';

  @override
  String get statsMonth => '30 days';

  @override
  String get statsUsers => 'People in the app';

  @override
  String get statsNewUsers => 'Joined';

  @override
  String get statsActiveUsers => 'Opened the app';

  @override
  String get statsFriendships => 'Friendships';

  @override
  String get statsFreeTimes => '\"I have time\"';

  @override
  String get statsOffers => 'Suggestions to talk';

  @override
  String get statsQuick => 'Quick connects';

  @override
  String get statsBothYes => 'Both said yes';

  @override
  String get statsTalked => 'Actually talked';

  @override
  String get statsDeclined => '\"Not now\"';

  @override
  String get statsLater => '\"I\'ll get back to you\"';

  @override
  String get statsNoAnswer => 'No answer';

  @override
  String get statsDialMs => 'How fast dialing starts';

  @override
  String get statsSeconds => 'sec';

  @override
  String get statsNote =>
      'Totals per person (phone number). Names appear only in the feedback, report and crash lists, and only for you.';

  @override
  String get statsReports => 'Reports';

  @override
  String realInviteStore(String url) {
    return 'Want to talk more without planning ahead? I installed DriveBond — when we\'re both free, it suggests we talk.\nGet it on Google Play: $url';
  }

  @override
  String inactiveDays(int days) {
    return 'Not opened for $days days';
  }

  @override
  String get inactiveMonth => 'Not opened for over a month';

  @override
  String get feedbackTitle => 'Send feedback';

  @override
  String get feedbackBody =>
      'Something not working? An idea? It comes straight to us.';

  @override
  String get feedbackHint => 'What should we improve?';

  @override
  String get feedbackSend => 'Send';

  @override
  String get statsFeedback => 'Feedback';

  @override
  String get statsReportsTitle => 'Recent reports';

  @override
  String get statsFeedbackTitle => 'Recent feedback';

  @override
  String get statsNotesEmpty => 'Nothing here yet';

  @override
  String get statsNotesFailed =>
      'No access. Enter the admin code again: Settings → long-press \"Check for update\".';

  @override
  String get firstRunRoutineChangeTime => 'Change time';

  @override
  String get inCall => 'In a call';

  @override
  String get close => 'Close';

  @override
  String get firstRunPhotoTitle => 'A photo, so people recognize you';

  @override
  String get firstRunPhotoBody => 'Optional. Only your friends see it.';

  @override
  String get firstRunPhotoGo => 'Choose a photo';

  @override
  String get firstRunPhotoLater =>
      'You can add or change it any time: Settings → tap your name → \"My photo\".';

  @override
  String peopleAsleepTitle(int count) {
    return 'Haven\'t opened the app in a month ($count)';
  }

  @override
  String get peopleAsleepBody =>
      'They come back to the list by themselves when they open it again.';

  @override
  String get removedTitle => 'People I removed';

  @override
  String get removedBody =>
      'You can bring them back — and you\'re friends again right away.';

  @override
  String get removedEmpty => 'You haven\'t removed anyone.';

  @override
  String get removedRestore => 'Bring back';

  @override
  String get statsUsersHint =>
      'People with a phone number. Several installs or accounts with the same number = one person';

  @override
  String get statsNewUsersHint =>
      'Phone numbers seen for the first time in this period';

  @override
  String get statsActiveUsersHint =>
      'People (by number) who opened the app at least once in the period';

  @override
  String get statsFriendshipsHint =>
      'Pairs of two different people who are connected and approved (no duplicates)';

  @override
  String get statsFreeTimesHint =>
      'How many times someone marked they\'re free';

  @override
  String get statsOffersHint =>
      'How many times we suggested two free friends talk';

  @override
  String get statsQuickHint =>
      'Calls that started without asking (both sides agreed ahead)';

  @override
  String get statsBothYesHint => 'Suggestions that became a call';

  @override
  String get statsTalkedHint => 'Based on what they answered after the call';

  @override
  String get statsDeclinedHint => 'One side declined the suggestion';

  @override
  String get statsLaterHint => 'Out of the \"Not now\" answers';

  @override
  String get statsNoAnswerHint => 'Nobody answered in time';

  @override
  String get statsReportsHint => 'Reports about users. Tap for details';

  @override
  String get statsFeedbackHint =>
      'Messages sent to you from the app. Tap for details';

  @override
  String get statsCrashes => 'Crashes';

  @override
  String get statsCrashesHint =>
      'Errors the app reported by itself. Tap for details';

  @override
  String get statsDialMsHint =>
      'From the second \"yes\" until the phone dials (typically)';

  @override
  String get statsCrashesTitle => 'Recent crashes';

  @override
  String askTitle(String name) {
    return 'Talk with $name now?';
  }

  @override
  String get askBody => 'We\'ll ask if now works. If yes, you start talking.';

  @override
  String get askBodyNotFree =>
      'We\'ll mark that you have time too (30 minutes), and ask if now works.';

  @override
  String get askYes => 'Yes, ask';

  @override
  String askNotFree(String name) {
    return 'Looks like $name doesn\'t have time anymore.';
  }

  @override
  String askBusy(String name) {
    return 'Now isn\'t good for $name. We\'ll suggest when it is.';
  }

  @override
  String askNotNow(String name) {
    return 'We already asked $name this time. We\'ll wait for next time.';
  }

  @override
  String askCallOpen(String name) {
    return 'Your last call with $name isn\'t closed yet. As soon as one of you answers \"How was it?\" or the call disconnects, you can reach out again.';
  }

  @override
  String get askNoNumber =>
      'Can\'t call: neither of you has a phone number in the app.';

  @override
  String get askMeNotFree => 'First mark that you have time.';

  @override
  String get askFailed => 'We couldn\'t ask right now. You can try again.';

  @override
  String friendKept(String name) {
    return '$name is on your list';
  }

  @override
  String hiddenFreeLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more friends free, without a name',
      one: 'and one more friend free, without a name',
    );
    return '$_temp0';
  }

  @override
  String get anonymousSeeNote =>
      'You chose to appear without a name, so here too you only see how many are free.';

  @override
  String get missedTitle => 'You didn\'t answer, so we stopped suggesting you.';

  @override
  String get missedBody =>
      'Meanwhile friends don\'t see that you have time. Do you still have time?';

  @override
  String get missedYes => 'Yes, I have time';

  @override
  String get missedNo => 'Not now';

  @override
  String get autoMissedTitle => 'You didn\'t answer on your last trips.';

  @override
  String get autoMissedBody => 'Keep automatic trip detection?';

  @override
  String get autoMissedKeep => 'Keep';

  @override
  String get autoMissedOff => 'Turn off';

  @override
  String get graceTitle => 'A few minutes to settle in';

  @override
  String get graceBody => 'Then we\'ll suggest a call, if someone\'s free.';

  @override
  String get graceReady => 'I\'m ready now';

  @override
  String get graceNotThisTrip => 'Not this trip';

  @override
  String get extendButton => 'Extend';

  @override
  String get extendTitle => 'Extend by…';

  @override
  String extendBy(int minutes) {
    return '+$minutes min';
  }

  @override
  String get durationUntilTime => 'Until…';

  @override
  String durationUntilTimeCapped(String time) {
    return 'Up to 3 hours is possible, so we set it until $time.';
  }

  @override
  String pendingTitle(String name) {
    return 'You joined $name\'s list';
  }

  @override
  String pendingBody(String name) {
    return '$name added you and can\'t see yet when you have time. Know them? Keep them on the list?';
  }

  @override
  String get pendingKeep => 'Keep';

  @override
  String get pendingRemove => 'Remove';

  @override
  String weeklyNotifTitle(String people, String talks) {
    return 'This week you talked with $people friends in $talks calls 🔥';
  }

  @override
  String get weeklyNotifBody => 'What a week. Who\'s next?';

  @override
  String get weekShare => 'Share';

  @override
  String weekShareText(int people) {
    return 'This week I talked with $people friends while driving, with DriveBond 🚗🔥';
  }

  @override
  String get driveInviteTitle => 'Who would you love to hear from in traffic?';

  @override
  String get driveInviteBody =>
      'On your last drive no friend was free. Invite a friend or two, and next time there\'ll be someone to talk to.';

  @override
  String get driveInviteButton => 'Invite a friend';

  @override
  String offerShared(int minutes) {
    return 'You\'re both free for about $minutes more min';
  }

  @override
  String get offerLastTalkToday => 'You already talked today';

  @override
  String offerLastTalkDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'You talked $days days ago',
      one: 'You talked yesterday',
    );
    return '$_temp0';
  }

  @override
  String offerLastTalkDate(String date) {
    return 'You haven\'t talked since $date';
  }

  @override
  String get offerFirstTalk => 'This will be your first talk here';

  @override
  String get waitOther => 'Talk with someone else';

  @override
  String get settingsAnonymous => 'Appear without my name when I have time';

  @override
  String get settingsAnonymousHint =>
      'Friends see only how many are free, not who.';

  @override
  String get settingsHideInCall => 'Hide when I\'m in a call';

  @override
  String get settingsHideInCallHint =>
      'During a call, friends won\'t see that you\'re available.';

  @override
  String get settingsQuietHours => 'Quiet hours';

  @override
  String get settingsQuietOff =>
      'No quiet hours. On an automatically detected trip, you can get suggestions at any hour.';

  @override
  String settingsQuietOn(String from, String to) {
    return 'Between $from and $to, on an automatically detected trip we won\'t mark you free.';
  }

  @override
  String get quietPickFrom => 'From what time?';

  @override
  String get quietPickTo => 'Until what time?';

  @override
  String get quietClear => 'Remove quiet hours';

  @override
  String get quietSet => 'Choose hours';

  @override
  String get realNotifChannelTalk => 'Suggestions to talk';

  @override
  String get driverFreeTitle => 'Who\'s free now';

  @override
  String get driverFreeHint => 'Tap a friend, and we\'ll ask them.';

  @override
  String get driverNobody => 'No friend is free yet';

  @override
  String get driverNobodyBody =>
      'When someone\'s free, we\'ll suggest you talk.';

  @override
  String get driverNormalView => 'Regular screen';

  @override
  String get driverBack => 'Back to the driving screen';

  @override
  String get freeNotNow => 'Not right now';

  @override
  String freeNotNowTitle(String name) {
    return 'Can\'t reach $name right now';
  }

  @override
  String get freeNotNowBody =>
      'A call can\'t be suggested right now (e.g. at the start of a trip, or when you already asked this time). When it\'s possible, it\'ll show as usual.';

  @override
  String freeNotNowMine(String name) {
    return 'That\'s because you haven\'t approved $name on your list yet. Once you do, you can talk right away.';
  }

  @override
  String afterCallTitle(String name) {
    return 'When should we suggest $name again?';
  }

  @override
  String afterCallNote(String name) {
    return 'Meanwhile you can always tap $name and ask yourself.';
  }

  @override
  String get afterCallAny => 'Any time';

  @override
  String get afterCallTomorrow => 'Tomorrow';

  @override
  String get afterCall3 => 'In 3 days';

  @override
  String get afterCallWeek => 'In a week';

  @override
  String get afterCallNoTalk => 'We didn\'t manage to talk';

  @override
  String directTitle(String name) {
    return '$name wants to talk with you';
  }

  @override
  String get directAsk => 'Does now work for you?';

  @override
  String get directAskShort => 'Wants to talk with you. Answer?';

  @override
  String voiceDirect(String name) {
    return '$name wants to talk with you. Answer?';
  }

  @override
  String get callToMain => 'To the main screen';

  @override
  String callBackToCall(String name) {
    return 'In a call with $name · back to the call screen';
  }

  @override
  String bgVoiceOffer(String name) {
    return '$name has time to talk. If it works — \"Talk\" in the notification.';
  }

  @override
  String bgVoiceDirect(String name) {
    return '$name wants to talk with you. If it works — \"Talk\" in the notification.';
  }

  @override
  String get notifPublicTalk => 'Someone is free to talk now';

  @override
  String answeredTheyCall(String name) {
    return 'A call from $name is on its way. Your phone will ring.';
  }

  @override
  String answeredYouCall(String name) {
    return '$name wants to talk too. Tap here — and call.';
  }

  @override
  String answeredWaiting(String name) {
    return 'Waiting for an answer from $name.';
  }

  @override
  String get answeredMissed =>
      'Didn\'t work out this time. We\'ll suggest again another time.';

  @override
  String voiceYouCall(String name) {
    return '$name wants to talk too. Tap the notification — and call.';
  }

  @override
  String get permsTitle => 'So it works while driving too';

  @override
  String get permsBody =>
      'A few approvals from the phone, once now, so no questions pop up in the middle of a drive.';

  @override
  String get permsAllowAll => 'Allow all';

  @override
  String get permsAllowOne => 'Allow';

  @override
  String get permsDone => 'Allowed';

  @override
  String get permsNotifTitle => 'Notifications';

  @override
  String get permsNotifBody =>
      'To know when a friend is free, even when the app is closed.';

  @override
  String get permsCallTitle => 'Phone calls';

  @override
  String get permsCallBody =>
      'So the call goes out right when you both say yes.';

  @override
  String get permsMicTitle => 'Microphone';

  @override
  String get permsMicBody =>
      'To answer \"yes\" or \"no\" by voice while driving. Nothing is recorded.';

  @override
  String get permsBgTitle => 'Background work';

  @override
  String get permsBgBody =>
      'So battery saving doesn\'t stop notifications in the middle of a drive.';

  @override
  String get permsAutoTitle =>
      'Automatic availability while driving (optional)';

  @override
  String get permsAutoBody =>
      'When the phone is in a vehicle, we\'ll mark that you have time. No GPS. You can turn it off any time.';

  @override
  String get permsSettings => 'Permissions';

  @override
  String get permsSettingsBody =>
      'Notifications, calls, microphone, background work';

  @override
  String get answeredRetry =>
      'We couldn\'t answer from here. Tap here — and answer in the app.';

  @override
  String get quickTitle => 'Quick connect';

  @override
  String get quickOffBody =>
      'When you\'re both free, the call goes out by itself. 5 seconds to cancel.';

  @override
  String quickWaitingBody(String name) {
    return 'On for you. It\'ll work once $name turns it on too.';
  }

  @override
  String get quickBothBody =>
      'On for both of you. When you\'re both free, the call goes out by itself.';

  @override
  String quickConfirmTitle(String name) {
    return 'Quick connect with $name?';
  }

  @override
  String quickConfirmBody(String name) {
    return 'When you\'re both free, the call goes out by itself, without asking. There are 5 seconds to cancel: if either of you cancels, the call doesn\'t go out.\n\n$name\'s app will show a suggestion to turn it on too.';
  }

  @override
  String get quickTurnOn => 'Turn on';

  @override
  String quickAskTitle(String name) {
    return '$name wants quick connect with you';
  }

  @override
  String get quickAskBody =>
      'When you\'re both free, the call will go out by itself, without asking. You both have 5 seconds to cancel.';

  @override
  String get quickAskYes => 'Turn on too';

  @override
  String get quickIntroTitle => 'New: quick connect';

  @override
  String get quickIntroBody =>
      'For your closest friends: when you\'re both free, the call goes out by itself, without asking. 5 seconds to cancel.';

  @override
  String get quickIntroPick => 'Choose friends';

  @override
  String get quickPickTitle => 'Quick connect with…';

  @override
  String quickTheyWantBody(String name) {
    return '$name already has quick connect with you on. Turn it on too?';
  }

  @override
  String get quickTheyWantChip => 'Wants quick connect';

  @override
  String pauseTitle(String when) {
    return 'Suggestions paused $when';
  }

  @override
  String pauseBody(String name) {
    return 'You can always tap $name and ask yourself.';
  }

  @override
  String get pauseQuickNote => 'Quick connect works during the pause too.';

  @override
  String get pauseCancel => 'Cancel';

  @override
  String pauseChip(String when) {
    return 'Paused $when';
  }

  @override
  String pauseUntilTime(String time) {
    return 'until $time';
  }

  @override
  String get pauseUntilTomorrow => 'until tomorrow';

  @override
  String pauseUntilDay(String day) {
    return 'until $day';
  }

  @override
  String pauseUntilDate(String date) {
    return 'until $date';
  }

  @override
  String get settingsPrivacyInfo => 'What\'s stored about me';

  @override
  String get permsPhoneNotif => 'Phone notification settings';

  @override
  String get realCirclesNone =>
      'Family, work, close friends: who sees that you have time';

  @override
  String get routineAskTitle => 'Your routine: do you have time now?';

  @override
  String routineAskBody(String minutes) {
    return 'Tap \"Yes\" and we\'ll mark that you have time for $minutes min.';
  }

  @override
  String get routineAskYes => 'Yes, I have time';

  @override
  String get othersRuleTitle =>
      'Friends in no group: when will they see that you have time?';

  @override
  String get pasteCode => 'Paste';

  @override
  String get realCallEnded => 'The call ended';

  @override
  String get realTapOrWait => 'Tap a free friend, or wait for us to suggest.';

  @override
  String driverMyTimeLeft(int minutes) {
    return 'Your free time: $minutes min left';
  }

  @override
  String durationTripNoteDetected(int hours) {
    return 'Ends by itself when the trip ends (and at most after $hours hours).';
  }

  @override
  String get afterCallHope => 'We hope it was a good talk 🙂';

  @override
  String get afterCallWrite =>
      'Feedback or an insight? Write to us, and we\'ll improve';

  @override
  String realWaitingLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds more seconds',
      one: 'one more second',
    );
    return '$_temp0';
  }

  @override
  String get addFriend => 'Add a friend';

  @override
  String get addFriendInviteBody => 'Send a link on WhatsApp or by message';

  @override
  String get addFriendCodeBody =>
      'Got an invitation without a link? Enter the code here';

  @override
  String get addFriendContactsBody =>
      'See which of your contacts are already here, and choose';

  @override
  String get tripNotifChannel => 'Friends heading out';

  @override
  String tripNotifTitle(String name) {
    return '$name is on the way';
  }

  @override
  String get tripNotifBody => 'Has time to talk now';

  @override
  String get tripNotifTalk => 'Talk';

  @override
  String get settingsTripNotify => 'Let friends know when I head out';

  @override
  String get settingsTripNotifyBody =>
      'To friends who turned on ⚡ automatic yes for you. At most once a day.';

  @override
  String get pushTestButton => 'Send me a test notification';

  @override
  String get pushTestSent =>
      'A test notification was sent. It should appear in a few seconds.';

  @override
  String get pushTestNoAppPush =>
      'This version of the app has no notifications yet (Firebase settings are missing in GitHub).';

  @override
  String get pushTestNoFunction =>
      'The notifications function (smooth-responder) wasn\'t found in Supabase.';

  @override
  String get pushTestNotConfigured =>
      'The function is missing the FCM_SERVICE_ACCOUNT secret in Supabase.';

  @override
  String get pushTestNoServer =>
      'The server hasn\'t been updated to part 12 (version 44) yet.';

  @override
  String get pushTestNotAllowed =>
      'The function requires verification: turn off Enforce JWT Verification on it.';

  @override
  String pushTestFailed(String code) {
    return 'Sending failed ($code).';
  }

  @override
  String get pushTestTitle => 'Test: notifications work ✓';

  @override
  String get pushTestNoToken =>
      'This phone\'s address wasn\'t found on the server (no_token).';

  @override
  String get notifChannelNews => 'Updates from DriveBond';

  @override
  String get ownerNotifFeedback => 'New feedback received';

  @override
  String get ownerNotifCrash => 'The app crashed for someone';

  @override
  String ownerNotifUser(String name) {
    return 'New user: $name';
  }

  @override
  String get versionNotifTitle => 'A new version of DriveBond is out';

  @override
  String get versionNotifBody => 'Tap to update on Google Play';

  @override
  String friendsSeeMeFree(String mode, String left) {
    return 'Friends see: free · $mode · $left';
  }

  @override
  String get friendsSeeMeInCall =>
      'Friends see: in a call. No questions will come meanwhile.';

  @override
  String get friendsSeeMeHidden =>
      'In a call: friends don\'t see that you have time (hidden in calls).';

  @override
  String missedNotifTitle(String name, String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': '$name tried to reach you',
      'male': '$name tried to reach you',
      'other': 'You missed a call with $name',
    });
    return '$_temp0';
  }

  @override
  String get missedNotifBody =>
      'The question closed before you answered. You can call when it suits you.';

  @override
  String get quietPickDays => 'On which days?';

  @override
  String get quietDaysSave => 'Save';

  @override
  String get quietDayLetters => 'S,M,T,W,T,F,S';

  @override
  String settingsQuietOnDays(String days, String from, String to) {
    return 'On $days, between $from and $to, on an automatically detected trip we won\'t mark you free.';
  }

  @override
  String get aboutTitle => 'About DriveBond';

  @override
  String get aboutSettingsBody =>
      'What\'s special about the app, which permissions you allowed and why they\'re needed';

  @override
  String get aboutHero =>
      'The dead time of the day — driving, in traffic or walking — becomes a good talk with someone who matters to you.';

  @override
  String get aboutSpecialTitle => 'What\'s special here';

  @override
  String get aboutSpecial1Title => 'A dead moment becomes a talk';

  @override
  String get aboutSpecial1Body =>
      'When you both have time at the same moment, the app connects you. No planning ahead and no \"let\'s talk sometime\".';

  @override
  String get aboutSpecial2Title => 'A call only when you both want it';

  @override
  String get aboutSpecial2Body =>
      'No call starts without a \"yes\" from both sides. Even when a trip is detected, it only means there\'s time, not that someone will call.';

  @override
  String get aboutSpecial3Title => 'While driving: by voice, with big buttons';

  @override
  String get aboutSpecial3Body =>
      'The phone reads out who\'s free, and you answer \"yes\" or \"no\" by voice. No typing and no lists to scroll.';

  @override
  String get aboutSpecial4Title => 'You\'re in control';

  @override
  String get aboutSpecial4Body =>
      'Who sees that you have time, quiet hours and days, hiding during calls, and blocking. All in settings.';

  @override
  String get aboutSpecial5Title => 'No feed and no strangers';

  @override
  String get aboutSpecial5Body =>
      'No infinite scroll and no random chat. Only talks with people you chose.';

  @override
  String get aboutPermsTitle => 'Phone permissions';

  @override
  String get aboutPermsIntro =>
      'What you allowed and why it\'s needed. Each permission is used only for what\'s written here.';

  @override
  String get aboutPermOn => 'Allowed';

  @override
  String get aboutPermOff => 'Not allowed';

  @override
  String get aboutPermOptional => 'Optional';

  @override
  String get aboutPermInUse => 'In use';

  @override
  String get aboutPermNotifBody =>
      'So you know when a friend is free, when someone asks if you have time, or when someone tried to reach you, even when the app is closed.';

  @override
  String get aboutPermCallBody =>
      'When you both say \"yes\", the call goes out right away through the phone\'s regular dialer, with no extra tap. The app doesn\'t read the call log.';

  @override
  String get aboutPermMicBody =>
      'Only when the app asks and waits for \"yes\" or \"no\" while driving. When the phone is connected to the car\'s hands-free, the car\'s microphone is used (music may pause for a second). Listening happens on the phone itself, and nothing is recorded or stored.';

  @override
  String get aboutPermBgBody =>
      'The phone\'s battery saving may stop the app in the middle of a drive. The exemption lets it keep working and notify you in time.\nThe app works in the background only during a trip, or when you marked you have time — not all day. The rest of the time it\'s off, and Android wakes it only when the phone is in a vehicle.\nBattery use is very small: no GPS, just a short check with the server, usually once every half minute.';

  @override
  String get aboutPermContactsTitle => 'Contacts';

  @override
  String get aboutPermContactsBody =>
      'To find friends who already use DriveBond. Only phone numbers are read, and they are one-way encrypted on the phone itself. Names never leave the phone, and nobody connects to you unless you choose.';

  @override
  String get aboutPermActivityTitle => 'Physical activity (trip detection)';

  @override
  String get aboutPermActivityBody =>
      'Only if \"Automatic availability while driving\" is on (it\'s on at sign-up, and you can turn it off any time). Android tells the app \"the phone is probably in a vehicle\", with no GPS and no location.';

  @override
  String get aboutPermBtTitle => 'Bluetooth (the car)';

  @override
  String get aboutPermBtBody =>
      'Optional: if you chose your car, the app notices when the phone connects to it, and so detects a trip faster. This stays on the phone.';

  @override
  String get aboutPrivacyTitle => 'What we never do';

  @override
  String get aboutNever1 =>
      'We don\'t record calls, don\'t transcribe, and there\'s no AI on anything said.';

  @override
  String get aboutNever2 => 'We don\'t read the call log.';

  @override
  String get aboutNever3 =>
      'We don\'t use GPS. Location, route and speed are never sent to anyone.';

  @override
  String get aboutNever4 =>
      'Friends see only whether you have time, in what mode (e.g. driving), and until when.';

  @override
  String get aboutNever5 =>
      'We never say you\'re the driver, only that \"the phone is probably in a vehicle\".';

  @override
  String get aboutFeedbackTitle => 'Help us improve';

  @override
  String get aboutFeedbackBody =>
      'The app is still in testing. Every note helps: what you liked, what confused you, and what didn\'t work.';

  @override
  String get meInRow => 'Me';

  @override
  String get quietEveryDay => 'Every day';

  @override
  String quietRangeLine(String days, String from, String to) {
    return '$days: $from–$to';
  }

  @override
  String get quietScreenBody =>
      'During these hours, on an automatically detected trip we won\'t mark you free. You can have several schedules, e.g. Sunday–Thursday at night and other hours on Friday and Saturday.';

  @override
  String get quietAdd => 'Add quiet hours';

  @override
  String get quietNone => 'No quiet hours yet.';

  @override
  String get quietDelete => 'Delete';

  @override
  String quietMany(String count, String lines) {
    return '$count schedules: $lines';
  }

  @override
  String waitingSent(String name) {
    return '✓ Sent to $name';
  }

  @override
  String waitingReached(String name) {
    return '✓✓ Reached $name\'s phone';
  }

  @override
  String get permsFullTitle => 'Full-screen question while driving';

  @override
  String get permsFullBody =>
      'To answer \"yes\" by voice even when the screen is locked.';

  @override
  String get aboutPermFullBody =>
      'While driving, when a friend asks if you have time, the app opens like an incoming call, even on a locked screen, and asks out loud. That way you can answer \"yes\" or \"no\" without touching the phone. When the screen is in use (e.g. navigation), only a notification appears at the top.';

  @override
  String get whyTitle => 'Why doesn\'t someone show up?';

  @override
  String get whyHint => 'Their phone number';

  @override
  String get whyCheck => 'Check';

  @override
  String get whyBadNumber => 'That doesn\'t look like a phone number.';

  @override
  String whyNumber(String number) {
    return 'The number in a standard form: $number';
  }

  @override
  String get whyNoContacts =>
      'The app has no access to your contacts, so it can\'t find them there.';

  @override
  String get whyNotInContacts =>
      'This number isn\'t in this phone\'s contacts (maybe you saved a different number for them).';

  @override
  String whyInContacts(String name, String number) {
    return 'Found in contacts: $name, saved as $number.';
  }

  @override
  String get whyMe => 'That\'s your number.';

  @override
  String get whyNotUser =>
      'There\'s no DriveBond user with this number (maybe they signed up without a number, or with another one).';

  @override
  String get whyUser =>
      'They use DriveBond. In Add a friend → Contacts they should show up; if not, search again.';

  @override
  String get whyFriend => 'They\'re already your friend.';

  @override
  String get whyRemoved =>
      'One of you removed the other in the past, so they don\'t come back from contacts. Whoever removed can bring them back: My people → People I removed → Bring back.';

  @override
  String get whyBlocked =>
      'There\'s a block between you, so they don\'t show up.';

  @override
  String get whyRateLimited =>
      'There have been many searches today. Try again tomorrow.';

  @override
  String get whyOldServer =>
      'The server hasn\'t been updated for this check yet (part 21).';

  @override
  String get widgetTitle => 'Free now';

  @override
  String get widgetEmpty => 'Nobody is free right now';

  @override
  String widgetLeft(String m) {
    return '$m min left';
  }

  @override
  String get voiceHeardYes => 'Got it, connecting.';

  @override
  String get voiceHeardNo => 'Okay.';

  @override
  String get voiceNotHeard => 'I didn\'t hear. You can tap.';

  @override
  String healthMissing(String what) {
    return 'A phone permission is missing: $what. Without it DriveBond doesn\'t work properly.';
  }

  @override
  String get healthFix => 'Fix';

  @override
  String get whatsNewTitle => 'What\'s new in this update';

  @override
  String get whatsNewBody =>
      '• \"Yes\" by voice: a beep when listening, more time to answer, and a spoken confirmation\n• After a call you can reach out again right away\n• Home screen widget: who\'s free now';

  @override
  String get problemTitle => 'Report a problem';

  @override
  String get problemBody =>
      'Something didn\'t work? Write what happened, and we\'ll get the technical details too.';

  @override
  String get problemHint => 'What happened? Roughly when?';

  @override
  String get problemDetails =>
      'Technical details from the phone (version, status, log) are sent with the message. No friends\' names, no numbers and nothing from your voice.';

  @override
  String get ownerLookupTitle => 'A user\'s status on the server';

  @override
  String get ownerLookupHint => 'Name or phone number';

  @override
  String get ownerLookupNone => 'Nobody found.';

  @override
  String get ownerDetails => 'Technical details';

  @override
  String get testDriveTry => 'Try a test drive';

  @override
  String get testDriveTitle => 'Test drive';

  @override
  String get testDriveSettings =>
      'See how it feels in the car. Also checks that the microphone works.';

  @override
  String get testDriveBody =>
      'We\'ll pretend a friend is free while you\'re driving. The app will ask out loud, and you can answer \"yes\" or \"no\" by voice or with a button. Nobody gets a question, it\'s just practice.';

  @override
  String get testDriveStart => 'Start';

  @override
  String get testDriveFriendInitial => 'D';

  @override
  String get testDriveQuestion => 'Danny (for example) has time. Talk?';

  @override
  String get testDriveYes => 'Yes, talk';

  @override
  String get testDriveNo => 'Not now';

  @override
  String get testDriveYesTitle => 'Great, that\'s how it works';

  @override
  String get testDriveYesBody =>
      'On a real drive, once the friend also says yes, the phone dials by itself. All that\'s left is to talk.';

  @override
  String get testDriveNoTitle => 'That\'s fine too';

  @override
  String get testDriveNoBody =>
      'You can always say no. We\'ll suggest again another time.';

  @override
  String get testDriveNotHeardTitle => 'We didn\'t hear an answer';

  @override
  String get testDriveNotHeardBody =>
      'Try again and speak clearly after the beep. If it repeats, check in ⓘ at the top of Home → Permissions that the microphone is allowed. The buttons always work.';

  @override
  String get testDriveDone => 'Done';

  @override
  String get testDriveAgain => 'Try again';

  @override
  String get homeUpdating => 'Updating…';

  @override
  String get startingLines =>
      'Looking for who\'s free to talk…|Checking who\'s on the road…|Getting your friends ready…|Just a moment…';

  @override
  String get googleContinue => 'Continue with Google';

  @override
  String get googleOr => 'or without Google';

  @override
  String googleConnected(String email) {
    return 'Connected with Google: $email';
  }

  @override
  String get googleCardTitle => 'Keep your account with Google';

  @override
  String get googleCardBody =>
      'This way your friends come back to you on a new phone or after reinstalling.';

  @override
  String get googleCardAction => 'Connect Google';

  @override
  String get googleSettingsTitle => 'Google account';

  @override
  String get googleSettingsOff =>
      'Not connected. Recommended, so your account comes back on a new phone';

  @override
  String get googleTakenTitle =>
      'This Google account already has a DriveBond account';

  @override
  String get googleTakenBody =>
      'Probably from another phone. You can switch to it, and its friends will appear here. The account open on this phone now will be disconnected from it.';

  @override
  String get googleSwitch => 'Switch to this account';

  @override
  String get realErrorGoogle =>
      'We couldn\'t sign in with Google. You can try again.';

  @override
  String get autoYesTitle => 'Automatic yes';

  @override
  String get autoYesBody =>
      'Friends with enough stars connect to you right away, whenever you have time. You\'re not asked: your phone just rings. From how many stars:';

  @override
  String get autoYesFrom => 'From whom';

  @override
  String get autoYesStars3 => '3 stars and up';

  @override
  String get autoYesStars4 => '4 and up';

  @override
  String get autoYesStars5 => 'Only 5';

  @override
  String get autoYesOn => '⚡ Automatic yes is on';

  @override
  String get autoYesOff => '⚡ Automatic yes is off';

  @override
  String get instantFriend => 'Connects instantly';

  @override
  String get homeAutoYesTitle => '⚡ Automatic yes';

  @override
  String homeAutoYesOnBody(int stars) {
    return 'Friends with $stars stars and up connect to you right away when you have time, without asking you.';
  }

  @override
  String get homeAutoYesOffBody =>
      'Off. When on, close friends connect to you right away when you have time, without a question.';

  @override
  String get modeFreeShort => 'Free';

  @override
  String get startDriving => 'I\'m driving';

  @override
  String get startFree => 'I have time';

  @override
  String get startHint => 'One tap = 30 minutes. You can change it later.';

  @override
  String audienceLabel(String who) {
    return 'Available to: $who';
  }

  @override
  String get audienceAll => 'Everyone';

  @override
  String audienceAllBut(String names) {
    return 'Everyone except $names';
  }

  @override
  String get audienceTitle => 'Who am I available to?';

  @override
  String get audienceOnlyTab => 'Only groups I mark';

  @override
  String get audienceExceptTab => 'Everyone except…';

  @override
  String get audienceOnlyNote =>
      'Only people in the marked groups will see that you have time. Nothing marked: everyone.';

  @override
  String get audienceExceptNote =>
      'All friends will see that you have time, except people in the marked groups.';

  @override
  String get audienceNoGroups =>
      'No groups yet. You can create them in the People tab.';

  @override
  String audienceMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: 'one person',
    );
    return '$_temp0';
  }

  @override
  String meDrivingTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'You\'re driving',
      'male': 'You\'re driving',
      'other': 'Driving',
    });
    return '$_temp0';
  }

  @override
  String meFreeTitle(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'female': 'You have time',
      'male': 'You have time',
      'other': 'You have time',
    });
    return '$_temp0';
  }

  @override
  String timeLeftEdit(int minutes) {
    return '$minutes min left';
  }

  @override
  String get autoTripEnds => 'Automatic trip · ends by itself';

  @override
  String get timeTitle => 'For how long?';

  @override
  String get time15 => '15 min';

  @override
  String get time30 => '30 min';

  @override
  String get time45 => '45 min';

  @override
  String get time60 => '1 hour';

  @override
  String get time90 => '1.5 hours';

  @override
  String get time120 => '2 hours';

  @override
  String get time180 => '3 hours';

  @override
  String get timeUntil => 'Until a set time';

  @override
  String get timeMaxNote => 'Up to 3 hours from the start of the free time.';

  @override
  String get endFree => 'End';

  @override
  String get groupsNote =>
      'What changed: \"who sees me in each mode\" moved out of groups. Instead, when you have time you choose \"Available to…\". Someone you don\'t want seeing you: 0 stars. A setting you already made is kept, and you can see it inside the group.';

  @override
  String get intro1Title => 'Stuck in traffic again?';

  @override
  String get intro1Body =>
      'Maybe it\'s actually a good time to talk with a friend.';

  @override
  String get intro2Title => 'A friend heads out';

  @override
  String get intro2Body =>
      'She starts a drive, the car connection turns on, DriveBond detects it and you get a suggestion to talk.';

  @override
  String get introStart => 'Let\'s start';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbBack => 'Back';

  @override
  String get onbWhatIs => 'What is DriveBond?';

  @override
  String get onbPhoneTitle => 'What\'s your number?';

  @override
  String get onbGoogleName => 'The name your friends will see';

  @override
  String get intro3Title => 'Suddenly traffic\nis fun.';

  @override
  String get intro3Body =>
      'You both say yes by voice and a regular phone call starts.';

  @override
  String get intro2Badge => 'DriveBond detected: you\'re both free now';

  @override
  String get aboutTourOpen => 'How it works — in 3 pictures';

  @override
  String get aboutTourDone => 'Got it';

  @override
  String get realCarPickHint =>
      'You can mark several cars, e.g. a private car and a work car.';

  @override
  String get realCarSave => 'Save';

  @override
  String get journeyTitle => 'Your first talk — 3 steps';

  @override
  String get journeyStep1 => 'Add a friend';

  @override
  String get journeyStep2 => 'Tap \"I\'m driving\" or \"I have time\"';

  @override
  String get journeyStep3 => 'First talk through DriveBond';

  @override
  String fireTooltip(int n) {
    return '$n talks through DriveBond';
  }

  @override
  String get milestoneFirstTitle => 'Your first talk\non DriveBond! 🎉';

  @override
  String milestoneFirstBody(int stars) {
    return 'Now you can turn on ⚡ automatic yes. When it\'s on: a friend you gave $stars stars or more who taps you — your phone simply rings, without asking you \"want to talk?\", like any call.';
  }

  @override
  String get milestoneFirstGo => 'Turn on ⚡ automatic yes';

  @override
  String milestoneTitle(int n) {
    return 'Yes! You reached\n$n talks 🔥';
  }

  @override
  String milestoneBody(int n) {
    return '$n good talks with your people. Keep it going.';
  }

  @override
  String get milestoneOk => 'Let\'s go';

  @override
  String get firstRunCarTitle => 'Automatically available on every drive';

  @override
  String get firstRunCarBody =>
      'When the phone detects it\'s probably in a vehicle, friends see that you have time. At the end of the trip it turns off by itself. No location.';

  @override
  String get firstRunCarSwitch => 'Automatic trip detection';

  @override
  String get firstRunCarPick => 'Your car\'s Bluetooth — for faster detection';

  @override
  String get autoYesLockedBody => '🔒 Unlocks after your first talk';

  @override
  String milestoneUnlockedBody(int stars) {
    return '🔓 Unlocked now: ⚡ automatic yes. When it\'s on: a friend you gave $stars stars or more who taps you — your phone simply rings, without asking you \"want to talk?\", like any call.';
  }

  @override
  String get feedbackOrProblem => 'Feedback or a problem';

  @override
  String get feedbackOrProblemBody =>
      'An idea, or something that didn\'t work — it comes straight to us.';

  @override
  String get statsNoPhone => 'Accounts without a phone number';

  @override
  String statsNoPhoneHint(int active) {
    return 'Old versions or unfinished sign-ups. Not counted as people. $active of them opened the app in the period';
  }

  @override
  String statsPeople(int n) {
    return ' · from $n people';
  }

  @override
  String get genderQuestion => 'How should we address you?';

  @override
  String get genderMale => 'He';

  @override
  String get genderFemale => 'She';

  @override
  String get genderAny => 'Doesn\'t matter';

  @override
  String get genderHint =>
      'Only for the wording in the app. You can skip it, and change it in settings.';

  @override
  String get genderCardBody =>
      'One choice, and from now on the app will address you accordingly. You can change it in settings.';

  @override
  String get settingsLanguage => 'Language · שפה';

  @override
  String get languagePhone => 'Like the phone';

  @override
  String get languageHe => 'עברית';

  @override
  String get languageEn => 'English';

  @override
  String get settingsAccessibility => 'Accessibility statement';

  @override
  String get funnelTitle => 'The funnel: what happens to people who joined';

  @override
  String get funnelJoined => 'Joined in the period';

  @override
  String get funnelJoinedHint => 'New people (by phone number)';

  @override
  String get funnelFriend => 'Added a friend';

  @override
  String get funnelFriendHint => 'Of them: have at least one connected friend';

  @override
  String get funnelFree => 'Were available';

  @override
  String get funnelFreeHint =>
      'Of them: marked they have time or drove, at least once';

  @override
  String get funnelTalked => 'Talked';

  @override
  String get funnelTalkedHint => 'Of them: at least one talk through DriveBond';

  @override
  String get funnelWeek => 'Came back after a week';

  @override
  String funnelWeekHint(int base) {
    return 'Of $base who joined a week ago or more: opened the app again after 7 days';
  }

  @override
  String get firstRunFewHint =>
      'Best with 3 friends or more: then there\'s almost always someone free to talk.';

  @override
  String get firstRunInviteMore => 'Invite more friends';
}
