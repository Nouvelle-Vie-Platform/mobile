// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nouvelle Vie';

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
  String get navBible => 'Bible';

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
  String get radioTitle => 'New Life Radio';

  @override
  String get radioOffAir => 'Off air';

  @override
  String get radioLive => 'On air';

  @override
  String get radioUnstable => 'Unstable connection…';

  @override
  String get radioRetrying => 'Reconnecting…';

  @override
  String get radioFailureAntenna => 'Station unavailable';

  @override
  String get radioUnavailableMessage =>
      'New Life Radio is not broadcasting right now.';

  @override
  String get radioLongPressTip => 'Press and hold to open the live page';

  @override
  String get radioOpenLiveHint => 'open the live page';

  @override
  String get radioLiveBadge => 'LIVE';

  @override
  String radioListeners(int count) {
    return '$count listening';
  }

  @override
  String get radioReactionHeart => 'Send a heart';

  @override
  String get radioReactionPray => 'Send a prayer';

  @override
  String get radioReactionPraise => 'Send praise';

  @override
  String get radioReactionFire => 'Send fire';

  @override
  String get radioReactionAmen => 'Amen';

  @override
  String get radioReactionAmenLabel => 'Say Amen';

  @override
  String get radioCommentsLabel => 'Live comments';

  @override
  String radioCommentSemantics(String name, String body) {
    return '$name: $body';
  }

  @override
  String get radioMessageOptionsHint => 'message options';

  @override
  String get radioNewMessages => 'New messages';

  @override
  String get radioCommentHint => 'Write…';

  @override
  String get radioSilencedNotice =>
      'A moderator has paused your comments until the end of this live.';

  @override
  String get radioCommentClosed => 'The live has ended: comments are closed.';

  @override
  String get radioCommentThrottled =>
      'Slow down: one message every five seconds.';

  @override
  String get radioCommentInvalid =>
      'Your message must be 1 to 200 characters long.';

  @override
  String get radioCommentFailed => 'Message not sent. Try again.';

  @override
  String get radioPseudonymTitle => 'Choose a display name';

  @override
  String get radioPseudonymMessage =>
      'It will appear next to your messages during live broadcasts.';

  @override
  String get radioPseudonymHint => 'Your display name';

  @override
  String get radioPseudonymConfirm => 'Confirm';

  @override
  String get radioPseudonymInvalid => 'Between 2 and 24 characters.';

  @override
  String get radioPseudonymThrottled => 'Too many attempts. Try again later.';

  @override
  String get radioPseudonymFailed => 'Display name not saved. Try again.';

  @override
  String get radioReportAction => 'Report this message';

  @override
  String get radioReported => 'Thanks, a moderator will review it.';

  @override
  String get radioAlreadyReported => 'You have already reported this message.';

  @override
  String get radioMessageGone => 'This message is no longer available.';

  @override
  String get radioActionFailed => 'Couldn\'t do that. Try again.';

  @override
  String get radioModHide => 'Hide';

  @override
  String get radioModKeep => 'Keep';

  @override
  String get radioModSilence => 'Silence the author';

  @override
  String get radioModResetPseudonym => 'Reset display name';

  @override
  String get radioModHidden => 'Message hidden.';

  @override
  String get radioModKept => 'Message kept.';

  @override
  String get radioModSilenced => 'Author silenced until the end of this live.';

  @override
  String get radioModPseudonymReset => 'Display name reset.';

  @override
  String get radioModNotGuest => 'Only a guest\'s display name can be reset.';

  @override
  String get radioReportedQueue => 'Reported messages';

  @override
  String radioReportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
    );
    return '$_temp0';
  }

  @override
  String get radioReportedEmpty => 'No messages waiting.';

  @override
  String get radioStopListening => 'Stop listening';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionListen => 'Listen';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionLoading => 'Loading…';

  @override
  String get sectionLatestTeachings => 'Latest publications';

  @override
  String get mediaTitle => 'Media library';

  @override
  String get mediaSearchHint => 'Search for a message...';

  @override
  String get filterAll => 'All';

  @override
  String get filterTeachings => 'Messages';

  @override
  String get seriesTag => 'Theme';

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
  String get echangesTabMessages => 'Messages';

  @override
  String get echangesTabRequests => 'Requests';

  @override
  String get requestsEmptyTitle => 'No requests yet';

  @override
  String get requestsEmpty =>
      'Your prayer requests, suggestions and complaints will appear here, with their follow-up.';

  @override
  String get requestsAdd => 'New request';

  @override
  String get requestsLoadError => 'Couldn\'t read your requests.';

  @override
  String get requestStatusNew => 'New';

  @override
  String get requestStatusInProgress => 'In progress';

  @override
  String get requestStatusResolved => 'Resolved';

  @override
  String get requestStatusArchived => 'Archived';

  @override
  String requestSentOn(String date) {
    return 'Sent on $date';
  }

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
  String get chatAuthorRemoved => 'Removed member';

  @override
  String get chatReadOnly => 'Only group hosts can post in this group.';

  @override
  String get chatEmpty => 'No messages yet. Be the first to write.';

  @override
  String get echangesEmptyTitle => 'No conversations';

  @override
  String get echangesEmpty =>
      'Your groups and chats will show up here. Pull down to refresh.';

  @override
  String get echangesLoadError => 'Could not read your conversations.';

  @override
  String get echangesJoinOpen => 'Open to all';

  @override
  String get echangesJoinOnRequest => 'On request';

  @override
  String get echangesJoinPending => 'Request sent';

  @override
  String get groupRoleLeader => 'Host';

  @override
  String get groupRoleModerator => 'Moderator';

  @override
  String get groupRoleMember => 'Member';

  @override
  String get chatMessageHint => 'Your message...';

  @override
  String get chatToday => 'Today';

  @override
  String chatUnreadSeparator(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get chatMediaUnsupported =>
      'This message contains media this version of the app can\'t show yet.';

  @override
  String get echangesMediaPreview => 'Attachment';

  @override
  String get chatMessageFailed => 'Not sent. Tap to retry.';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatDiscard => 'Delete';

  @override
  String echangesUnreadBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String get teachingAppBarTitle => 'Message';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionMyNotes => 'My notes';

  @override
  String get actionShare => 'Share';

  @override
  String get tabDescription => 'Description';

  @override
  String contentGuests(String names) {
    return 'With $names';
  }

  @override
  String get listAnd => 'and';

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
      'Messages you download to listen offline will show up here.';

  @override
  String downloadsStorageUsed(String size) {
    return '$size MB used';
  }

  @override
  String downloadSize(String size) {
    return '$size MB';
  }

  @override
  String get downloadsUnknownTitle => 'Downloaded message';

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
      'A message was removed by the library and deleted from your downloads.';

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
  String get requestTypePrayer => 'Prayer request';

  @override
  String get requestTypeSuggestion => 'Suggestion';

  @override
  String get requestTypeComplaint => 'Complaint';

  @override
  String get newRequestTitleLabel => 'Subject';

  @override
  String get newRequestTitleHint => 'In a few words';

  @override
  String get newRequestTitleTooShort => 'At least 3 characters.';

  @override
  String get newRequestContentEmpty => 'Write your message.';

  @override
  String get newRequestShareLabel => 'Share with the community';

  @override
  String get newRequestShareSubtitle =>
      'It will appear on the prayer wall. Otherwise only the pastoral team will read it.';

  @override
  String get newRequestSent => 'Request sent.';

  @override
  String get newRequestErrorNetwork => 'Couldn\'t send: check your connection.';

  @override
  String get newRequestErrorGeneric => 'Sending failed. Please try again.';

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
  String get notesTab => 'Notes';

  @override
  String get notesGuestTitle => 'Your notes are waiting';

  @override
  String get notesGuestMessage =>
      'Sign in to write your notes and find them on all your devices.';

  @override
  String get notesEmptyTitle => 'No notes';

  @override
  String get notesEmptyMessage => 'Tap + to write your first note.';

  @override
  String get notesFilterAll => 'All';

  @override
  String get notesUntitled => 'New note';

  @override
  String get notesBodyHint => 'Write here…';

  @override
  String get notesDone => 'Done';

  @override
  String get notesPin => 'Pin';

  @override
  String get notesUnpin => 'Unpin';

  @override
  String get notesDelete => 'Delete';

  @override
  String get notesDeleteConfirmTitle => 'Delete this note?';

  @override
  String get notesDeleteConfirmMessage =>
      'It will be removed from all your devices.';

  @override
  String get notesCategoryTitle => 'Category';

  @override
  String get notesCategoryAdd => 'Add a category';

  @override
  String get notesCategoryNameHint => 'Category name';

  @override
  String get notesCategoryCreate => 'Add';

  @override
  String get notesCategoryNone => 'No category';

  @override
  String get notesCategoryEditTitle => 'Edit category';

  @override
  String get notesCategoryDelete => 'Delete category';

  @override
  String notesCategoryDeleteConfirm(String name) {
    return 'Delete “$name”? Its notes will stay, without a category.';
  }

  @override
  String get notesShareFailed => 'Sharing failed.';

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
  String get mediaSettingsStreaming => 'Listening to a message';

  @override
  String get mediaSettingsDownload => 'Download';

  @override
  String get mediaSettingsDownloadOnCellular => 'Download on mobile data';

  @override
  String get mediaSettingsDownloadOnCellularSubtitle =>
      'By default, downloads wait for Wi-Fi to protect your data plan.';

  @override
  String get branchScopeTitle => 'My assembly';

  @override
  String get branchScopeLead =>
      'Choose the assembly whose messages, gatherings and announcements you want to follow. The agenda and the prayer wall are unaffected.';

  @override
  String get branchScopeAll => 'All assemblies';

  @override
  String get branchScopeAllSubtitle =>
      'Everything the church publishes, wherever it publishes it.';

  @override
  String get branchScopeEmpty =>
      'The list of assemblies will arrive with the first sync.';

  @override
  String get mediaSettingsRadio => 'Radio';

  @override
  String get mediaSettingsListening => 'Listening';

  @override
  String get qualityQuestionRadio => 'What quality for the radio?';

  @override
  String get qualityQuestionListening => 'What quality for listening?';

  @override
  String get qualityQuestionDownload => 'What quality for downloads?';

  @override
  String get qualityLead =>
      'Quality adapts to your network, or stays fixed to save your data.';

  @override
  String get radioQualityMinimum => 'Minimum';

  @override
  String qualityPerHour(int mb) {
    return '≈ $mb MB per hour';
  }

  @override
  String get qualityAdaptive => 'Adapts to your network';

  @override
  String get mediaQualityAuto => 'Automatic';

  @override
  String get mediaQualityLow => 'Data saver';

  @override
  String get mediaQualityMid => 'Standard';

  @override
  String get mediaQualityHigh => 'High';

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
  String get authAlreadyMember => 'Already a member?';

  @override
  String get authIdentifierTitle => 'Join us';

  @override
  String get authIdentifierSubtitle =>
      'Enter your phone number or email to continue.';

  @override
  String get authReasonCommunity => 'Sign in to reach your conversations.';

  @override
  String get authReasonProfile => 'Sign in to reach your profile.';

  @override
  String get authPhoneHint => '90 12 34 56';

  @override
  String get authEmailHint => 'jean.kossi@email.com';

  @override
  String get authNoticeEmailOnly =>
      'Your sign-in code will be sent to you by email.';

  @override
  String get authNoticePhoneOnly =>
      'Your sign-in code will be sent to your phone.';

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
  String get stateErrorRefusedMessage =>
      'This content isn\'t available right now. Your internet connection isn\'t the problem.';

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
  String get teachingRetractedTitle => 'This message is no longer available';

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

  @override
  String get legalNoticeBody =>
      'By using the app, you accept our terms of use and our privacy policy.';

  @override
  String get legalNoticeTerms => 'Terms of use';

  @override
  String get legalNoticePrivacy => 'Privacy';

  @override
  String get legalNoticeDismiss => 'Got it';

  @override
  String get appUpdateBody => 'A new version of the app is available.';

  @override
  String get appUpdateAction => 'Update';

  @override
  String get appUpdateDismiss => 'Later';

  @override
  String get miniPlayerLiveBadge => 'LIVE';

  @override
  String get miniPlayerOnAirBadge => 'On air';

  @override
  String miniPlayerOpen(String title) {
    return 'Open player: $title';
  }

  @override
  String get miniPlayerSkipBackward => 'Back 30 seconds';

  @override
  String get miniPlayerSkipForward => 'Forward 30 seconds';

  @override
  String get miniPlayerReplay => 'Replay';

  @override
  String get miniPlayerRelaunch => 'Start listening again';

  @override
  String get miniPlayerClose => 'Close player';

  @override
  String get chatSearchHint => 'Search';

  @override
  String get chatSearchTitle => 'Search';

  @override
  String chatSearchMinLength(int count) {
    return 'Type at least $count characters to search chat names and messages.';
  }

  @override
  String get chatSearchChats => 'Chats';

  @override
  String get chatSearchMessages => 'Messages';

  @override
  String get chatSearchMore => 'More results';

  @override
  String get chatSearchOffline =>
      'Older history couldn\'t be searched. The results above come from this phone.';

  @override
  String get chatSearchNoResult => 'No results.';

  @override
  String get chatSearchUnknownChat => 'Chat';

  @override
  String get chatArchive => 'Archive';

  @override
  String get chatUnarchive => 'Unarchive';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatMarkRead => 'Mark as read';

  @override
  String get chatPinnedLabel => 'Pinned';

  @override
  String chatPinLimit(int count) {
    return 'You can pin up to $count chats. Unpin one first.';
  }

  @override
  String get chatArrangeFailed => 'This chat couldn\'t be moved.';

  @override
  String get chatArchivedNotice => 'Chat archived';

  @override
  String get chatUndo => 'Undo';

  @override
  String chatArchivedRow(int count) {
    return 'Archived ($count)';
  }

  @override
  String get chatArchivedTitle => 'Archived';

  @override
  String get chatArchivedEmptyTitle => 'No archived chats';

  @override
  String get chatArchivedEmpty =>
      'Swipe a chat to the left to archive it. It stays here even when a new message arrives.';

  @override
  String get m6NewConversation => 'New chat';

  @override
  String get m6NewGroup => 'New group';

  @override
  String get m6SearchContacts => 'Search for a name';

  @override
  String get m6NoContacts =>
      'Nobody to write to yet: you can write to the members of your groups.';

  @override
  String get m6NoContactMatch => 'No name matches.';

  @override
  String get m6DirectFirstMessage =>
      'Write the first message: the chat starts with it.';

  @override
  String get m6CreateGroupTitle => 'New group';

  @override
  String get m6GroupNameLabel => 'Group name';

  @override
  String get m6GroupNameTooShort => 'At least 3 characters';

  @override
  String get m6GroupDescriptionLabel => 'Description (optional)';

  @override
  String get m6GroupMembersLabel => 'Members';

  @override
  String get m6CreateGroupSubmit => 'Create group';

  @override
  String get m6CreateGroupFailed =>
      'The group was not created. Check your connection, then tap “Create group” again.';

  @override
  String get m6Join => 'Join';

  @override
  String get m6RequestJoin => 'Ask to join';

  @override
  String get m6Leave => 'Leave group';

  @override
  String get m6LeaveConfirm =>
      'You will no longer receive this group\'s messages.';

  @override
  String get m6Cancel => 'Cancel';

  @override
  String get m6AddMembers => 'Add members';

  @override
  String get m6AddMembersSubmit => 'Add';

  @override
  String get m6NoOneToAdd => 'Everyone from your groups is already a member.';

  @override
  String get m6MakeModerator => 'Make moderator';

  @override
  String get m6RemoveModerator => 'Remove moderator role';

  @override
  String get m6RemoveMember => 'Remove from group';

  @override
  String get m6RemoveConfirm =>
      'This person will no longer receive the group\'s messages.';

  @override
  String get m6MemberOptions => 'Member options';

  @override
  String get m6PendingRequests => 'Join requests';

  @override
  String get m6Approve => 'Accept';

  @override
  String get m6Reject => 'Decline';

  @override
  String get m6RequestUnnamed => 'Someone without a name';

  @override
  String get m6ActionRefused => 'This action isn\'t allowed here.';

  @override
  String get m6ActionUnreachable =>
      'No answer from the server. Check your connection.';

  @override
  String get chatTyping => 'typing…';

  @override
  String chatTypingNamed(String name) {
    return '$name is typing…';
  }

  @override
  String chatTypingSeveral(int count) {
    return '$count people are typing…';
  }

  @override
  String get chatPresenceOnline => 'online';

  @override
  String chatLastSeenToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String chatLastSeenYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String chatLastSeenOn(String date, String time) {
    return 'last seen $date at $time';
  }

  @override
  String get chatReceiptSent => 'Sent';

  @override
  String get chatReceiptDelivered => 'Delivered';

  @override
  String get chatReceiptRead => 'Read';

  @override
  String get messageInfoAction => 'Info';

  @override
  String get messageInfoTitle => 'Message info';

  @override
  String get messageInfoReadBy => 'Read by';

  @override
  String get messageInfoDeliveredTo => 'Delivered to';

  @override
  String get messageInfoPending => 'Not received yet';

  @override
  String get messageInfoEmpty => 'Nobody is waiting for this message.';

  @override
  String get messageInfoError =>
      'Could not load the message info. Check your connection.';

  @override
  String messageInfoToday(String time) {
    return 'today at $time';
  }

  @override
  String messageInfoYesterday(String time) {
    return 'yesterday at $time';
  }

  @override
  String messageInfoOn(String date, String time) {
    return '$date at $time';
  }

  @override
  String get privacyMenu => 'Privacy';

  @override
  String get privacyMenuSubtitle => 'Read receipts, last seen and online';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyReadReceipts => 'Read receipts';

  @override
  String get privacyReadReceiptsHint =>
      'If you turn them off, others will no longer see that you read their messages, and you will no longer see when they read yours. Does not apply to groups.';

  @override
  String get privacyPresence => 'Last seen and online';

  @override
  String get privacyPresenceHint =>
      'If you turn it off, others will no longer see when you are online, and you will no longer see when they are.';

  @override
  String get privacyLoadError => 'Could not load your privacy settings.';

  @override
  String get privacySaveError => 'The setting could not be saved. Try again.';

  @override
  String get notificationYou => 'You';

  @override
  String get notificationNewMessage => 'New message';

  @override
  String notificationNewMessageFrom(String name) {
    return 'New message from $name';
  }

  @override
  String get notificationReply => 'Reply';

  @override
  String get notificationReplyHint => 'Your message';

  @override
  String get notificationMarkRead => 'Mark as read';

  @override
  String notificationSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String notificationSummaryText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count chats',
      one: 'in 1 chat',
    );
    return '$_temp0';
  }

  @override
  String get notificationPreviewSetting => 'Show message content';

  @override
  String get notificationPreviewSettingHint =>
      'In notifications. Otherwise: “New message”';

  @override
  String get chatMuteMenu => 'Chat options';

  @override
  String get chatMute => 'Mute';

  @override
  String get chatMuteTitle => 'Mute notifications for…';

  @override
  String get chatMuteEightHours => '8 hours';

  @override
  String get chatMuteOneWeek => '1 week';

  @override
  String get chatMuteForever => 'Always';

  @override
  String get chatUnmute => 'Unmute notifications';

  @override
  String get chatMuteFailed =>
      'Mute could not be changed. Check your connection.';

  @override
  String get conversationMuted => 'Muted';

  @override
  String get chatMessageDeleted => 'This message was deleted';

  @override
  String get chatMessageEdited => 'Edited';

  @override
  String get chatMessageForwarded => 'Forwarded';

  @override
  String get chatQuoteDeleted => 'Deleted message';

  @override
  String get chatQuoteMedia => 'Media';

  @override
  String get chatQuoteAudio => 'Voice message';

  @override
  String get chatQuoteImage => 'Photo';

  @override
  String get chatQuoteYou => 'You';

  @override
  String chatReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get chatReplying => 'Reply';

  @override
  String get chatEditing => 'Edit message';

  @override
  String get chatCancelReply => 'Cancel reply';

  @override
  String get chatCancelEdit => 'Cancel editing';

  @override
  String get chatActionReply => 'Reply';

  @override
  String get chatActionCopy => 'Copy';

  @override
  String get chatActionForward => 'Forward';

  @override
  String get chatActionEdit => 'Edit';

  @override
  String get chatActionDeleteForMe => 'Delete for me';

  @override
  String get chatActionDeleteForEveryone => 'Delete for everyone';

  @override
  String get chatMoreReactions => 'More reactions';

  @override
  String get chatCopied => 'Message copied';

  @override
  String get chatDeleteForEveryoneConfirm =>
      'This message will be replaced by “This message was deleted” for everyone.';

  @override
  String get chatForwardTitle => 'Forward to…';

  @override
  String get chatForwardSend => 'Send';

  @override
  String get chatForwardEmpty => 'No conversation to forward to.';

  @override
  String get chatForwardLimit => '5 conversations at most.';

  @override
  String get chatForwardDone => 'Message forwarded';

  @override
  String get chatGestureWindowClosed => 'Too late: this is no longer possible.';

  @override
  String get chatGestureRefused => 'This isn\'t possible for this message.';

  @override
  String get chatGestureUnreachable => 'No connection. Try again.';

  @override
  String get chatReactionsTitle => 'Reactions';

  @override
  String get chatReactionsRemove => 'Tap to remove';

  @override
  String get chatQuoteNotFound => 'Message not found';

  @override
  String get m4ChatAttach => 'Attach';

  @override
  String get m4ChatCamera => 'Camera';

  @override
  String get m4ChatRecordVoice => 'Hold to record a voice message';

  @override
  String get m4AttachGallery => 'Gallery';

  @override
  String get m4AttachVideo => 'Video';

  @override
  String get m4AttachRecordVideo => 'Record';

  @override
  String get m4AttachDocument => 'Document';

  @override
  String get m4AttachAudio => 'Audio';

  @override
  String get m4AttachLocation => 'Location';

  @override
  String get m4AttachContact => 'Contact';

  @override
  String get m4PreviewVoice => '🎤 Voice message';

  @override
  String get m4PreviewAudio => '🎵 Audio';

  @override
  String get m4PreviewImage => '📷 Photo';

  @override
  String get m4PreviewVideo => '🎥 Video';

  @override
  String get m4PreviewDocument => '📄 Document';

  @override
  String get m4PreviewLocation => '📍 Location';

  @override
  String get m4PreviewContact => '👤 Contact';

  @override
  String get m4VoiceSlideToCancel => '‹ Slide to cancel';

  @override
  String get m4VoiceCancel => 'Discard voice message';

  @override
  String get m4VoiceSend => 'Send voice message';

  @override
  String get m4VoiceLockHint => 'Slide up to lock';

  @override
  String get m4VoiceMicDenied =>
      'Allow the microphone to record a voice message.';

  @override
  String get m4VoiceTooShort => 'Hold the microphone to record.';

  @override
  String get m4MediaErrorTooLarge => 'File too large.';

  @override
  String get m4MediaErrorTooLong => 'Too long to be sent.';

  @override
  String get m4MediaErrorType => 'This file type is not accepted.';

  @override
  String get m4MediaErrorMissing => 'The file is no longer on the phone.';

  @override
  String get m4MediaErrorUnreadable => 'This file could not be prepared.';

  @override
  String get m4MediaUnavailable => 'Media unavailable';

  @override
  String get m4MediaUnsupportedKind =>
      'This kind of message is not supported yet.';

  @override
  String get m4LocationTitle => 'Send my location?';

  @override
  String get m4LocationLabelHint => 'Place name (optional)';

  @override
  String get m4LocationDisabled => 'Location is turned off on this phone.';

  @override
  String get m4LocationDenied =>
      'Allow location access to share your position.';

  @override
  String get m4LocationOpen => 'Open in Maps';

  @override
  String get m4LocationDefaultLabel => 'Shared location';

  @override
  String get m4ContactCall => 'Call';

  @override
  String get m4DocumentOpenFailed => 'This document could not be opened.';

  @override
  String get m4DocumentUnsupported => 'This file type cannot be sent.';

  @override
  String get m4CaptionHint => 'Add a caption…';

  @override
  String get m4Send => 'Send';

  @override
  String get m4Cancel => 'Cancel';

  @override
  String get m4SharedMedia => 'Shared media';

  @override
  String get m4QuoteVideo => 'Video';

  @override
  String get m4QuoteDocument => 'Document';

  @override
  String get m4QuoteLocation => 'Location';

  @override
  String get m4QuoteContact => 'Contact';

  @override
  String get sharedContentTitle => 'Media, links and docs';

  @override
  String get sharedContentMedia => 'Media';

  @override
  String get sharedContentLinks => 'Links';

  @override
  String get sharedContentDocs => 'Docs';

  @override
  String get sharedContentMediaEmpty => 'No photos or videos shared';

  @override
  String get sharedContentLinksEmpty => 'No links shared';

  @override
  String get sharedContentDocsEmpty => 'No documents shared';

  @override
  String qualityHoursPerGigabyte(int hours) {
    return '1 GB of data ≈ $hours h of listening';
  }

  @override
  String qualityHoursPerGigabyteAtLeast(int hours) {
    return '1 GB of data ≈ at least $hours h of listening';
  }

  @override
  String get qualityNowWifi => 'You are on wifi';

  @override
  String get qualityNowCellular => 'You are on mobile data';

  @override
  String get qualityNetworkEdge => 'Works even on 2G (EDGE)';

  @override
  String get qualityNetworkWeak => 'Decent 2G or 3G is enough';

  @override
  String get qualityNetwork3g => '3G is enough';

  @override
  String get qualityNetworkGood => 'Good 3G or 4G';

  @override
  String get qualityNetworkStrong => 'Needs 4G or wifi';

  @override
  String get qualityNetworkAdaptive =>
      'Any network: steps down by itself when it weakens';

  @override
  String get qualityNetworkListeningAuto =>
      'Thrifty on mobile data, full on wifi';

  @override
  String get qualitySoundVoice => 'Clear voice, muffled music';

  @override
  String get qualitySoundVoiceMusic => 'Crisp voice, decent music';

  @override
  String get qualitySoundClear => 'Crisp voice and music';

  @override
  String get qualitySoundFull => 'Full voice and music';

  @override
  String get qualitySoundAdaptive => 'The best your network allows';

  @override
  String get radioOfflineTitle => 'No network right now';

  @override
  String get radioOfflineMessage =>
      'The radio starts again on its own as soon as the network is back.';

  @override
  String get noteEditorPlaceholder => 'Write your note…';

  @override
  String get noteEditorOpenFormat => 'Formatting';

  @override
  String get noteEditorFormatTitle => 'Format';

  @override
  String get noteEditorClose => 'Close';

  @override
  String get noteEditorStyleTitle => 'Title';

  @override
  String get noteEditorStyleSubtitle => 'Heading';

  @override
  String get noteEditorStyleHeading => 'Subheading';

  @override
  String get noteEditorStyleBody => 'Body';

  @override
  String get noteEditorBold => 'Bold';

  @override
  String get noteEditorItalic => 'Italic';

  @override
  String get noteEditorUnderline => 'Underline';

  @override
  String get noteEditorStrike => 'Strikethrough';

  @override
  String get noteEditorHighlight => 'Highlight';

  @override
  String get noteEditorTextColor => 'Text color';

  @override
  String get noteEditorBulletList => 'Bulleted list';

  @override
  String get noteEditorNumberedList => 'Numbered list';

  @override
  String get noteEditorChecklist => 'Checklist';

  @override
  String get noteEditorOutdent => 'Decrease indent';

  @override
  String get noteEditorIndent => 'Increase indent';

  @override
  String get noteEditorMonostyle => 'Monostyled';

  @override
  String get noteEditorQuote => 'Block quote';

  @override
  String get noteLinkAdd => 'Add a link';

  @override
  String get noteLinkSheetTitle => 'Add a link';

  @override
  String get noteLinkToNote => 'A note';

  @override
  String get noteLinkToTeaching => 'A teaching';

  @override
  String get noteLinkToWeb => 'A web address';

  @override
  String get noteLinkToBible => 'The Bible';

  @override
  String get noteLinkSearch => 'Search';

  @override
  String get noteLinkInvalidUrl => 'Invalid web address';

  @override
  String get noteLinkInsert => 'Insert link';

  @override
  String get noteLinkNoResult => 'No results';

  @override
  String get noteLinkNoteMissing => 'This note no longer exists';

  @override
  String get noteLinkCannotOpen => 'Unable to open this link';

  @override
  String get noteAttachmentButton => 'Attach';

  @override
  String get noteAttachmentChooseMedia => 'Choose Photo or Video';

  @override
  String get noteAttachmentTakeMedia => 'Take Photo or Video';

  @override
  String get noteAttachmentTakePhoto => 'Photo';

  @override
  String get noteAttachmentTakeVideo => 'Video';

  @override
  String get noteAttachmentRecordAudio => 'Record Audio';

  @override
  String get noteAttachmentAttachFile => 'Attach File';

  @override
  String get noteAttachmentRecording => 'Recording…';

  @override
  String get noteAttachmentRecordStop => 'Done';

  @override
  String get noteAttachmentRecordCancel => 'Cancel';

  @override
  String get noteAttachmentMicDenied => 'Allow the microphone to record audio.';

  @override
  String get noteAttachmentRecordingName => 'Audio recording';

  @override
  String get noteAttachmentPreparing => 'Preparing…';

  @override
  String get noteAttachmentUploading => 'Uploading…';

  @override
  String get noteAttachmentFailed => 'Upload failed';

  @override
  String get noteAttachmentRetry => 'Retry';

  @override
  String get noteAttachmentUnavailable => 'Attachment unavailable';

  @override
  String get bibleTabHome => 'Home';

  @override
  String get bibleTabBible => 'Bible';

  @override
  String get bibleTabFavorites => 'Favorites';

  @override
  String get bibleTabNotes => 'Notes';

  @override
  String get bibleTabMore => 'More';

  @override
  String get bibleBackToHome => 'Back to home';

  @override
  String get bibleOldTestament => 'Old Testament';

  @override
  String get bibleNewTestament => 'New Testament';

  @override
  String get bibleBookSearchHint => 'Quick book search';

  @override
  String get bibleNoBookFound => 'No matching book';

  @override
  String bibleChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String get bibleChooseChapter => 'Choose a chapter';

  @override
  String get bibleChooseVerse => 'Choose a verse';

  @override
  String bibleStartReading(String reference) {
    return 'Start $reference';
  }

  @override
  String get bibleSelectTitle => 'Choose a passage';

  @override
  String get bibleSelectHint => 'Tap verses to choose a passage';

  @override
  String bibleInsertReference(String reference) {
    return 'Insert $reference';
  }

  @override
  String get bibleChangeChapter => 'Change chapter';

  @override
  String get bibleVersionTooltip => 'Bible version';

  @override
  String get bibleChapterUnavailable =>
      'This chapter is not available in this version.';

  @override
  String get bibleSoonTitle => 'Coming soon';

  @override
  String get bibleHomeSoon =>
      'Verse of the day, Sunday passage, reading plans and quizzes will appear here.';

  @override
  String get bibleFavoritesSoon =>
      'Your favorite verses, marked chapters and highlights will be listed here.';

  @override
  String get bibleMoreSoon =>
      'Reading plans, quizzes, versions and settings will appear here.';

  @override
  String get bibleSearchTitle => 'Search';

  @override
  String get bibleSearchHint => 'A word, or a reference (jn 3 16)';

  @override
  String bibleSearchGoTo(String reference) {
    return 'Go to $reference';
  }

  @override
  String bibleSearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String get bibleSearchScopeAll => 'All';

  @override
  String get bibleSearchScopeOld => 'OT';

  @override
  String get bibleSearchScopeNew => 'NT';

  @override
  String get bibleSearchScopeBook => 'Book';

  @override
  String get bibleSearchMore => 'Show more';

  @override
  String get bibleSearchHistory => 'Recent searches';

  @override
  String get bibleSearchClearHistory => 'Clear';

  @override
  String get bibleSearchIndexing => 'Preparing search…';

  @override
  String get bibleSearchEmpty =>
      'Search a word in the Bible, or type a reference.';

  @override
  String get bibleSearchNoResults => 'No verse contains these words.';

  @override
  String get bibleSearchCompare => 'Compare versions';

  @override
  String get bibleSearchCompareTitle => 'Compared results';
}
