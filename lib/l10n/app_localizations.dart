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

  /// Étiquette d'accessibilité du squelette de chargement (AppListSkeleton) : le squelette est purement visuel, c'est ce libellé que lit le lecteur d'écran
  ///
  /// In fr, this message translates to:
  /// **'Chargement en cours…'**
  String get stateLoading;

  /// Titre générique de l'état vide (AppEmptyState) quand l'écran n'a pas de libellé plus précis
  ///
  /// In fr, this message translates to:
  /// **'Rien à afficher'**
  String get stateEmptyTitle;

  /// Explication générique de l'état vide : la source a répondu et affirme qu'il n'y a rien
  ///
  /// In fr, this message translates to:
  /// **'Il n\'y a aucun contenu ici pour le moment.'**
  String get stateEmptyMessage;

  /// Marqueur générique de fin de parcours (variante endOfRange de AppEmptyState) : au-delà, la source n'affirme plus rien
  ///
  /// In fr, this message translates to:
  /// **'Fin de la liste'**
  String get stateEndOfList;

  /// Titre de l'état d'erreur (AppErrorState). Volontairement écrit comme une panne, jamais comme une absence de contenu : un écran vide faute de réseau ne doit pas se lire « il n'y a rien de prévu »
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue'**
  String get stateErrorTitle;

  /// Cause par défaut de l'état d'erreur, en langage humain — jamais un code HTTP ni un toString() d'exception
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le contenu. Vérifiez votre connexion internet, puis réessayez.'**
  String get stateErrorMessage;

  /// Cause de l'état d'erreur quand le serveur est joignable mais échoue (5xx), en langage humain
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond pas pour l\'instant. Réessayez dans un instant.'**
  String get stateErrorServerMessage;

  /// Action de l'état d'erreur : relance le chargement via le callback fourni par l'écran
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get stateRetry;

  /// Accueil, section « À venir » : le serveur a répondu et n'annonce aucune occurrence à partir de maintenant. À ne surtout pas confondre avec stateErrorTitle — un accueil vide faute de réseau doit se lire comme une panne, jamais comme un calendrier vide
  ///
  /// In fr, this message translates to:
  /// **'Aucun rassemblement à venir'**
  String get homeUpcomingEmptyTitle;

  /// Accueil, section « À venir » : explication du vide quand le serveur n'a annoncé aucune borne d'horizon
  ///
  /// In fr, this message translates to:
  /// **'Le calendrier n\'annonce rien pour le moment. Revenez bientôt.'**
  String get homeUpcomingEmptyMessage;

  /// Accueil, section « À venir » : le vide est borné par l'horizon annoncé par le serveur — au-delà de cette date il n'affirme rien, ce n'est donc pas « il n'y aura plus rien »
  ///
  /// In fr, this message translates to:
  /// **'Le calendrier n\'annonce rien jusqu\'au {date}.'**
  String homeUpcomingHorizonMessage(String date);

  /// Agenda : le mois consulté est réellement vide (le serveur a répondu). À ne surtout pas confondre avec stateErrorTitle
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement ce mois-ci'**
  String get agendaEmptyMonthTitle;

  /// Agenda : explication du mois sans événement
  ///
  /// In fr, this message translates to:
  /// **'Rien n\'est prévu pour cette période.'**
  String get agendaEmptyMonthMessage;

  /// Agenda : borne d'horizon exposée par l'API atteinte — au-delà, le serveur n'affirme rien. C'est une fin de parcours, pas une absence
  ///
  /// In fr, this message translates to:
  /// **'Fin du calendrier'**
  String get agendaHorizonTitle;

  /// Agenda : explication de la borne d'horizon
  ///
  /// In fr, this message translates to:
  /// **'Les événements plus lointains ne sont pas encore annoncés.'**
  String get agendaHorizonMessage;

  /// Agenda : infobulle et libellé d'accessibilité de la flèche de navigation vers le mois précédent
  ///
  /// In fr, this message translates to:
  /// **'Mois précédent'**
  String get agendaPreviousMonth;

  /// Agenda : infobulle et libellé d'accessibilité de la flèche vers le mois suivant. La flèche est grisée à la borne d'horizon
  ///
  /// In fr, this message translates to:
  /// **'Mois suivant'**
  String get agendaNextMonth;

  /// Agenda : libellé d'accessibilité d'une case de la grille. Les pastilles distinguent visuellement un événement de plusieurs ; ce libellé porte la même information au lecteur d'écran
  ///
  /// In fr, this message translates to:
  /// **'{day} — {count, plural, =0{aucun événement} one{{count} événement} other{{count} événements}}'**
  String agendaDaySummary(int day, int count);

  /// Détail d'un évènement : titre de la BrandAppBar. Générique — l'intitulé de l'évènement est déjà dans le corps de l'écran
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get eventDetailTitle;

  /// Détail d'un évènement : en-tête de la section description. La section entière disparaît quand `body` est absent (une prière hebdomadaire n'a rien à ajouter à son titre)
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get eventDetailAbout;

  /// Absence « contenu retiré » (ContentAbsence.retracted) : l'identifiant a été valide, il ne l'est plus — le serveur a dépublié ou reprogrammé le contenu (rétractation du flux delta, ADR-0025). Écrit comme un fait définitif, jamais comme une panne : il n'y a rien à réessayer
  ///
  /// In fr, this message translates to:
  /// **'Contenu retiré'**
  String get absenceRetractedTitle;

  /// Explication de l'absence « contenu retiré ». Répond à la seule question du fidèle : est-ce que ça revient ? Non
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n\'est plus disponible. Il a été retiré par l\'église.'**
  String get absenceRetractedMessage;

  /// Absence « pas encore synchronisé » (ContentAbsence.notSynced) : le magasin local n'a pas encore reçu ce contenu. À ne pas confondre avec absenceRetractedTitle — ici c'est une attente, le contenu existe probablement côté serveur. Pas encore câblé (arrive avec le magasin local)
  ///
  /// In fr, this message translates to:
  /// **'Pas encore synchronisé'**
  String get absenceNotSyncedTitle;

  /// Explication de l'absence « pas encore synchronisé » : dit quoi attendre et quand
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n\'est pas encore arrivé sur cet appareil. Il apparaîtra après la prochaine synchronisation.'**
  String get absenceNotSyncedMessage;

  /// Absence « pas encore de média » (ContentAbsence.noMedia) : le contenu est publié mais son fichier audio/vidéo n'est pas encore attaché. Pas encore câblé (arrive avec le lecteur média)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement à venir'**
  String get absenceNoMediaTitle;

  /// Explication de l'absence « pas encore de média » : le contenu existe, le fichier arrive
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement n\'est pas encore en ligne. Revenez d\'ici quelques jours.'**
  String get absenceNoMediaMessage;

  /// Absence « média indisponible hors ligne » (ContentAbsence.offlineMedia) : le média existe mais n'a pas été téléchargé et l'appareil est hors ligne. La seule des quatre qui se résout en retrouvant du réseau. Pas encore câblé
  ///
  /// In fr, this message translates to:
  /// **'Indisponible hors ligne'**
  String get absenceOfflineMediaTitle;

  /// Explication de l'absence « média indisponible hors ligne » : dit l'action qui débloque
  ///
  /// In fr, this message translates to:
  /// **'Cet enregistrement n\'a pas été téléchargé. Reconnectez-vous à internet pour l\'écouter.'**
  String get absenceOfflineMediaMessage;

  /// Action commune aux quatre absences (ContentAbsenceView) : rend la main sans éjecter le fidèle de l'écran qu'il avait ouvert
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get absenceBack;

  /// Écran de détail d'un rassemblement (concert, convention, formation, forum, croisade) : le mot en surtitre du lecteur. Jamais « Événement » — le calendrier (collection `events`) est une autre chose, des occurrences datées ; un rassemblement de médiathèque est un contenu enregistré
  ///
  /// In fr, this message translates to:
  /// **'Rassemblement'**
  String get gatheringAppBarTitle;

  /// Absence « contenu retiré » vue depuis l'écran de détail d'un rassemblement : dit de quoi on parle, là où absenceRetractedTitle reste générique
  ///
  /// In fr, this message translates to:
  /// **'Ce rassemblement n\'est plus disponible'**
  String get gatheringRetractedTitle;

  /// Explication du rassemblement retiré. Mentionne explicitement l'arrêt de la lecture : le son s'est coupé, il faut dire pourquoi
  ///
  /// In fr, this message translates to:
  /// **'Il a été retiré par l\'église. La lecture est arrêtée.'**
  String get gatheringRetractedMessage;

  /// Accueil : titre du bloc qui regroupe les rubriques de rassemblement, avant les rubriques du référentiel. Distingue les deux familles de la médiathèque à l'écran, comme deux collections les distinguent sur le fil
  ///
  /// In fr, this message translates to:
  /// **'Rassemblements'**
  String get sectionGatherings;

  /// Absence « contenu retiré » vue depuis l'écran de détail d'un enseignement : dit de quoi on parle, là où absenceRetractedTitle reste générique
  ///
  /// In fr, this message translates to:
  /// **'Cet enseignement n\'est plus disponible'**
  String get teachingRetractedTitle;

  /// Explication de l'enseignement retiré. Mentionne explicitement l'arrêt de la lecture : le son s'est coupé, il faut dire pourquoi
  ///
  /// In fr, this message translates to:
  /// **'Il a été retiré de la médiathèque. La lecture est arrêtée.'**
  String get teachingRetractedMessage;

  /// Visionneuse : bouton d'ouverture du composeur. **N'existe que si l'acteur appartient à au moins un compte officiel** (canComposeAnnouncementProvider) — pour l'écrasante majorité des fidèles, l'onglet reste une visionneuse sans aucune affordance d'écriture
  ///
  /// In fr, this message translates to:
  /// **'Publier une annonce'**
  String get composeAnnouncement;

  /// Composeur en création : titre de la BrandAppBar
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle annonce'**
  String get composerNewTitle;

  /// Composeur en modification : titre de la BrandAppBar. Un compte officiel est un espace éditorial collectif — un membre corrige toute annonce de ses comptes, pas seulement les siennes
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'annonce'**
  String get composerEditTitle;

  /// Composeur : libellé du sélecteur de compte officiel. Choisir le compte **est** choisir la portée — il n'y a pas de sélecteur de branche, le serveur la dérive du compte
  ///
  /// In fr, this message translates to:
  /// **'Publier au nom de'**
  String get composerAccountLabel;

  /// Composeur : libellé du champ titre. Facultatif — une annonce valide porte au moins un titre, un message ou une image
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get composerTitleLabel;

  /// Composeur : indication du champ titre
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get composerTitleHint;

  /// Composeur : libellé du champ corps
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get composerBodyLabel;

  /// Composeur : indication du champ corps
  ///
  /// In fr, this message translates to:
  /// **'Ce que l\'église doit savoir'**
  String get composerBodyHint;

  /// Composeur : libellé du sélecteur de teinte. Les fonds viennent du référentiel `status_backgrounds` avec leurs arrêts et leur encre déjà dérivés par le serveur ; l'application ne calcule aucune couleur
  ///
  /// In fr, this message translates to:
  /// **'Fond'**
  String get composerBackgroundLabel;

  /// Composeur : option « pas de fond choisi » du sélecteur de teinte. Le rendu retombe alors sur la teinte dérivée de l'identifiant de l'annonce
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get composerBackgroundNone;

  /// Composeur : libellé du bloc de dépôt d'image
  ///
  /// In fr, this message translates to:
  /// **'Image de fond'**
  String get composerImageLabel;

  /// Composeur : action ouvrant la photothèque
  ///
  /// In fr, this message translates to:
  /// **'Choisir une image'**
  String get composerImageAdd;

  /// Composeur : action remplaçant l'image déjà choisie
  ///
  /// In fr, this message translates to:
  /// **'Remplacer l\'image'**
  String get composerImageReplace;

  /// Composeur : action retirant l'image choisie **avant envoi**. Ne retire pas une image déjà publiée — le contrat serveur n'a pas de champ pour ça
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'image'**
  String get composerImageRemove;

  /// Composeur en modification : dit que l'annonce porte déjà une image côté serveur et qu'elle reste en place tant qu'on n'en dépose pas une autre
  ///
  /// In fr, this message translates to:
  /// **'Image déjà publiée conservée'**
  String get composerImageKept;

  /// Composeur : libellé du choix entre publier maintenant, programmer et brouillon — trois modes repliés sur le seul champ `published_at`
  ///
  /// In fr, this message translates to:
  /// **'Publication'**
  String get composerTimingLabel;

  /// Composeur : publier immédiatement. Le champ est **omis** de la requête, et c'est l'horloge du serveur qui fait foi — pas celle du téléphone, qui peut dériver
  ///
  /// In fr, this message translates to:
  /// **'Maintenant'**
  String get composerTimingNow;

  /// Composeur : publier à une date future
  ///
  /// In fr, this message translates to:
  /// **'Programmer'**
  String get composerTimingScheduled;

  /// Composeur : garder l'annonce sans la publier (`published_at` explicitement nul)
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get composerTimingDraft;

  /// Composeur : libellé de l'instant de publication programmée
  ///
  /// In fr, this message translates to:
  /// **'Date de publication'**
  String get composerScheduleLabel;

  /// Composeur : action ouvrant le sélecteur de date de publication
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date'**
  String get composerSchedulePick;

  /// Composeur : libellé de la date d'expiration, facultative
  ///
  /// In fr, this message translates to:
  /// **'Fin de publication'**
  String get composerExpiryLabel;

  /// Composeur : état par défaut de la fin de publication
  ///
  /// In fr, this message translates to:
  /// **'N\'expire jamais'**
  String get composerExpiryNever;

  /// Composeur : action ouvrant le sélecteur de date de fin
  ///
  /// In fr, this message translates to:
  /// **'Choisir une fin'**
  String get composerExpiryPick;

  /// Composeur : action supprimant la date de fin choisie
  ///
  /// In fr, this message translates to:
  /// **'Retirer la fin'**
  String get composerExpiryClear;

  /// Composeur : action d'envoi en création
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get composerPublish;

  /// Composeur : action d'envoi en modification
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get composerSave;

  /// Composeur en modification : action de suppression
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'annonce'**
  String get composerDelete;

  /// Boîte de confirmation de suppression : question
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette annonce ?'**
  String get composerDeleteConfirmTitle;

  /// Boîte de confirmation de suppression : conséquence. Dite en termes de lecteurs, pas de base de données
  ///
  /// In fr, this message translates to:
  /// **'Elle disparaîtra de l\'application de tous les fidèles.'**
  String get composerDeleteConfirmBody;

  /// Boîte de confirmation de suppression : action destructrice
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get composerDeleteConfirmAction;

  /// Composeur : aucun compte officiel utilisable n'est encore arrivé dans le magasin local, alors que l'appartenance, elle, y est. Une fenêtre de synchronisation, pas une erreur
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte disponible'**
  String get composerNoAccountTitle;

  /// Composeur : explication de l'absence de compte utilisable
  ///
  /// In fr, this message translates to:
  /// **'Vos comptes officiels ne sont pas encore arrivés sur cet appareil. Réessayez après la prochaine synchronisation.'**
  String get composerNoAccountBody;

  /// Composeur en modification : l'annonce n'est plus dans le magasin local — retirée par le serveur, ou supprimée par un autre membre du compte
  ///
  /// In fr, this message translates to:
  /// **'Annonce introuvable'**
  String get composerMissingTitle;

  /// Composeur en modification : explication de l'annonce disparue
  ///
  /// In fr, this message translates to:
  /// **'Elle a été retirée. Il n\'y a plus rien à modifier.'**
  String get composerMissingBody;

  /// Composeur : rien à publier. Une image seule — une affiche — est une annonce parfaitement valide, et c'est le cas le plus courant
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins un titre, un message ou une image.'**
  String get composerIssueNothing;

  /// Composeur : mode « programmer » retenu sans date
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la date de publication.'**
  String get composerIssueSchedule;

  /// Composeur : fin antérieure ou égale au début. Une annonce expirée à sa naissance n'aura jamais été lue
  ///
  /// In fr, this message translates to:
  /// **'La fin de publication doit venir après la publication.'**
  String get composerIssueExpiry;

  /// Échec d'écriture, pas de réponse du serveur. Publier exige le réseau : il n'y a ni file d'envoi ni brouillon local, et l'application doit le **dire** plutôt que d'échouer en silence
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get composerErrorNetworkTitle;

  /// Échec d'écriture réseau : dit l'action qui débloque, et rassure sur la saisie — qui n'est jamais perdue à l'écran
  ///
  /// In fr, this message translates to:
  /// **'Publier une annonce demande une connexion internet. Votre saisie est conservée : reconnectez-vous, puis réessayez.'**
  String get composerErrorNetworkBody;

  /// Échec d'écriture 403. Le chemin normal, pas un cas exotique : l'appartenance connue du téléphone est un confort d'affichage, jamais une autorisation, et le serveur revérifie à chaque écriture
  ///
  /// In fr, this message translates to:
  /// **'Vous ne publiez plus pour ce compte'**
  String get composerErrorForbiddenTitle;

  /// Échec d'écriture 403 : explique sans accuser, et donne le recours
  ///
  /// In fr, this message translates to:
  /// **'Le bureau de ce compte officiel a changé. Rapprochez-vous d\'un responsable si c\'est une erreur.'**
  String get composerErrorForbiddenBody;

  /// Échec d'écriture 422 : le serveur a répondu, mais le contenu ne passe pas
  ///
  /// In fr, this message translates to:
  /// **'Annonce refusée'**
  String get composerErrorRejectedTitle;

  /// Échec d'écriture 422 : repli quand le serveur n'a pas fourni de message
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas accepté cette annonce. Corrigez la saisie, puis réessayez.'**
  String get composerErrorRejectedBody;

  /// Échec d'écriture 404/410 : l'annonce a disparu entre l'ouverture et l'envoi
  ///
  /// In fr, this message translates to:
  /// **'Annonce introuvable'**
  String get composerErrorGoneTitle;

  /// Échec d'écriture 404/410 : nomme la cause la plus probable — un compte officiel est un espace éditorial collectif
  ///
  /// In fr, this message translates to:
  /// **'Elle a été supprimée entre-temps, peut-être par un autre membre du compte.'**
  String get composerErrorGoneBody;

  /// Échec d'écriture 5xx : le serveur est joignable, ce n'est pas la connexion de l'auteur
  ///
  /// In fr, this message translates to:
  /// **'Serveur indisponible'**
  String get composerErrorServerTitle;

  /// Échec d'écriture 5xx : dit qu'attendre peut suffire
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond pas correctement. Réessayez dans un instant.'**
  String get composerErrorServerBody;

  /// Échec d'écriture 401 : le token n'est plus valide. La purge et le retour à l'authentification sont déjà déclenchés globalement — inutile de proposer « Réessayer »
  ///
  /// In fr, this message translates to:
  /// **'Session expirée'**
  String get composerErrorUnauthorizedTitle;

  /// Échec d'écriture 401 : la seule action utile
  ///
  /// In fr, this message translates to:
  /// **'Reconnectez-vous pour publier.'**
  String get composerErrorUnauthorizedBody;

  /// Confirmation après création. L'annonce apparaîtra au mur une fois ramenée par le flux delta — le composeur n'écrit jamais dans le magasin local
  ///
  /// In fr, this message translates to:
  /// **'Annonce publiée'**
  String get composerPublished;

  /// Confirmation après modification
  ///
  /// In fr, this message translates to:
  /// **'Annonce mise à jour'**
  String get composerUpdated;

  /// Confirmation après suppression
  ///
  /// In fr, this message translates to:
  /// **'Annonce supprimée'**
  String get composerDeleted;

  /// Visionneuse : action de modification du statut affiché. N'existe que si ce statut appartient à l'un de mes comptes officiels
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'annonce'**
  String get statusEdit;

  /// Visionneuse : action de suppression du statut affiché
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'annonce'**
  String get statusDelete;
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
