import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ee.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ee'),
    Locale('en'),
    Locale('fr')
  ];

  /// Nom de l'application
  ///
  /// In fr, this message translates to:
  /// **'Maison du Miracle'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In fr, this message translates to:
  /// **'Nous annonçons avec foi.'**
  String get splashTagline;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias'**
  String get navMedia;

  /// No description provided for @navAnnouncements.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get navAnnouncements;

  /// No description provided for @navGroups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get navGroups;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @navAgenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get navAgenda;

  /// No description provided for @navDonations.
  ///
  /// In fr, this message translates to:
  /// **'Dons'**
  String get navDonations;

  /// No description provided for @announcementsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get announcementsTitle;

  /// Titre affiché quand aucun statut n'est publié
  ///
  /// In fr, this message translates to:
  /// **'Aucune annonce'**
  String get announcementsEmptyTitle;

  /// Explication de l'état vide des annonces
  ///
  /// In fr, this message translates to:
  /// **'Les annonces de l\'église apparaîtront ici.'**
  String get announcementsEmptyBody;

  /// Badge signalant un statut vidéo
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get statusVideoBadge;

  /// Titre de la feuille listant les statuts
  ///
  /// In fr, this message translates to:
  /// **'Toutes les annonces'**
  String get statusListTitle;

  /// Bouton ouvrant la liste des statuts
  ///
  /// In fr, this message translates to:
  /// **'Voir toutes les annonces'**
  String get statusOpenList;

  /// Bouton coupant le son des statuts
  ///
  /// In fr, this message translates to:
  /// **'Couper le son'**
  String get statusMute;

  /// Bouton réactivant le son des statuts
  ///
  /// In fr, this message translates to:
  /// **'Activer le son'**
  String get statusUnmute;

  /// Horodatage relatif : moins d'une minute
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get timeJustNow;

  /// Horodatage relatif exprimé en minutes
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Il y a {count} minute} other{Il y a {count} minutes}}'**
  String timeMinutesAgo(int count);

  /// Horodatage relatif exprimé en heures
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Il y a {count} heure} other{Il y a {count} heures}}'**
  String timeHoursAgo(int count);

  /// Horodatage relatif : la veille
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get timeYesterday;

  /// Horodatage relatif exprimé en jours (moins d'une semaine)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Il y a {count} jour} other{Il y a {count} jours}}'**
  String timeDaysAgo(int count);

  /// No description provided for @onboardingWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get onboardingWelcome;

  /// No description provided for @onboardingTitleHighlight.
  ///
  /// In fr, this message translates to:
  /// **'Dans la Maison\ndu Miracle'**
  String get onboardingTitleHighlight;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Une communauté vivante, connectée et engagée pour la gloire de Dieu.'**
  String get onboardingSubtitle;

  /// No description provided for @actionNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get actionNext;

  /// No description provided for @onboardingVerse.
  ///
  /// In fr, this message translates to:
  /// **'« Venez à moi, vous tous qui êtes fatigués, et je vous donnerai du repos. »\n— Matthieu 11:28'**
  String get onboardingVerse;

  /// No description provided for @onboardingStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// No description provided for @onboardingJoinTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous rejoindre'**
  String get onboardingJoinTitle;

  /// No description provided for @onboardingJoinSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez comment continuer.'**
  String get onboardingJoinSubtitle;

  /// No description provided for @authPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get authPhone;

  /// No description provided for @authEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @actionJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get actionJoin;

  /// No description provided for @onboardingCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get onboardingCodeTitle;

  /// No description provided for @onboardingCodeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code que vous avez reçu.'**
  String get onboardingCodeSubtitle;

  /// No description provided for @onboardingCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification'**
  String get onboardingCodeHint;

  /// No description provided for @actionValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get actionValidate;

  /// No description provided for @onboardingAlreadyMember.
  ///
  /// In fr, this message translates to:
  /// **'Déjà membre ? '**
  String get onboardingAlreadyMember;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Heureux de vous revoir !'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour continuer.'**
  String get loginSubtitle;

  /// No description provided for @fieldEmailOrPhone.
  ///
  /// In fr, this message translates to:
  /// **'Email ou numéro'**
  String get fieldEmailOrPhone;

  /// No description provided for @fieldPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get fieldPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// No description provided for @actionLogin.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get actionLogin;

  /// No description provided for @orContinueWith.
  ///
  /// In fr, this message translates to:
  /// **'Ou continuer avec'**
  String get orContinueWith;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? '**
  String get noAccountYet;

  /// No description provided for @actionRegister.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get actionRegister;

  /// No description provided for @registerAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inscription'**
  String get registerAppBarTitle;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer votre compte'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez notre communauté.'**
  String get registerSubtitle;

  /// No description provided for @fieldPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get fieldPhone;

  /// No description provided for @fieldLocalBranch.
  ///
  /// In fr, this message translates to:
  /// **'Branche locale'**
  String get fieldLocalBranch;

  /// No description provided for @registerTermsPrefix.
  ///
  /// In fr, this message translates to:
  /// **'En créant un compte, vous acceptez nos '**
  String get registerTermsPrefix;

  /// No description provided for @registerTermsLink.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation.'**
  String get registerTermsLink;

  /// Salutation d'accueil
  ///
  /// In fr, this message translates to:
  /// **'Bonjour {name} !'**
  String homeGreeting(String name);

  /// Salutation d'accueil quand l'utilisateur n'a pas renseigné son nom
  ///
  /// In fr, this message translates to:
  /// **'Bonjour !'**
  String get homeGreetingNoName;

  /// No description provided for @homeBlessing.
  ///
  /// In fr, this message translates to:
  /// **'Que Dieu vous bénisse aujourd\'hui.'**
  String get homeBlessing;

  /// No description provided for @liveBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Culte en direct'**
  String get liveBannerTitle;

  /// No description provided for @liveBannerSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre maintenant'**
  String get liveBannerSubtitle;

  /// No description provided for @sectionUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get sectionUpcoming;

  /// No description provided for @sectionUpcomingServices.
  ///
  /// In fr, this message translates to:
  /// **'Cultes à venir'**
  String get sectionUpcomingServices;

  /// No description provided for @homeWatchLive.
  ///
  /// In fr, this message translates to:
  /// **'Regarder le direct'**
  String get homeWatchLive;

  /// No description provided for @actionSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get actionSeeAll;

  /// Bouton d'écoute d'un enseignement
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get actionListen;

  /// No description provided for @sectionLatestTeachings.
  ///
  /// In fr, this message translates to:
  /// **'Derniers enseignements'**
  String get sectionLatestTeachings;

  /// Rubrique d'accueil : les messages portés au culte dominical
  ///
  /// In fr, this message translates to:
  /// **'Messages du dimanche'**
  String get sectionSundayMessage;

  /// No description provided for @sectionBibleStudy.
  ///
  /// In fr, this message translates to:
  /// **'Études bibliques'**
  String get sectionBibleStudy;

  /// Rubrique d'accueil : enregistrements centrés sur la prière (veillées, intercession)
  ///
  /// In fr, this message translates to:
  /// **'Moments de prière'**
  String get sectionPrayerTimes;

  /// No description provided for @mediaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Médiathèque'**
  String get mediaTitle;

  /// No description provided for @mediaSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un enseignement...'**
  String get mediaSearchHint;

  /// No description provided for @mediaRecommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandés pour vous'**
  String get mediaRecommended;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get filterAll;

  /// No description provided for @filterSermons.
  ///
  /// In fr, this message translates to:
  /// **'Prêches'**
  String get filterSermons;

  /// No description provided for @filterTeachings.
  ///
  /// In fr, this message translates to:
  /// **'Enseignements'**
  String get filterTeachings;

  /// No description provided for @filterMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get filterMusic;

  /// No description provided for @seriesTag.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get seriesTag;

  /// No description provided for @seriesMessagesCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} messages'**
  String seriesMessagesCount(int count);

  /// No description provided for @groupsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes groupes'**
  String get groupsTitle;

  /// No description provided for @groupsDiscoverMore.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir plus de groupes'**
  String get groupsDiscoverMore;

  /// No description provided for @communityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get communityTitle;

  /// No description provided for @communityTabInbox.
  ///
  /// In fr, this message translates to:
  /// **'Inbox'**
  String get communityTabInbox;

  /// No description provided for @communityTabRequests.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes'**
  String get communityTabRequests;

  /// No description provided for @groupMembers.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres'**
  String groupMembers(int count);

  /// No description provided for @groupMembersWithRole.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres • {role}'**
  String groupMembersWithRole(int count, String role);

  /// No description provided for @chatMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre message...'**
  String get chatMessageHint;

  /// No description provided for @chatToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get chatToday;

  /// No description provided for @teachingAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Enseignement'**
  String get teachingAppBarTitle;

  /// No description provided for @actionDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get actionDownload;

  /// No description provided for @actionMyNotes.
  ///
  /// In fr, this message translates to:
  /// **'Mes notes'**
  String get actionMyNotes;

  /// No description provided for @actionShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get actionShare;

  /// No description provided for @tabDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get tabDescription;

  /// No description provided for @teachingVerses.
  ///
  /// In fr, this message translates to:
  /// **'Versets'**
  String get teachingVerses;

  /// No description provided for @tabNotesCount.
  ///
  /// In fr, this message translates to:
  /// **'Notes ({count})'**
  String tabNotesCount(int count);

  /// No description provided for @actionDownloadAudio.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger l\'audio'**
  String get actionDownloadAudio;

  /// No description provided for @agendaSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout l\'agenda'**
  String get agendaSeeAll;

  /// No description provided for @weekdayMon.
  ///
  /// In fr, this message translates to:
  /// **'Lun'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In fr, this message translates to:
  /// **'Mar'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In fr, this message translates to:
  /// **'Mer'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In fr, this message translates to:
  /// **'Jeu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In fr, this message translates to:
  /// **'Ven'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In fr, this message translates to:
  /// **'Sam'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In fr, this message translates to:
  /// **'Dim'**
  String get weekdaySun;

  /// No description provided for @liveAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Culte en direct'**
  String get liveAppBarTitle;

  /// No description provided for @liveAudioOnly.
  ///
  /// In fr, this message translates to:
  /// **'Audio seul'**
  String get liveAudioOnly;

  /// No description provided for @liveQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get liveQuality;

  /// No description provided for @liveAboutTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos de ce live'**
  String get liveAboutTitle;

  /// No description provided for @liveAboutBody.
  ///
  /// In fr, this message translates to:
  /// **'Soyez bénis par la Parole de Dieu et restez connectés.'**
  String get liveAboutBody;

  /// No description provided for @liveConnectedPeople.
  ///
  /// In fr, this message translates to:
  /// **'{count} personnes connectées'**
  String liveConnectedPeople(String count);

  /// No description provided for @liveCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message...'**
  String get liveCommentHint;

  /// No description provided for @prayersAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Espace de prière'**
  String get prayersAppBarTitle;

  /// No description provided for @prayersTabMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes requêtes'**
  String get prayersTabMine;

  /// No description provided for @prayersTabCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get prayersTabCommunity;

  /// No description provided for @prayersNewRequest.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle requête'**
  String get prayersNewRequest;

  /// No description provided for @newRequestAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle requête'**
  String get newRequestAppBarTitle;

  /// No description provided for @newRequestTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type de requête'**
  String get newRequestTypeLabel;

  /// No description provided for @requestTypeSuggestion.
  ///
  /// In fr, this message translates to:
  /// **'Suggestion'**
  String get requestTypeSuggestion;

  /// No description provided for @requestTypeComplaint.
  ///
  /// In fr, this message translates to:
  /// **'Plainte'**
  String get requestTypeComplaint;

  /// No description provided for @requestTypeReport.
  ///
  /// In fr, this message translates to:
  /// **'Signalement'**
  String get requestTypeReport;

  /// No description provided for @requestTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get requestTypeOther;

  /// No description provided for @newRequestDescribeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre requête'**
  String get newRequestDescribeLabel;

  /// No description provided for @newRequestDescribeHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre message ici...'**
  String get newRequestDescribeHint;

  /// No description provided for @anonymousLabel.
  ///
  /// In fr, this message translates to:
  /// **'Anonyme'**
  String get anonymousLabel;

  /// No description provided for @anonymousSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre identité restera confidentielle.'**
  String get anonymousSubtitle;

  /// No description provided for @actionSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get actionSend;

  /// No description provided for @notesAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes notes'**
  String get notesAppBarTitle;

  /// No description provided for @notesSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une note...'**
  String get notesSearchHint;

  /// No description provided for @profileRole.
  ///
  /// In fr, this message translates to:
  /// **'Membre Nouvelle Vie'**
  String get profileRole;

  /// No description provided for @profileEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get profileEdit;

  /// No description provided for @profileStatServices.
  ///
  /// In fr, this message translates to:
  /// **'Cultes'**
  String get profileStatServices;

  /// No description provided for @profileStatNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get profileStatNotes;

  /// No description provided for @profileMyBranch.
  ///
  /// In fr, this message translates to:
  /// **'Ma branche'**
  String get profileMyBranch;

  /// No description provided for @profileMyContributions.
  ///
  /// In fr, this message translates to:
  /// **'Mes contributions'**
  String get profileMyContributions;

  /// No description provided for @profileMyNotes.
  ///
  /// In fr, this message translates to:
  /// **'Mes notes spirituelles'**
  String get profileMyNotes;

  /// No description provided for @darkMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode sombre'**
  String get darkMode;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @helpSupport.
  ///
  /// In fr, this message translates to:
  /// **'Aide & Support'**
  String get helpSupport;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @donationsAppBarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dons & Offrandes'**
  String get donationsAppBarTitle;

  /// No description provided for @donationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Soutenez l\'œuvre de Dieu'**
  String get donationsTitle;

  /// No description provided for @donationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Donnez selon ce que Dieu met dans votre cœur.'**
  String get donationsSubtitle;

  /// No description provided for @donationsAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get donationsAmountLabel;

  /// No description provided for @donationsPaymentMethodLabel.
  ///
  /// In fr, this message translates to:
  /// **'Méthode de paiement'**
  String get donationsPaymentMethodLabel;

  /// No description provided for @paymentCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte bancaire'**
  String get paymentCard;

  /// No description provided for @actionContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get actionContinue;

  /// No description provided for @donationsSecure.
  ///
  /// In fr, this message translates to:
  /// **'Vos dons sont sécurisés'**
  String get donationsSecure;

  /// Bouton d'entrée dans le parcours d'authentification
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get authStart;

  /// Lien vers le même écran identifiant (parcours unifié)
  ///
  /// In fr, this message translates to:
  /// **'Déjà membre ?'**
  String get authAlreadyMember;

  /// Titre de l'écran de saisie de l'identifiant
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez-nous'**
  String get authIdentifierTitle;

  /// Sous-titre de l'écran identifiant
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre numéro ou votre email pour continuer.'**
  String get authIdentifierSubtitle;

  /// Indication du champ téléphone (sans indicatif)
  ///
  /// In fr, this message translates to:
  /// **'90 12 34 56'**
  String get authPhoneHint;

  /// Indication du champ email
  ///
  /// In fr, this message translates to:
  /// **'jean.kossi@email.com'**
  String get authEmailHint;

  /// Bouton pour valider l'identifiant et demander le code
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authContinue;

  /// Séparateur au-dessus des boutons Google/Apple
  ///
  /// In fr, this message translates to:
  /// **'Ou continuer avec'**
  String get authOrContinueWith;

  /// Libellé du sélecteur d'indicatif téléphonique
  ///
  /// In fr, this message translates to:
  /// **'Indicatif'**
  String get authDialCode;

  /// Titre de l'écran de saisie du code
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get authCodeTitle;

  /// Sous-titre de l'écran code, avec la cible (téléphone/email)
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code à 6 chiffres envoyé à {target}.'**
  String authCodeSubtitle(String target);

  /// Bouton pour renvoyer le code de vérification
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authResend;

  /// Compte à rebours avant de pouvoir renvoyer le code
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer dans {seconds} s'**
  String authResendIn(int seconds);

  /// Erreur unique couvrant le code incorrect ET le code expiré : le serveur fusionne les deux cas dans un 422 générique, pour ne pas renseigner un attaquant sur l'état d'un code
  ///
  /// In fr, this message translates to:
  /// **'Code invalide ou expiré'**
  String get authCodeInvalid;

  /// Titre de l'écran de complétion / édition du profil
  ///
  /// In fr, this message translates to:
  /// **'Nous aimerions en savoir plus sur vous'**
  String get profileFormTitle;

  /// Sous-titre de l'écran profil (profil skippable)
  ///
  /// In fr, this message translates to:
  /// **'Ces informations restent facultatives et modifiables.'**
  String get profileFormSubtitle;

  /// Civilité : rendu de la clé UserTitle.brother
  ///
  /// In fr, this message translates to:
  /// **'Frère'**
  String get titleBrother;

  /// Civilité : rendu de la clé UserTitle.sister
  ///
  /// In fr, this message translates to:
  /// **'Sœur'**
  String get titleSister;

  /// Libellé du champ prénom (User.firstName, sans préfixe Frère/Sœur)
  ///
  /// In fr, this message translates to:
  /// **'Votre prénom'**
  String get fieldYourName;

  /// Libellé du sélecteur de branche
  ///
  /// In fr, this message translates to:
  /// **'Votre branche'**
  String get fieldYourBranch;

  /// Option : pas encore rattaché à une branche
  ///
  /// In fr, this message translates to:
  /// **'Je suis nouveau'**
  String get branchImNew;

  /// Le référentiel /sync/branches ne renvoie aucune branche
  ///
  /// In fr, this message translates to:
  /// **'Aucune branche à sélectionner pour le moment.'**
  String get branchesEmpty;

  /// Échec du chargement de /sync/branches : l'écran reste utilisable
  ///
  /// In fr, this message translates to:
  /// **'Liste des branches indisponible. Tu pourras la choisir plus tard.'**
  String get branchesUnavailable;

  /// Bouton pour sauter l'étape de complétion du profil
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get actionLater;

  /// Bouton d'enregistrement du profil
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get actionSave;

  /// Action ouvrant l'écran d'édition du profil
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon profil'**
  String get profileEditAction;

  /// Bannière douce invitant à compléter le profil
  ///
  /// In fr, this message translates to:
  /// **'Complétez votre profil'**
  String get profileIncompleteBanner;

  /// Bouton de la bannière de profil incomplet
  ///
  /// In fr, this message translates to:
  /// **'Compléter'**
  String get profileIncompleteBannerCta;

  /// Titre de la boîte de confirmation de déconnexion
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get logoutConfirmTitle;

  /// Message de confirmation de déconnexion
  ///
  /// In fr, this message translates to:
  /// **'Vous devrez saisir un nouveau code pour vous reconnecter.'**
  String get logoutConfirmMessage;

  /// Bouton d'annulation générique
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get actionCancel;

  /// Libellé du statut « nouveau » (non rattaché à une branche)
  ///
  /// In fr, this message translates to:
  /// **'Nouveau — pas encore rattaché'**
  String get statusNewLabel;

  /// Message d'erreur générique (échec inattendu d'une action)
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get errorGeneric;

  /// Libellé du champ civilité (Frère / Sœur) sur l'écran profil
  ///
  /// In fr, this message translates to:
  /// **'Civilité'**
  String get profileTitleLabel;

  /// Erreur de validation : civilité non sélectionnée
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez Frère ou Sœur'**
  String get profileTitleRequired;

  /// Erreur : trop de tentatives de saisie du code
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez plus tard.'**
  String get authCodeTooManyAttempts;

  /// Confirmation : un nouveau code de vérification a été envoyé
  ///
  /// In fr, this message translates to:
  /// **'Code renvoyé.'**
  String get authCodeResent;
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
      <String>['ee', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ee':
      return AppLocalizationsEe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
