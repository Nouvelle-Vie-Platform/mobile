// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Miracle House';

  @override
  String get splashTagline => 'We proclaim with faith.';

  @override
  String get navHome => 'Home';

  @override
  String get navMedia => 'Media';

  @override
  String get navAnnouncements => 'Announcements';

  @override
  String get navGroups => 'Chats';

  @override
  String get navProfile => 'Profile';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navDonations => 'Giving';

  @override
  String get announcementsTitle => 'Announcements';

  @override
  String get announcementsEmptyTitle => 'No announcements';

  @override
  String get announcementsEmptyBody => 'Church announcements will appear here.';

  @override
  String get statusVideoBadge => 'Video';

  @override
  String get statusListTitle => 'All announcements';

  @override
  String get statusOpenList => 'See all announcements';

  @override
  String get statusMute => 'Mute';

  @override
  String get statusUnmute => 'Unmute';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String get onboardingWelcome => 'Welcome';

  @override
  String get onboardingTitleHighlight => 'To the Miracle\nHouse';

  @override
  String get onboardingSubtitle =>
      'A living community, connected and committed for the glory of God.';

  @override
  String get actionNext => 'Next';

  @override
  String get onboardingVerse =>
      '« Come to me, all who are weary, and I will give you rest. »\n— Matthew 11:28';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingJoinTitle => 'Join us';

  @override
  String get onboardingJoinSubtitle => 'Choose how to continue.';

  @override
  String get authPhone => 'Phone';

  @override
  String get authEmail => 'Email';

  @override
  String get actionJoin => 'Join';

  @override
  String get onboardingCodeTitle => 'Verification';

  @override
  String get onboardingCodeSubtitle => 'Enter the code you received.';

  @override
  String get onboardingCodeHint => 'Verification code';

  @override
  String get actionValidate => 'Confirm';

  @override
  String get onboardingAlreadyMember => 'Already a member? ';

  @override
  String get loginTitle => 'Glad to see you again!';

  @override
  String get loginSubtitle => 'Log in to continue.';

  @override
  String get fieldEmailOrPhone => 'Email or phone';

  @override
  String get fieldPassword => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get actionLogin => 'Log in';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get noAccountYet => 'No account yet? ';

  @override
  String get actionRegister => 'Sign up';

  @override
  String get registerAppBarTitle => 'Registration';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle => 'Join our community.';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldLocalBranch => 'Local branch';

  @override
  String get registerTermsPrefix =>
      'After verification, you will be asked to accept our ';

  @override
  String get registerTermsLink => 'terms of use and our privacy policy.';

  @override
  String homeGreeting(String name) {
    return 'Hello $name!';
  }

  @override
  String get homeGreetingNoName => 'Hello!';

  @override
  String get homeBlessing => 'May God bless you today.';

  @override
  String get liveBannerTitle => 'Live service';

  @override
  String get liveBannerSubtitle => 'Join now';

  @override
  String get sectionUpcoming => 'Upcoming';

  @override
  String get sectionUpcomingServices => 'Upcoming services';

  @override
  String get homeWatchLive => 'Watch live';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionListen => 'Listen';

  @override
  String get sectionLatestTeachings => 'Latest teachings';

  @override
  String get mediaTitle => 'Media library';

  @override
  String get mediaSearchHint => 'Search for a teaching...';

  @override
  String get mediaRecommended => 'Recommended for you';

  @override
  String get filterAll => 'All';

  @override
  String get filterSermons => 'Sermons';

  @override
  String get filterTeachings => 'Teachings';

  @override
  String get filterMusic => 'Music';

  @override
  String get seriesTag => 'Series';

  @override
  String seriesMessagesCount(int count) {
    return '$count messages';
  }

  @override
  String get groupsDiscoverMore => 'Discover more groups';

  @override
  String get communityTitle => 'Chats';

  @override
  String get echangesDiscover => 'Groups to join';

  @override
  String echangesHostedBy(String name) {
    return 'Hosted by $name';
  }

  @override
  String get requestsTitle => 'Requests';

  @override
  String get requestsEmptyTitle => 'No requests yet';

  @override
  String get requestsEmpty => 'Your requests and suggestions will appear here.';

  @override
  String get requestsAdd => 'New request';

  @override
  String get memberMessage => 'Message';

  @override
  String get memberProfileSubtitle => 'Community member';

  @override
  String get groupInfoAbout => 'Description';

  @override
  String get groupInfoSharedMedia => 'Shared media';

  @override
  String get mediaSaved => 'Image saved to your photos';

  @override
  String get mediaSaveErrorPermission =>
      'Photos access denied. Allow it in Settings.';

  @override
  String get mediaSaveErrorNetwork => 'Download failed. Check your connection.';

  @override
  String get mediaSaveErrorUnsupported =>
      'Saving isn\'t available on this device.';

  @override
  String get mediaSaveError => 'Couldn\'t save the image.';

  @override
  String groupMembers(int count) {
    return '$count members';
  }

  @override
  String groupMembersWithRole(int count, String role) {
    return '$count members • $role';
  }

  @override
  String get joinGroupOpen => 'Join';

  @override
  String get joinGroupRequest => 'Request to join';

  @override
  String get joinGroupPending => 'Pending';

  @override
  String get groupLeave => 'Leave group';

  @override
  String get groupJoined => 'You joined the group.';

  @override
  String get groupRequestSent => 'Request sent.';

  @override
  String get groupActionError => 'Action failed for now.';

  @override
  String get echangesEmpty => 'No conversations yet.';

  @override
  String get echangesError => 'Couldn\'t load your chats.';

  @override
  String get groupBroadcastBanner => 'Only leaders post in this group.';

  @override
  String get groupWriteLockedBanner =>
      'Writing is temporarily restricted to leaders.';

  @override
  String get groupDeactivatedBanner => 'This group is archived, read-only.';

  @override
  String get groupJoinRequestsTitle => 'Join requests';

  @override
  String get groupApprove => 'Approve';

  @override
  String get groupReject => 'Decline';

  @override
  String get institutionGroupsTitle => 'Its groups';

  @override
  String get institutionOfficialAccount => 'Official account';

  @override
  String get institutionContributor => 'Contributor';

  @override
  String get chatMessageHint => 'Your message...';

  @override
  String get chatToday => 'Today';

  @override
  String get teachingAppBarTitle => 'Teaching';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionMyNotes => 'My notes';

  @override
  String get actionShare => 'Share';

  @override
  String get tabDescription => 'Description';

  @override
  String get teachingVerses => 'Verses';

  @override
  String tabNotesCount(int count) {
    return 'Notes ($count)';
  }

  @override
  String get actionDownloadAudio => 'Download audio';

  @override
  String get downloadStateDownloading => 'Downloading';

  @override
  String downloadProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get downloadStatePaused => 'Paused';

  @override
  String get downloadStateWaitingWifi => 'Waiting for Wi-Fi';

  @override
  String get downloadStateComplete => 'Downloaded';

  @override
  String get downloadStateFailed => 'Download failed';

  @override
  String get downloadActionPause => 'Pause';

  @override
  String get downloadActionResume => 'Resume download';

  @override
  String get downloadActionRetry => 'Retry download';

  @override
  String get downloadActionDelete => 'Delete download';

  @override
  String get downloadDeleteConfirmTitle => 'Delete this download?';

  @override
  String get downloadDeleteConfirmMessage =>
      'The file will be removed from this device. You can download it again later.';

  @override
  String get downloadDeleteConfirmAction => 'Delete';

  @override
  String get downloadStateQueued => 'Queued';

  @override
  String get profileDownloads => 'Downloads';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmptyTitle => 'No downloads';

  @override
  String get downloadsEmptyMessage =>
      'Teachings you download to listen offline will show up here.';

  @override
  String downloadsStorageUsed(String size) {
    return '$size MB used';
  }

  @override
  String downloadSize(String size) {
    return '$size MB';
  }

  @override
  String get downloadsUnknownTitle => 'Downloaded teaching';

  @override
  String get downloadUpdateAvailable => 'Update available';

  @override
  String get downloadActionUpdate => 'Update';

  @override
  String downloadPurgeNotice(String title) {
    return '“$title” was removed by the library and deleted from your downloads.';
  }

  @override
  String get downloadPurgeNoticeUnnamed =>
      'A teaching was removed by the library and deleted from your downloads.';

  @override
  String get downloadPurgeDismiss => 'Dismiss';

  @override
  String get agendaSeeAll => 'See full agenda';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get liveAppBarTitle => 'Live service';

  @override
  String get liveAudioOnly => 'Audio only';

  @override
  String get liveQuality => 'Quality';

  @override
  String get liveAboutTitle => 'About this live';

  @override
  String get liveAboutBody =>
      'Be blessed by the Word of God and stay connected.';

  @override
  String liveConnectedPeople(String count) {
    return '$count people connected';
  }

  @override
  String get liveCommentHint => 'Write a message...';

  @override
  String get prayersAppBarTitle => 'Prayer space';

  @override
  String get prayersTabMine => 'My requests';

  @override
  String get prayersTabCommunity => 'Community';

  @override
  String get prayersNewRequest => 'New request';

  @override
  String prayerRequestPraying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members praying',
      one: '$count member praying',
    );
    return '$_temp0';
  }

  @override
  String get newRequestAppBarTitle => 'New request';

  @override
  String get newRequestTypeLabel => 'Request type';

  @override
  String get requestTypeSuggestion => 'Suggestion';

  @override
  String get requestTypeComplaint => 'Complaint';

  @override
  String get requestTypeReport => 'Report';

  @override
  String get requestTypeOther => 'Other';

  @override
  String get newRequestDescribeLabel => 'Describe your request';

  @override
  String get newRequestDescribeHint => 'Write your message here...';

  @override
  String get anonymousLabel => 'Anonymous';

  @override
  String get anonymousSubtitle => 'Your identity will remain confidential.';

  @override
  String get actionSend => 'Send';

  @override
  String get notesAppBarTitle => 'My notes';

  @override
  String get notesSearchHint => 'Search for a note...';

  @override
  String get profileRole => 'New Life member';

  @override
  String get profileEdit => 'Edit';

  @override
  String get profileStatServices => 'Services';

  @override
  String get profileStatNotes => 'Notes';

  @override
  String get profileMyBranch => 'My branch';

  @override
  String get profileMyContributions => 'My contributions';

  @override
  String get profileMyNotes => 'My spiritual notes';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get settings => 'Settings';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete my account';

  @override
  String get deleteAccountLead =>
      'This is permanent. It cannot be undone, and nobody at the church can undo it for you.';

  @override
  String get deleteAccountErasedTitle => 'What is erased';

  @override
  String get deleteAccountErasedIdentity =>
      'Your identity: name, title, email, phone.';

  @override
  String get deleteAccountErasedNotes => 'Your spiritual notes.';

  @override
  String get deleteAccountErasedProgress =>
      'Your listening progress, on this device and the others.';

  @override
  String get deleteAccountKeptTitle => 'What stays, without your name';

  @override
  String get deleteAccountKeptMessages =>
      'Your group messages stay readable, detached from you.';

  @override
  String get deleteAccountKeptPrayers =>
      'Prayers others carried with you do not vanish from the wall.';

  @override
  String get deleteAccountReuse =>
      'Your email becomes free again: you may sign up later, but it will be a brand new account with nothing of this one.';

  @override
  String get deleteAccountConfirmCheckbox => 'I understand this is permanent.';

  @override
  String get deleteAccountAction => 'Delete permanently';

  @override
  String get deleteAccountErrorNetwork =>
      'Cannot delete: no network. Your account is untouched.';

  @override
  String get deleteAccountErrorServer =>
      'The server could not process the request. Your account is untouched, try again.';

  @override
  String get mediaSettings => 'Quality';

  @override
  String get mediaSettingsTitle => 'Quality & data';

  @override
  String get mediaSettingsLead =>
      'These settings change nothing on the church network. They protect your data plan when you are out.';

  @override
  String get mediaSettingsStreaming => 'Listening to a teaching';

  @override
  String get mediaSettingsLive => 'Live';

  @override
  String get mediaSettingsDownload => 'Download';

  @override
  String get mediaSettingsDownloadOnCellular => 'Download on mobile data';

  @override
  String get mediaSettingsDownloadOnCellularSubtitle =>
      'By default, downloads wait for Wi-Fi to protect your data plan.';

  @override
  String get mediaQualityAuto => 'Automatic';

  @override
  String get mediaQualityLow => 'Data saver';

  @override
  String get mediaQualityMid => 'Standard';

  @override
  String get mediaQualityHigh => 'High';

  @override
  String mediaQualityImpactAuto(int mb) {
    return '≈ $mb MB per hour on mobile data, better quality on wifi.';
  }

  @override
  String mediaQualityImpactLow(int mb) {
    return '≈ $mb MB per hour · fine for preaching, the choir loses depth.';
  }

  @override
  String mediaQualityImpactMid(int mb) {
    return '≈ $mb MB per hour · worship regains its fullness.';
  }

  @override
  String mediaQualityImpactHigh(int mb) {
    return '≈ $mb MB per hour · every nuance, at full price.';
  }

  @override
  String get themeSectionTitle => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAutoHoursTitle => 'Switch times';

  @override
  String get themeDarkFrom => 'Goes dark at';

  @override
  String get themeLightFrom => 'Back to light at';

  @override
  String get logout => 'Log out';

  @override
  String get donationsAppBarTitle => 'Donations & Offerings';

  @override
  String get donationsTitle => 'Support God\'s work';

  @override
  String get donationsSubtitle =>
      'Give according to what God puts in your heart.';

  @override
  String get donationsAmountLabel => 'Amount';

  @override
  String get donationsPaymentMethodLabel => 'Payment method';

  @override
  String get paymentCard => 'Bank card';

  @override
  String get actionContinue => 'Continue';

  @override
  String get donationsSecure => 'Your donations are secure';

  @override
  String get authStart => 'Get started';

  @override
  String get authAlreadyMember => 'Already a member?';

  @override
  String get authIdentifierTitle => 'Join us';

  @override
  String get authIdentifierSubtitle =>
      'Enter your phone number or email to continue.';

  @override
  String get authPhoneHint => '90 12 34 56';

  @override
  String get authEmailHint => 'jean.kossi@email.com';

  @override
  String get authContinue => 'Continue';

  @override
  String get authOrContinueWith => 'Or continue with';

  @override
  String get authDialCode => 'Dial code';

  @override
  String get authCodeTitle => 'Verification';

  @override
  String authCodeSubtitle(String target) {
    return 'Enter the 6-digit code sent to $target.';
  }

  @override
  String get authResend => 'Resend code';

  @override
  String authResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authCodeInvalid => 'Invalid or expired code';

  @override
  String get profileFormTitle => 'We\'d love to know more about you';

  @override
  String get profileFormSubtitle =>
      'This information stays optional and can be changed anytime.';

  @override
  String get titleBrother => 'Brother';

  @override
  String get titleSister => 'Sister';

  @override
  String get fieldYourName => 'Your first name';

  @override
  String get fieldYourBranch => 'Your branch';

  @override
  String get branchImNew => 'I\'m new';

  @override
  String get branchMotherChurch => 'Mother Church';

  @override
  String get branchesEmpty => 'No branch to select yet.';

  @override
  String get branchesUnavailable =>
      'Branch list unavailable. You can pick one later.';

  @override
  String get actionLater => 'Later';

  @override
  String get actionSave => 'Save';

  @override
  String get profileEditAction => 'Edit my profile';

  @override
  String get profileIncompleteBanner => 'Complete your profile';

  @override
  String get profileIncompleteBannerCta => 'Complete';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage => 'You\'ll need a new code to log back in.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get statusNewLabel => 'New — not attached yet';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get profileTitleLabel => 'Title';

  @override
  String get profileTitleRequired => 'Please select Brother or Sister';

  @override
  String get authCodeTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get authCodeResent => 'Code resent.';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateEmptyTitle => 'Nothing to show';

  @override
  String get stateEmptyMessage => 'There is no content here yet.';

  @override
  String get stateEndOfList => 'End of list';

  @override
  String get stateErrorTitle => 'Connection lost';

  @override
  String get stateErrorMessage =>
      'We couldn\'t load this content. Check your internet connection, then try again.';

  @override
  String get stateErrorServerMessage =>
      'The server isn\'t responding right now. Please try again in a moment.';

  @override
  String get stateRetry => 'Try again';

  @override
  String get homeUpcomingEmptyTitle => 'No upcoming gatherings';

  @override
  String get homeUpcomingEmptyMessage =>
      'Nothing is on the calendar right now. Check back soon.';

  @override
  String homeUpcomingHorizonMessage(String date) {
    return 'Nothing is on the calendar through $date.';
  }

  @override
  String get agendaEmptyMonthTitle => 'No events this month';

  @override
  String get agendaEmptyMonthMessage => 'Nothing is scheduled for this period.';

  @override
  String get agendaHorizonTitle => 'End of the calendar';

  @override
  String get agendaHorizonMessage =>
      'Events further ahead haven\'t been announced yet.';

  @override
  String get agendaPreviousMonth => 'Previous month';

  @override
  String get agendaNextMonth => 'Next month';

  @override
  String agendaDaySummary(int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
      zero: 'no events',
    );
    return '$day — $_temp0';
  }

  @override
  String get eventDetailTitle => 'Event';

  @override
  String get eventDetailAbout => 'About';

  @override
  String get absenceRetractedTitle => 'Content removed';

  @override
  String get absenceRetractedMessage =>
      'This content is no longer available. It was removed by the church.';

  @override
  String get absenceNotSyncedTitle => 'Not synced yet';

  @override
  String get absenceNotSyncedMessage =>
      'This content hasn\'t reached this device yet. It will appear after the next sync.';

  @override
  String get absenceNoMediaTitle => 'Recording coming soon';

  @override
  String get absenceNoMediaMessage =>
      'The recording isn\'t online yet. Check back in a few days.';

  @override
  String get absenceOfflineMediaTitle => 'Can\'t listen offline';

  @override
  String get absenceOfflineMediaMessage =>
      'The media library plays online. Reconnect to the internet to start playback.';

  @override
  String get absenceBack => 'Back';

  @override
  String get gatheringAppBarTitle => 'Gathering';

  @override
  String get gatheringRetractedTitle => 'This gathering is no longer available';

  @override
  String get gatheringRetractedMessage =>
      'It was removed by the church. Playback has stopped.';

  @override
  String get sectionGatherings => 'Gatherings';

  @override
  String get teachingRetractedTitle => 'This teaching is no longer available';

  @override
  String get teachingRetractedMessage =>
      'It was removed from the media library. Playback has stopped.';

  @override
  String get playerErrorTitle => 'Playback interrupted';

  @override
  String get playerErrorMessage =>
      'The sound stopped. Check your connection, then resume playback.';

  @override
  String get playerErrorRetry => 'Resume';

  @override
  String get composeAnnouncement => 'Post an announcement';

  @override
  String get composerNewTitle => 'New announcement';

  @override
  String get composerEditTitle => 'Edit announcement';

  @override
  String get composerAccountLabel => 'Post as';

  @override
  String get composerTitleLabel => 'Title';

  @override
  String get composerTitleHint => 'Optional';

  @override
  String get composerBodyLabel => 'Message';

  @override
  String get composerBodyHint => 'What the church needs to know';

  @override
  String get composerBackgroundLabel => 'Background';

  @override
  String get composerBackgroundNone => 'None';

  @override
  String get composerImageLabel => 'Background image';

  @override
  String get composerImageAdd => 'Choose an image';

  @override
  String get composerImageReplace => 'Replace image';

  @override
  String get composerImageRemove => 'Remove image';

  @override
  String get composerImageKept => 'Published image kept';

  @override
  String get composerTimingLabel => 'Publication';

  @override
  String get composerTimingNow => 'Now';

  @override
  String get composerTimingScheduled => 'Schedule';

  @override
  String get composerTimingDraft => 'Draft';

  @override
  String get composerScheduleLabel => 'Publication date';

  @override
  String get composerSchedulePick => 'Pick a date';

  @override
  String get composerExpiryLabel => 'Ends on';

  @override
  String get composerExpiryNever => 'Never expires';

  @override
  String get composerExpiryPick => 'Pick an end date';

  @override
  String get composerExpiryClear => 'Remove end date';

  @override
  String get composerPublish => 'Publish';

  @override
  String get composerSave => 'Save';

  @override
  String get composerDelete => 'Delete announcement';

  @override
  String get composerDeleteConfirmTitle => 'Delete this announcement?';

  @override
  String get composerDeleteConfirmBody =>
      'It will disappear from every member\'s app.';

  @override
  String get composerDeleteConfirmAction => 'Delete';

  @override
  String get composerNoAccountTitle => 'No account available';

  @override
  String get composerNoAccountBody =>
      'Your official accounts haven\'t reached this device yet. Try again after the next sync.';

  @override
  String get composerMissingTitle => 'Announcement not found';

  @override
  String get composerMissingBody =>
      'It has been removed. There is nothing left to edit.';

  @override
  String get composerIssueNothing =>
      'Add at least a title, a message or an image.';

  @override
  String get composerIssueSchedule => 'Pick the publication date.';

  @override
  String get composerIssueExpiry =>
      'The end date must come after the publication date.';

  @override
  String get composerErrorNetworkTitle => 'Connection required';

  @override
  String get composerErrorNetworkBody =>
      'Posting an announcement needs an internet connection. Your text is kept: reconnect, then try again.';

  @override
  String get composerErrorForbiddenTitle =>
      'You no longer post for this account';

  @override
  String get composerErrorForbiddenBody =>
      'This official account\'s team has changed. Reach out to a leader if this is a mistake.';

  @override
  String get composerErrorRejectedTitle => 'Announcement refused';

  @override
  String get composerErrorRejectedBody =>
      'The server did not accept this announcement. Fix it, then try again.';

  @override
  String get composerErrorGoneTitle => 'Announcement not found';

  @override
  String get composerErrorGoneBody =>
      'It was deleted in the meantime, perhaps by another member of the account.';

  @override
  String get composerErrorServerTitle => 'Server unavailable';

  @override
  String get composerErrorServerBody =>
      'The server is not responding properly. Try again in a moment.';

  @override
  String get composerErrorUnauthorizedTitle => 'Session expired';

  @override
  String get composerErrorUnauthorizedBody => 'Sign in again to post.';

  @override
  String get composerPublished => 'Announcement posted';

  @override
  String get composerUpdated => 'Announcement updated';

  @override
  String get composerDeleted => 'Announcement deleted';

  @override
  String get statusEdit => 'Edit announcement';

  @override
  String get statusDelete => 'Delete announcement';

  @override
  String get drawerOpen => 'Open menu';

  @override
  String get drawerTerms => 'Terms of use';

  @override
  String get drawerPrivacy => 'Privacy policy';

  @override
  String get drawerAbout => 'About';

  @override
  String get aboutChurchName => 'Église Évangélique Nouvelle Vie';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String legalFooterUpdated(int version, String date) {
    return 'Version $version — updated on $date';
  }

  @override
  String legalFooterVersion(int version) {
    return 'Version $version';
  }

  @override
  String get legalGateTitleFirst => 'Before we begin';

  @override
  String get legalGateTitleUpdated => 'Our terms have changed';

  @override
  String get legalGateSubtitle => 'We need your agreement to continue.';

  @override
  String get legalGateAcceptTerms => 'I have read and accept the terms of use.';

  @override
  String get legalGateAcceptPrivacy =>
      'I have read and accept the privacy policy.';

  @override
  String get legalGateErrorNetwork =>
      'A connection is required to record your agreement.';

  @override
  String get legalGateErrorUnauthorized =>
      'Your session has expired. Sign in again to record your agreement.';

  @override
  String get legalGateErrorOutdated => 'These terms have been updated.';

  @override
  String get legalGateErrorServer =>
      'The server could not record your agreement.';

  @override
  String get legalGateReload => 'Reload';
}
