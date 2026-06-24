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
  String get navGroups => 'Groups';

  @override
  String get navProfile => 'Profile';

  @override
  String get announcementsTitle => 'Announcements';

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
  String get fieldFullName => 'Full name';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldLocalBranch => 'Local branch';

  @override
  String get registerTermsPrefix => 'By creating an account, you accept our ';

  @override
  String get registerTermsLink => 'Terms of use.';

  @override
  String homeGreeting(String name) {
    return 'Hello $name!';
  }

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
  String get sectionLatestTeachings => 'Latest teachings';

  @override
  String get mediaTitle => 'Media library';

  @override
  String get mediaSearchHint => 'Search for a teaching...';

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
  String get groupsTitle => 'My groups';

  @override
  String get groupsDiscoverMore => 'Discover more groups';

  @override
  String get communityTitle => 'Community';

  @override
  String get communityTabInbox => 'Inbox';

  @override
  String get communityTabRequests => 'Requests';

  @override
  String groupMembers(int count) {
    return '$count members';
  }

  @override
  String groupMembersWithRole(int count, String role) {
    return '$count members • $role';
  }

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
  String tabNotesCount(int count) {
    return 'Notes ($count)';
  }

  @override
  String get actionDownloadAudio => 'Download audio';

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
}
