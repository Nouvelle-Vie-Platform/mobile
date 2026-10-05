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

  /// Nom **affiché** de l'application — celui que le fidèle lit sous l'icône, et le seul des trois noms du dépôt qui bouge. Il porte déjà « Nouvelle Vie » dans `android:label` et `CFBundleDisplayName` ; cette clé-ci disait encore « Maison du Miracle », et l'écran de démarrage le montrait. Ni le nom du paquet Dart (`maison_du_miracle`) ni l'identifiant d'application (`com.maisondumiracle.*`) ne sont concernés — voir « L'identité de l'application » dans CLAUDE.md. Le nom de l'**église**, lui, vit dans `aboutChurchName`
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle Vie'**
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

  /// Bottom nav + titre du hub de conversations « Échanges » (ex-« Groupes »). Une seule clé : l'onglet pilule a disparu, elle ne sert plus que la barre de nav et le titre de la page
  ///
  /// In fr, this message translates to:
  /// **'Échanges'**
  String get navGroups;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// La Bible : titre de son écran, et infobulle de l'icône en haut à droite de l'accueil qui l'ouvre. N'est plus un onglet de la barre du bas
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get navBible;

  /// Placeholder d'un écran pas encore livré (écran Bible)
  ///
  /// In fr, this message translates to:
  /// **'Page en construction'**
  String get pageUnderConstruction;

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

  /// Annonce, sur l'écran du code, de la barrière de consentement qui suit. RÉÉCRITE en #56 : « En créant un compte, vous acceptez nos… » était la formule de l'acceptation IMPLICITE, devenue fausse sous consentement explicite tracé — l'accord n'est plus déduit de la création du compte, il est donné à la barrière
  ///
  /// In fr, this message translates to:
  /// **'Après la vérification, il vous sera demandé d\'accepter nos '**
  String get registerTermsPrefix;

  /// Suite de registerTermsPrefix, mise en valeur. Elle ne mène nulle part et ce n'est pas un oubli : /legal/:kind est hors des emplacements autorisés avant authentification, la garde y renverrait vers /auth. Les DEUX documents y sont nommés — la barrière peut en exiger deux
  ///
  /// In fr, this message translates to:
  /// **'conditions d\'utilisation et notre politique de confidentialité.'**
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

  /// Le nom de l'antenne — libellé fixe du bouton d'accueil (dans tous les états), titre de l'écran, et ligne annoncée à l'écran verrouillé. Nom propre : identique dans les trois langues
  ///
  /// In fr, this message translates to:
  /// **'New Life Radio'**
  String get radioTitle;

  /// Écran /radio : la route publique a répondu que l'antenne ne diffuse pas (onAir à false, jamais à null). L'écoute reste possible — l'information guide, elle n'interdit pas
  ///
  /// In fr, this message translates to:
  /// **'Hors antenne'**
  String get radioOffAir;

  /// Écran /radio : le son de l'antenne sort vraiment (RadioPhase.playing). Pas « En direct » depuis #135 : ce mot-là est réservé au badge d'un direct de la régie (radioLiveBadge), et la radio tourne 24 h/24 sans direct
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne'**
  String get radioLive;

  /// Écran /radio pendant la reprise (les six attentes) : il dit qu'il réessaie, sans nommer la panne qu'il combat encore
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle tentative…'**
  String get radioRetrying;

  /// Écran /radio, cause de l'abandon : rien n'a répondu (DNS, socket refusée, délai dépassé)
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre connexion'**
  String get radioFailureConnection;

  /// Écran /radio : quelque chose a répondu et ce n'était pas une playlist (404, 401, page HTML) — cause de l'abandon, et titre de l'écran quand la route d'antenne ne donne aucune adresse de flux
  ///
  /// In fr, this message translates to:
  /// **'Antenne indisponible'**
  String get radioFailureAntenna;

  /// Écran /radio, cause de l'abandon quand on ignore s'il y a eu une réponse — la panne du lecteur iOS n'en porte aucune trace lisible. Ne nomme ni le réseau ni l'antenne : affirmer l'un des deux serait inventer la moitié du diagnostic
  ///
  /// In fr, this message translates to:
  /// **'Écoute impossible'**
  String get radioFailureUnknown;

  /// Écran /radio, sous la cause de l'abandon : vrai pour les trois causes, il dit qu'on a renoncé et que le geste appartient à l'auditeur
  ///
  /// In fr, this message translates to:
  /// **'L\'application a cessé de réessayer. Relancez l\'écoute quand vous voulez.'**
  String get radioGaveUpMessage;

  /// Écran d'antenne quand aucune adresse de flux n'est connue
  ///
  /// In fr, this message translates to:
  /// **'New Life Radio ne diffuse pas pour le moment.'**
  String get radioUnavailableMessage;

  /// Message bref à l'accueil, au premier son d'un lancement réussi depuis le bouton radio (jamais à l'échec, jamais pour un lancement venu d'ailleurs) : il fait découvrir l'appui long
  ///
  /// In fr, this message translates to:
  /// **'Astuce : un appui long sur ce bouton ouvre le live à tout moment.'**
  String get radioLongPressTip;

  /// Indice d'accessibilité de l'appui long sur le bouton radio de l'accueil — le lecteur d'écran le lit après sa propre consigne (« touchez deux fois et maintenez pour… »)
  ///
  /// In fr, this message translates to:
  /// **'ouvrir le live'**
  String get radioOpenLiveHint;

  /// Page live : badge du direct (une régie tient l'antenne). Affiché seulement pendant un direct — jamais pour dire que le son sort. Capitales voulues
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get radioLiveBadge;

  /// Page live : le compteur d'auditeurs, affiché seulement quand le serveur rend un nombre (au-dessus du seuil réglé au portail, 10 par défaut)
  ///
  /// In fr, this message translates to:
  /// **'{count} à l\'écoute'**
  String radioListeners(int count);

  /// Page live : libellé d'accessibilité du bouton de réaction ❤️
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un cœur'**
  String get radioReactionHeart;

  /// Page live : libellé d'accessibilité du bouton de réaction 🙏
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une prière'**
  String get radioReactionPray;

  /// Page live : libellé d'accessibilité du bouton de réaction 🙌
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une louange'**
  String get radioReactionPraise;

  /// Page live : libellé d'accessibilité du bouton de réaction 🔥
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une flamme'**
  String get radioReactionFire;

  /// Page live : la réaction « Amen », rendue en mot sur son bouton (les quatre autres sont des emojis). Court : il tient dans un bouton rond
  ///
  /// In fr, this message translates to:
  /// **'Amen'**
  String get radioReactionAmen;

  /// Page live : libellé d'accessibilité du bouton « Amen »
  ///
  /// In fr, this message translates to:
  /// **'Dire Amen'**
  String get radioReactionAmenLabel;

  /// Page live : nom du fil de commentaires pour le lecteur d'écran
  ///
  /// In fr, this message translates to:
  /// **'Commentaires du direct'**
  String get radioCommentsLabel;

  /// Page live : un commentaire lu par le lecteur d'écran — l'auteur puis le texte
  ///
  /// In fr, this message translates to:
  /// **'{name} : {body}'**
  String radioCommentSemantics(String name, String body);

  /// Page live : indice d'accessibilité de l'appui long sur un commentaire (signaler, et pour un modérateur masquer, réduire au silence, réinitialiser le pseudo)
  ///
  /// In fr, this message translates to:
  /// **'options du message'**
  String get radioMessageOptionsHint;

  /// Page live : pastille qui ramène en bas du fil quand l'auditeur est remonté et que des messages arrivent
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux messages'**
  String get radioNewMessages;

  /// Page live : texte indicatif du champ de commentaire (pendant un direct seulement)
  ///
  /// In fr, this message translates to:
  /// **'Écrire…'**
  String get radioCommentHint;

  /// Page live : remplace le champ de saisie quand le porteur a été réduit au silence
  ///
  /// In fr, this message translates to:
  /// **'Un modérateur a suspendu vos commentaires jusqu\'à la fin du direct.'**
  String get radioSilencedNotice;

  /// Page live : refus d'un commentaire hors direct (409 E_RADIO_COMMENTS_CLOSED)
  ///
  /// In fr, this message translates to:
  /// **'Le direct est terminé : les commentaires sont fermés.'**
  String get radioCommentClosed;

  /// Page live : refus d'un commentaire trop rapproché (429)
  ///
  /// In fr, this message translates to:
  /// **'Doucement : un message toutes les cinq secondes.'**
  String get radioCommentThrottled;

  /// Page live : refus d'un commentaire vide ou trop long (422)
  ///
  /// In fr, this message translates to:
  /// **'Votre message doit faire de 1 à 200 caractères.'**
  String get radioCommentInvalid;

  /// Page live : échec d'envoi d'un commentaire sans cause lisible (réseau, réponse inattendue)
  ///
  /// In fr, this message translates to:
  /// **'Message non envoyé. Réessayez.'**
  String get radioCommentFailed;

  /// Page live : titre du formulaire qui s'ouvre quand un invité écrit ou signale pour la première fois (403 E_RADIO_PSEUDONYM_REQUIRED)
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un pseudo'**
  String get radioPseudonymTitle;

  /// Page live : sous le titre du formulaire de pseudo
  ///
  /// In fr, this message translates to:
  /// **'Il s\'affichera à côté de vos messages pendant les directs.'**
  String get radioPseudonymMessage;

  /// Page live : texte indicatif du champ de pseudo
  ///
  /// In fr, this message translates to:
  /// **'Votre pseudo'**
  String get radioPseudonymHint;

  /// Page live : bouton du formulaire de pseudo — enregistre, puis renvoie le message
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get radioPseudonymConfirm;

  /// Page live : pseudo refusé (422 E_RADIO_PSEUDONYM_INVALID, ou vérifié avant l'envoi)
  ///
  /// In fr, this message translates to:
  /// **'Entre 2 et 24 caractères.'**
  String get radioPseudonymInvalid;

  /// Page live : pseudo refusé pour trop d'essais (429, 5 par heure)
  ///
  /// In fr, this message translates to:
  /// **'Trop d\'essais. Réessayez plus tard.'**
  String get radioPseudonymThrottled;

  /// Page live : échec de l'enregistrement du pseudo sans cause lisible
  ///
  /// In fr, this message translates to:
  /// **'Pseudo non enregistré. Réessayez.'**
  String get radioPseudonymFailed;

  /// Page live : action de l'appui long sur un commentaire, pour tout auditeur
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce message'**
  String get radioReportAction;

  /// Page live : signalement accepté — le message reste visible jusqu'à la décision d'un modérateur
  ///
  /// In fr, this message translates to:
  /// **'Merci, un modérateur va le regarder.'**
  String get radioReported;

  /// Page live : 409 E_RADIO_COMMENT_ALREADY_REPORTED
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà signalé ce message.'**
  String get radioAlreadyReported;

  /// Page live : le message a été masqué entre-temps, ou le direct est fini (404 / 409)
  ///
  /// In fr, this message translates to:
  /// **'Ce message n\'est plus disponible.'**
  String get radioMessageGone;

  /// Page live : échec d'un signalement ou d'un geste de modération sans cause lisible
  ///
  /// In fr, this message translates to:
  /// **'Action impossible. Réessayez.'**
  String get radioActionFailed;

  /// Page live, modérateur : masquer un message (il disparaît du fil de tous)
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get radioModHide;

  /// Page live, modérateur : garder un message signalé (il quitte la file, reste au fil)
  ///
  /// In fr, this message translates to:
  /// **'Garder'**
  String get radioModKeep;

  /// Page live, modérateur : empêcher l'auteur d'écrire jusqu'à la fin du direct. Rien n'est annoncé à l'audience
  ///
  /// In fr, this message translates to:
  /// **'Réduire au silence'**
  String get radioModSilence;

  /// Page live, modérateur : obliger un invité à choisir un autre pseudo (invités seulement)
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le pseudo'**
  String get radioModResetPseudonym;

  /// Page live, modérateur : confirmation du masquage
  ///
  /// In fr, this message translates to:
  /// **'Message masqué.'**
  String get radioModHidden;

  /// Page live, modérateur : confirmation après « Garder »
  ///
  /// In fr, this message translates to:
  /// **'Message gardé.'**
  String get radioModKept;

  /// Page live, modérateur : confirmation du silence
  ///
  /// In fr, this message translates to:
  /// **'Auteur réduit au silence jusqu\'à la fin du direct.'**
  String get radioModSilenced;

  /// Page live, modérateur : confirmation de la réinitialisation
  ///
  /// In fr, this message translates to:
  /// **'Pseudo réinitialisé.'**
  String get radioModPseudonymReset;

  /// Page live, modérateur : 409 E_RADIO_COMMENT_AUTHOR_NOT_GUEST
  ///
  /// In fr, this message translates to:
  /// **'Seul le pseudo d\'un invité peut être réinitialisé.'**
  String get radioModNotGuest;

  /// Page live, modérateur : titre de la file des signalements, et libellé du bouton qui l'ouvre
  ///
  /// In fr, this message translates to:
  /// **'Messages signalés'**
  String get radioReportedQueue;

  /// Page live, modérateur : nombre de signalements en attente sur un message
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 signalement} other{{count} signalements}}'**
  String radioReportedCount(int count);

  /// Page live, modérateur : la file des signalements est vide
  ///
  /// In fr, this message translates to:
  /// **'Aucun message en attente.'**
  String get radioReportedEmpty;

  /// Page live : libellé d'accessibilité du bouton d'arrêt (il arrête l'antenne et ferme la page)
  ///
  /// In fr, this message translates to:
  /// **'Arrêter l\'écoute'**
  String get radioStopListening;

  /// No description provided for @actionSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get actionSeeAll;

  /// Bouton d'écoute d'un message
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get actionListen;

  /// No description provided for @actionPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get actionPause;

  /// No description provided for @actionLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get actionLoading;

  /// Accueil : titre de la section des contenus les plus récents. La clé garde son nom historique ; le libellé, lui, ne nomme plus un type de contenu — « publications » couvre ce que la section mélange déjà
  ///
  /// In fr, this message translates to:
  /// **'Dernières publications'**
  String get sectionLatestTeachings;

  /// No description provided for @mediaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Médiathèque'**
  String get mediaTitle;

  /// No description provided for @mediaSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un message...'**
  String get mediaSearchHint;

  /// Médiathèque : le libellé du dépôt de l'entrée de menu indélébile — le catalogue entier, sans filtre (public.nav.mediatheque). Le portail peut le surcharger ; cette valeur est ce qu'affiche une application qui n'a pas encore synchronisé
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get filterAll;

  /// Médiathèque : libellé de l'onglet des messages. La clé garde son nom historique, le libellé dit « Messages »
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get filterTeachings;

  /// Étiquette posée sur un regroupement de messages. La clé garde son nom historique ; le mot affiché est « Thème », plus « Série »
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get seriesTag;

  /// Nombre de messages d'un thème, affiché sous l'étiquette seriesTag. Disait déjà « messages » avant le renommage, et le reste : un thème compte des messages, il n'en est pas un — aucune redondance avec seriesTag
  ///
  /// In fr, this message translates to:
  /// **'{count} messages'**
  String seriesMessagesCount(int count);

  /// No description provided for @groupsDiscoverMore.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir plus de groupes'**
  String get groupsDiscoverMore;

  /// Titre affiché en tête du hub « Échanges » (dans le bandeau diagonal). Même mot que navGroups, clé distincte : l'un titre la page, l'autre la barre de nav
  ///
  /// In fr, this message translates to:
  /// **'Échanges'**
  String get communityTitle;

  /// Hub Échanges : en-tête de la rangée horizontale de découverte (groupes à rejoindre), distincte de la liste des conversations
  ///
  /// In fr, this message translates to:
  /// **'Groupes à rejoindre'**
  String get echangesDiscover;

  /// Hub Échanges : sous-titre d'une carte de groupe à rejoindre — l'animateur du groupe
  ///
  /// In fr, this message translates to:
  /// **'Animé par {name}'**
  String echangesHostedBy(String name);

  /// Titre de l'écran Requêtes, ouvert par le bouton en haut à droite du hub Échanges (et tooltip de ce bouton)
  ///
  /// In fr, this message translates to:
  /// **'Requêtes'**
  String get requestsTitle;

  /// Écran Requêtes : titre de l'état vide (aucune requête envoyée pour l'instant)
  ///
  /// In fr, this message translates to:
  /// **'Aucune requête'**
  String get requestsEmptyTitle;

  /// Écran Requêtes : explication de l'état vide
  ///
  /// In fr, this message translates to:
  /// **'Vos requêtes et suggestions apparaîtront ici.'**
  String get requestsEmpty;

  /// Écran Requêtes : bouton d'ajout, ouvre le formulaire existant de nouvelle requête
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle requête'**
  String get requestsAdd;

  /// Écran profil-membre : bouton qui démarre une conversation directe avec ce membre
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get memberMessage;

  /// Fiche membre : statut sous le nom
  ///
  /// In fr, this message translates to:
  /// **'Membre de la communauté'**
  String get memberProfileSubtitle;

  /// Fiche de groupe : intitulé de la section description
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get groupInfoAbout;

  /// Fiche de groupe : intitulé de la section des médias partagés
  ///
  /// In fr, this message translates to:
  /// **'Médias partagés'**
  String get groupInfoSharedMedia;

  /// Visionneuse : confirmation d'enregistrement d'un média
  ///
  /// In fr, this message translates to:
  /// **'Image enregistrée dans vos photos'**
  String get mediaSaved;

  /// Visionneuse : permission galerie refusée
  ///
  /// In fr, this message translates to:
  /// **'Accès aux photos refusé. Autorisez-le dans les réglages.'**
  String get mediaSaveErrorPermission;

  /// Visionneuse : panne réseau au téléchargement
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement. Vérifiez votre connexion.'**
  String get mediaSaveErrorNetwork;

  /// Visionneuse : plateforme non supportée (web)
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement indisponible sur cet appareil.'**
  String get mediaSaveErrorUnsupported;

  /// Visionneuse : échec d'enregistrement inattendu
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer l\'image.'**
  String get mediaSaveError;

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

  /// Fil de discussion : ligne d'auteur d'un message dont l'auteur a supprimé son compte (ADR-0032, couple (authorId: null, isSystem: false)). Ce n'est PAS un nom de repli, c'est un fait — et il ne doit jamais être passé à AppAvatar(name:), qui en tirerait les initiales « MR » et une teinte dérivée de la longueur du libellé
  ///
  /// In fr, this message translates to:
  /// **'Membre retiré'**
  String get chatAuthorRemoved;

  /// Fil de discussion : remplace la barre de saisie quand le groupe est en diffusion (postPolicy=admins), sous verrou d'écriture, ou désactivé. Une phrase, jamais un champ grisé : une option désactivée reste une option offerte
  ///
  /// In fr, this message translates to:
  /// **'Seuls les animateurs peuvent écrire dans ce groupe.'**
  String get chatReadOnly;

  /// Fil de discussion : état vide d'un groupe dont le magasin n'a encore reçu aucun message
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour l\'instant. Soyez le premier à écrire.'**
  String get chatEmpty;

  /// Hub Échanges : titre de l'état vide (le magasin n'a pas encore reçu mes groupes, ou je n'appartiens à aucun)
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation'**
  String get echangesEmptyTitle;

  /// Hub Échanges : explication de l'état vide, qui nomme le geste de rattrapage (le réveil push est de la tranche 2)
  ///
  /// In fr, this message translates to:
  /// **'Vos groupes et discussions apparaîtront ici. Tirez vers le bas pour rafraîchir.'**
  String get echangesEmpty;

  /// Hub Échanges : échec de lecture du magasin local. C'est une base illisible, pas une panne de réseau
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire vos conversations.'**
  String get echangesLoadError;

  /// Carte d'un groupe à rejoindre : politique d'adhésion « open » — on entre sans demander
  ///
  /// In fr, this message translates to:
  /// **'Ouvert à tous'**
  String get echangesJoinOpen;

  /// Carte d'un groupe à rejoindre : politique d'adhésion « request » — un animateur approuve
  ///
  /// In fr, this message translates to:
  /// **'Sur demande'**
  String get echangesJoinOnRequest;

  /// Carte d'un groupe à rejoindre : ma demande est en attente (group_join_requests.status = pending). On le dit plutôt que de proposer un geste déjà fait
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get echangesJoinPending;

  /// Fiche de groupe : rôle « leader » d'un membre
  ///
  /// In fr, this message translates to:
  /// **'Animateur'**
  String get groupRoleLeader;

  /// Fiche de groupe : rôle « moderator » d'un membre
  ///
  /// In fr, this message translates to:
  /// **'Modérateur'**
  String get groupRoleModerator;

  /// Fiche de groupe : rôle « member », et repli de tout rôle que le serveur ajouterait — une chaîne brute à l'écran se lirait comme une donnée perdue
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get groupRoleMember;

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

  /// Fil de discussion : séparateur posé avant le premier message non lu, à l'ouverture (#140). Il reste à sa place tant que le fil est ouvert, même quand la lecture avance
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} message non lu} other{{count} messages non lus}}'**
  String chatUnreadSeparator(int count);

  /// Fil de discussion : corps d'un message-média (vocal, image) dont le texte est nul (#140, piège 1). Jamais une bulle vide : la personne doit savoir qu'un message est là
  ///
  /// In fr, this message translates to:
  /// **'Ce message contient un média que cette version de l\'application ne sait pas encore afficher.'**
  String get chatMediaUnsupported;

  /// Hub Échanges : aperçu d'une conversation dont le dernier message est un média (texte nul, #140)
  ///
  /// In fr, this message translates to:
  /// **'Pièce jointe'**
  String get echangesMediaPreview;

  /// Fil de discussion : sous une bulle à moi dont l'envoi a échoué. Le toucher ouvre Réessayer / Supprimer (#140). Le renvoi est aussi automatique au retour du réseau
  ///
  /// In fr, this message translates to:
  /// **'Non envoyé. Touchez pour réessayer.'**
  String get chatMessageFailed;

  /// Fil de discussion : feuille d'actions d'un message non envoyé — le renvoyer, sous la même clé (jamais de doublon)
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get chatRetry;

  /// Fil de discussion : feuille d'actions d'un message non envoyé — l'abandonner (rien ne part au serveur)
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get chatDiscard;

  /// Libellé d'accessibilité de la pastille de non-lus (onglet Échanges et tuile d'une conversation, #140). Le chiffre seul est affiché, la phrase est lue
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} message non lu} other{{count} messages non lus}}'**
  String echangesUnreadBadge(int count);

  /// Titre de la barre de l'écran de détail d'un message. La clé garde son nom historique
  ///
  /// In fr, this message translates to:
  /// **'Message'**
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

  /// Crédit des invités d'un contenu, sur l'écran de détail seulement (#77). Ne nomme QUE les invités : l'animateur est déjà affiché sous le titre, et « animé par » ne se dirait pas d'un prédicateur. Pas d'invité, pas de ligne — jamais de libellé de remplacement
  ///
  /// In fr, this message translates to:
  /// **'Avec {names}'**
  String contentGuests(String names);

  /// Conjonction de la dernière paire d'une énumération, assemblée en Dart (utils/name_list.dart) : un ARB sait accueillir une liste, il ne sait pas l'énumérer
  ///
  /// In fr, this message translates to:
  /// **'et'**
  String get listAnd;

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

  /// Bouton de téléchargement, état en cours : accessibilité de l'anneau de progression. Le pourcentage s'affiche à côté
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement en cours'**
  String get downloadStateDownloading;

  /// Pourcentage de progression d'un téléchargement en cours
  ///
  /// In fr, this message translates to:
  /// **'{percent} %'**
  String downloadProgressPercent(int percent);

  /// No description provided for @downloadStatePaused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get downloadStatePaused;

  /// Bouton de téléchargement : wifi seulement actif et l'appareil est en données mobiles (F8)
  ///
  /// In fr, this message translates to:
  /// **'En attente de wifi'**
  String get downloadStateWaitingWifi;

  /// No description provided for @downloadStateComplete.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get downloadStateComplete;

  /// No description provided for @downloadStateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement'**
  String get downloadStateFailed;

  /// No description provided for @downloadActionPause.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en pause'**
  String get downloadActionPause;

  /// No description provided for @downloadActionResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre le téléchargement'**
  String get downloadActionResume;

  /// No description provided for @downloadActionRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer le téléchargement'**
  String get downloadActionRetry;

  /// No description provided for @downloadActionDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get downloadActionDelete;

  /// No description provided for @downloadDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement ?'**
  String get downloadDeleteConfirmTitle;

  /// Confirmation avant de supprimer un téléchargement COMPLET (F14) : on jette un contenu prêt à écouter hors ligne
  ///
  /// In fr, this message translates to:
  /// **'Le fichier sera effacé de cet appareil. Vous pourrez le télécharger de nouveau plus tard.'**
  String get downloadDeleteConfirmMessage;

  /// No description provided for @downloadDeleteConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get downloadDeleteConfirmAction;

  /// Page Téléchargements : état d'un téléchargement en file, pas encore démarré par le moteur natif
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get downloadStateQueued;

  /// Premier hexagone du Profil (F12) : mène à la page Téléchargements (/downloads)
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get profileDownloads;

  /// Titre de la page Téléchargements (F13)
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get downloadsTitle;

  /// Page Téléchargements : titre de l'état vide (rien n'a été téléchargé sur cet appareil)
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement'**
  String get downloadsEmptyTitle;

  /// Page Téléchargements : explication sous le titre de l'état vide
  ///
  /// In fr, this message translates to:
  /// **'Les messages que vous téléchargez pour les écouter hors ligne apparaîtront ici.'**
  String get downloadsEmptyMessage;

  /// Page Téléchargements : espace disque total occupé par les téléchargements (F13). {size} est un nombre déjà formaté en Mo
  ///
  /// In fr, this message translates to:
  /// **'{size} Mo utilisés'**
  String downloadsStorageUsed(String size);

  /// Page Téléchargements : taille d'un téléchargement complété, affichée à côté de « Téléchargé ». {size} est un nombre déjà formaté en Mo
  ///
  /// In fr, this message translates to:
  /// **'{size} Mo'**
  String downloadSize(String size);

  /// Page Téléchargements : titre de repli quand le message d'un téléchargement n'est pas (ou plus) dans le magasin local
  ///
  /// In fr, this message translates to:
  /// **'Message téléchargé'**
  String get downloadsUnknownTitle;

  /// Badge sur un téléchargement périmé (#194, F15) : le média a été révisé côté serveur. La copie locale reste écoutable ; un tap « Mettre à jour » la remplace
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour disponible'**
  String get downloadUpdateAvailable;

  /// Action sur un téléchargement périmé (#194, F15) : re-télécharge la nouvelle version du média
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get downloadActionUpdate;

  /// Bandeau de la page Téléchargements (#194, F16) : un message retiré côté serveur a vu sa copie locale purgée. {title} est le titre du message
  ///
  /// In fr, this message translates to:
  /// **'« {title} » a été retiré par la médiathèque et supprimé de vos téléchargements.'**
  String downloadPurgeNotice(String title);

  /// Bandeau de purge (#194, F16), repli quand le titre du message retiré n'est pas connu (téléchargement d'avant la dénormalisation)
  ///
  /// In fr, this message translates to:
  /// **'Un message a été retiré par la médiathèque et supprimé de vos téléchargements.'**
  String get downloadPurgeNoticeUnnamed;

  /// Bandeau de purge : rejeter une notification de purge (le fidèle l'a vue)
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get downloadPurgeDismiss;

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

  /// Carte de requête de prière : nombre de membres qui prient. Remplace une chaîne codée en dur (prayer_request_card.dart)
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} membre en prière} other{{count} membres en prière}}'**
  String prayerRequestPraying(int count);

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

  /// Profil : entrée qui ouvre l'écran de suppression de compte. Exigence App Store 5.1.1(v) — supprimer son compte doit être possible DANS l'app
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountTitle;

  /// Écran de suppression : la phrase d'ouverture. Dit « définitif » avant toute liste, parce que c'est la seule chose à retenir si on ne lit pas la suite
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive. Elle ne peut pas être annulée, et personne à l\'église ne peut la défaire pour vous.'**
  String get deleteAccountLead;

  /// No description provided for @deleteAccountErasedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui est effacé'**
  String get deleteAccountErasedTitle;

  /// No description provided for @deleteAccountErasedIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Votre identité : nom, civilité, email, téléphone.'**
  String get deleteAccountErasedIdentity;

  /// No description provided for @deleteAccountErasedNotes.
  ///
  /// In fr, this message translates to:
  /// **'Vos notes spirituelles.'**
  String get deleteAccountErasedNotes;

  /// No description provided for @deleteAccountErasedProgress.
  ///
  /// In fr, this message translates to:
  /// **'Votre progression d\'écoute, sur cet appareil et sur les autres.'**
  String get deleteAccountErasedProgress;

  /// No description provided for @deleteAccountKeptTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui reste, sans votre nom'**
  String get deleteAccountKeptTitle;

  /// No description provided for @deleteAccountKeptMessages.
  ///
  /// In fr, this message translates to:
  /// **'Vos messages dans les groupes restent lisibles, détachés de vous.'**
  String get deleteAccountKeptMessages;

  /// No description provided for @deleteAccountKeptPrayers.
  ///
  /// In fr, this message translates to:
  /// **'Les prières que d\'autres ont portées avec vous ne disparaissent pas du mur.'**
  String get deleteAccountKeptPrayers;

  /// Écran de suppression : l'email libéré permet une réinscription, mais sur un compte NEUF — le dire évite qu'on croie pouvoir « revenir » à son historique
  ///
  /// In fr, this message translates to:
  /// **'Votre email redevient libre : vous pourrez vous réinscrire, mais ce sera un compte entièrement neuf, sans rien de celui-ci.'**
  String get deleteAccountReuse;

  /// No description provided for @deleteAccountConfirmCheckbox.
  ///
  /// In fr, this message translates to:
  /// **'Je comprends que cette action est définitive.'**
  String get deleteAccountConfirmCheckbox;

  /// No description provided for @deleteAccountAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteAccountAction;

  /// Écran de suppression, panne réseau. Insiste sur « votre compte est intact » : sans cette phrase, on croit avoir à moitié réussi
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible : pas de réseau. Votre compte est intact.'**
  String get deleteAccountErrorNetwork;

  /// No description provided for @deleteAccountErrorServer.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas pu traiter la demande. Votre compte est intact, réessayez.'**
  String get deleteAccountErrorServer;

  /// No description provided for @mediaSettings.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get mediaSettings;

  /// No description provided for @mediaSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qualité & données'**
  String get mediaSettingsTitle;

  /// Panneau qualité : dit d'emblée que le réglage vise le forfait mobile, pas la qualité en général
  ///
  /// In fr, this message translates to:
  /// **'Ces réglages ne changent rien à ce que vous entendez sur le réseau de l\'église. Ils protègent votre forfait quand vous êtes dehors.'**
  String get mediaSettingsLead;

  /// No description provided for @mediaSettingsStreaming.
  ///
  /// In fr, this message translates to:
  /// **'Écoute d\'un message'**
  String get mediaSettingsStreaming;

  /// No description provided for @mediaSettingsLive.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get mediaSettingsLive;

  /// No description provided for @mediaSettingsDownload.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement'**
  String get mediaSettingsDownload;

  /// No description provided for @mediaSettingsDownloadOnCellular.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger en données mobiles'**
  String get mediaSettingsDownloadOnCellular;

  /// Sous-titre du toggle données mobiles des téléchargements (F8). Dit le défaut wifi-seulement et pourquoi
  ///
  /// In fr, this message translates to:
  /// **'Par défaut, les téléchargements attendent le wifi pour préserver votre forfait.'**
  String get mediaSettingsDownloadOnCellularSubtitle;

  /// Titre de la section « préférence de branche » du panneau de réglages. « Mon assemblée » et non « Ma branche » : c'est le mot qu'emploient les fidèles, et « branche » est le mot du référentiel serveur
  ///
  /// In fr, this message translates to:
  /// **'Mon assemblée'**
  String get branchScopeTitle;

  /// Phrase d'introduction de la section assemblée. Elle dit ce que le réglage touche ET ce qu'il ne touche pas : le serveur garde son propre cloisonnement sur l'agenda et le mur de prière, et quelqu'un qui l'ignorerait croirait le réglage cassé
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'assemblée dont vous voulez suivre les messages, les rassemblements et les annonces. L\'agenda et le mur de prière ne changent pas.'**
  String get branchScopeLead;

  /// L'option par défaut : aucun filtre. C'est aussi l'état d'une installation neuve, où rien n'a été choisi
  ///
  /// In fr, this message translates to:
  /// **'Toutes les assemblées'**
  String get branchScopeAll;

  /// Phrase d'impact de l'option « toutes » — sur le modèle des paliers de qualité, où chaque ligne dit ce qu'elle coûte et ce qu'elle fait perdre
  ///
  /// In fr, this message translates to:
  /// **'Tout ce que publie l\'église, où qu\'elle le publie.'**
  String get branchScopeAllSubtitle;

  /// État vide de la liste : les branches viennent du magasin local (collection répliquée « branches »), donc elles manquent tant qu'aucun cycle n'a abouti. L'absence s'affiche comme une absence, jamais comme une liste vide sans explication
  ///
  /// In fr, this message translates to:
  /// **'La liste des assemblées arrivera à la première synchronisation.'**
  String get branchScopeEmpty;

  /// No description provided for @mediaQualityAuto.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get mediaQualityAuto;

  /// No description provided for @mediaQualityLow.
  ///
  /// In fr, this message translates to:
  /// **'Économie'**
  String get mediaQualityLow;

  /// No description provided for @mediaQualityMid.
  ///
  /// In fr, this message translates to:
  /// **'Standard'**
  String get mediaQualityMid;

  /// No description provided for @mediaQualityHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get mediaQualityHigh;

  /// Phrase d'impact du mode automatique. Annonce le coût du PIRE cas (données mobiles) — c'est celui contre lequel on se protège
  ///
  /// In fr, this message translates to:
  /// **'≈ {mb} Mo par heure en données mobiles, meilleure qualité en wifi.'**
  String mediaQualityImpactAuto(int mb);

  /// Phrase d'impact du palier 64k. Dit aussi ce qu'on perd : le chiffre seul ferait choisir à l'aveugle
  ///
  /// In fr, this message translates to:
  /// **'≈ {mb} Mo par heure · suffisant pour la prédication, la chorale y perd.'**
  String mediaQualityImpactLow(int mb);

  /// No description provided for @mediaQualityImpactMid.
  ///
  /// In fr, this message translates to:
  /// **'≈ {mb} Mo par heure · la louange retrouve son ampleur.'**
  String mediaQualityImpactMid(int mb);

  /// No description provided for @mediaQualityImpactHigh.
  ///
  /// In fr, this message translates to:
  /// **'≈ {mb} Mo par heure · chaque nuance, au prix fort.'**
  String mediaQualityImpactHigh(int mb);

  /// No description provided for @themeSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get themeSectionTitle;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// Position du sélecteur d'apparence : suit le réglage DU TÉLÉPHONE. À distinguer de « Auto », qui suit une règle horaire de l'application
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// Position du sélecteur d'apparence : règle horaire de l'application, réglable. Ne suit PAS le téléphone
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeAutoHoursTitle.
  ///
  /// In fr, this message translates to:
  /// **'Heures de bascule'**
  String get themeAutoHoursTitle;

  /// No description provided for @themeDarkFrom.
  ///
  /// In fr, this message translates to:
  /// **'Passe en sombre à'**
  String get themeDarkFrom;

  /// No description provided for @themeLightFrom.
  ///
  /// In fr, this message translates to:
  /// **'Revient au clair à'**
  String get themeLightFrom;

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

  /// Sous-titre de l'écran identifiant, quand rien ne dit déjà pourquoi on y est. Une raison (authReason*) prend sa place
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre numéro ou votre email pour continuer.'**
  String get authIdentifierSubtitle;

  /// Pourquoi le formulaire s'affiche dans l'onglet Échanges. Il remplace le contenu de l'onglet pour un invité, et cette phrase est ce qui dit à quoi la connexion sert ICI — jamais une invitation générique. Elle ne remplace PAS l'annonce de canal (#83), qui répond à une autre question : par où le code arrive
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour accéder aux échanges.'**
  String get authReasonCommunity;

  /// Le même, pour l'onglet Profil
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour accéder à votre profil.'**
  String get authReasonProfile;

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

  /// Annonce affichée quand l'email est le SEUL canal ouvert : il n'y a alors pas de sélecteur, et cette phrase dit pourquoi. Repli du dépôt — le portail peut la remplacer (collection auth_channels, loginNotice)
  ///
  /// In fr, this message translates to:
  /// **'Votre code de connexion vous sera envoyé par email.'**
  String get authNoticeEmailOnly;

  /// Le symétrique, si le téléphone devenait le seul canal ouvert. Elle ne nomme aucun fournisseur (SMS, WhatsApp) : le canal est le téléphone, le fournisseur est un réglage serveur
  ///
  /// In fr, this message translates to:
  /// **'Votre code de connexion vous sera envoyé sur votre téléphone.'**
  String get authNoticePhoneOnly;

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

  /// Mention suffixée à la branche isMotherChurch dans le sélecteur, qui la place en tête de liste
  ///
  /// In fr, this message translates to:
  /// **'Église Mère'**
  String get branchMotherChurch;

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

  /// Cause de l'état d'erreur quand le serveur a répondu en refusant (401, 403) — jamais « vérifiez votre connexion » : une réponse reçue n'est pas une panne de réseau, et la seconde phrase retire la fausse piste
  ///
  /// In fr, this message translates to:
  /// **'Ce contenu n\'est pas accessible pour l\'instant. Votre connexion internet n\'est pas en cause.'**
  String get stateErrorRefusedMessage;

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

  /// Absence « écoute impossible hors ligne » (ContentAbsence.offlineMedia) : le média existe, l'appareil est hors ligne. La seule des quatre qui se résout en retrouvant du réseau. NE JAMAIS y remettre de téléchargement : la médiathèque s'écoute EN LIGNE SEULEMENT (docs/mediatheque-en-ligne.md), le catalogue est hors ligne, le son ne l'est pas. Pas encore câblé
  ///
  /// In fr, this message translates to:
  /// **'Écoute impossible hors ligne'**
  String get absenceOfflineMediaTitle;

  /// Explication de l'absence « écoute impossible hors ligne » : dit la règle (l'écoute passe par le réseau) puis l'action qui débloque. La formulation précédente — « cet enregistrement n'a pas été téléchargé » — présupposait une fonction de téléchargement qui n'existe pas et n'est pas prévue, et envoyait le fidèle chercher un bouton introuvable
  ///
  /// In fr, this message translates to:
  /// **'La médiathèque s\'écoute en ligne. Reconnectez-vous à internet pour lancer la lecture.'**
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

  /// Absence « contenu retiré » vue depuis l'écran de détail d'un message : dit de quoi on parle, là où absenceRetractedTitle reste générique
  ///
  /// In fr, this message translates to:
  /// **'Ce message n\'est plus disponible'**
  String get teachingRetractedTitle;

  /// Explication du message retiré. Mentionne explicitement l'arrêt de la lecture : le son s'est coupé, il faut dire pourquoi
  ///
  /// In fr, this message translates to:
  /// **'Il a été retiré de la médiathèque. La lecture est arrêtée.'**
  String get teachingRetractedMessage;

  /// Panne survenue **pendant** l'écoute (lecteur de la médiathèque). À ne surtout pas confondre avec stateErrorTitle, qui parle du catalogue : ici le contenu est bien arrivé, c'est le son qui s'est arrêté. Une panne survenue avant que le son n'ait jamais commencé s'affiche, elle, en ContentAbsence.offlineMedia — il n'y a alors rien à reprendre
  ///
  /// In fr, this message translates to:
  /// **'Lecture interrompue'**
  String get playerErrorTitle;

  /// Explication de la panne en cours d'écoute. Ne met en cause ni l'appareil ni l'église : elle nomme le fait (le son s'est arrêté) et l'issue (reprendre)
  ///
  /// In fr, this message translates to:
  /// **'Le son s\'est arrêté. Vérifiez votre connexion, puis reprenez la lecture.'**
  String get playerErrorMessage;

  /// Action de la panne en cours d'écoute — **jamais « Réessayer »**. Le mot doit promettre de repartir d'où on en était : sur un prêche d'une heure, la crainte d'un retour à zéro suffit à ce que le fidèle ne touche pas au bouton. Le lecteur tient parole (ContentPlayer.resume rouvre à la position courante)
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get playerErrorRetry;

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

  /// Infobulle de l'icône de l'accueil qui ouvre le menu latéral. Le glissement horizontal est coupé (carrousels et visionneuse de statuts) : cette icône est la seule ouverture
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le menu'**
  String get drawerOpen;

  /// Menu latéral : conditions générales d'utilisation. Abrégé, comme sur la maquette — le libellé long ne tiendrait pas sur une ligne du panneau
  ///
  /// In fr, this message translates to:
  /// **'CGU'**
  String get drawerTerms;

  /// Menu latéral : politique de confidentialité
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get drawerPrivacy;

  /// Menu latéral : écran « À propos » (version du binaire + présentation servie par le portail). Route distincte de /legal/:kind — ranger « À propos » sous /legal mentirait sur sa nature
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get drawerAbout;

  /// Entête local d'« À propos » : le nom de l'église, sous l'emblème qui porte déjà « Maison du Miracle ». Local et non servi — c'est l'identité de l'application, pas un contenu éditorial
  ///
  /// In fr, this message translates to:
  /// **'Église Évangélique Nouvelle Vie'**
  String get aboutChurchName;

  /// Entête local d'« À propos » : version et build du BINAIRE INSTALLÉ. Ne vient jamais du serveur — c'est toute la raison de cet entête local, et c'est le renseignement qu'on demande à un fidèle qui signale une anomalie. Ne pas confondre avec legalFooterVersion, qui est l'édition du document servi
  ///
  /// In fr, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(String version, String build);

  /// Pied d'un document légal. La date est formatée CÔTÉ CLIENT (utils/event_time.dart), jamais servie en toutes lettres par le serveur : un texte pré-formaté ne se traduit pas et ne se relit pas dans le fuseau du lecteur
  ///
  /// In fr, this message translates to:
  /// **'Version {version} — mise à jour le {date}'**
  String legalFooterUpdated(int version, String date);

  /// Pied d'un document légal quand le serveur n'a servi NI date de mise à jour NI date de publication. L'absence se rend comme une absence — jamais une date inventée, qui ferait foi sur un texte qu'on demande d'accepter
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String legalFooterVersion(int version);

  /// Titre de la barrière de consentement à la PREMIÈRE acceptation — déduit d'un résumé d'acceptation vide. Dire « nos conditions ont changé » à quelqu'un qui n'en a jamais lu aucune lui ferait chercher ce qu'il a manqué
  ///
  /// In fr, this message translates to:
  /// **'Avant de commencer'**
  String get legalGateTitleFirst;

  /// Titre de la barrière de consentement lors d'une RE-acceptation, après révision. Le fidèle concerné est connecté depuis longtemps : ce qu'il doit savoir, c'est que le texte a bougé
  ///
  /// In fr, this message translates to:
  /// **'Nos conditions ont changé'**
  String get legalGateTitleUpdated;

  /// Sous-titre de la barrière, commun aux deux cas. Il dit le blocage sans le déguiser : il n'y a ni « Plus tard », ni croix, ni retour
  ///
  /// In fr, this message translates to:
  /// **'Votre accord est nécessaire pour continuer.'**
  String get legalGateSubtitle;

  /// Case à cocher des CGU, sur la barrière. Une case PAR document exigé, jamais précochée — une case précochée n'est pas un consentement
  ///
  /// In fr, this message translates to:
  /// **'J\'ai lu et j\'accepte les conditions générales d\'utilisation.'**
  String get legalGateAcceptTerms;

  /// Case à cocher de la politique de confidentialité, sur la barrière. Si seule la politique a changé, c'est la seule case et le seul document affichés
  ///
  /// In fr, this message translates to:
  /// **'J\'ai lu et j\'accepte la politique de confidentialité.'**
  String get legalGateAcceptPrivacy;

  /// Refus d'enregistrement, serveur injoignable. Le document se lit hors ligne (il vient du magasin), l'accord ne s'enregistre pas : pas de file d'envoi, pas d'état « accepté, non confirmé » (ADR-0036, décision 2). Suivi de « Réessayer »
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise pour enregistrer votre accord.'**
  String get legalGateErrorNetwork;

  /// Refus d'enregistrement, 401. Aucun bouton : le retour à /auth se fait par la garde de route, l'écran ne navigue pas lui-même. Proposer « Réessayer » promettrait ce qui ne peut pas marcher
  ///
  /// In fr, this message translates to:
  /// **'Votre session a expiré. Reconnectez-vous pour enregistrer votre accord.'**
  String get legalGateErrorUnauthorized;

  /// Refus d'enregistrement, 422 : une révision a paru entre la synchronisation et l'appui sur « Continuer ». Réessayer à l'identique échouerait toujours — l'issue est de RECHARGER le document
  ///
  /// In fr, this message translates to:
  /// **'Ces conditions ont été mises à jour.'**
  String get legalGateErrorOutdated;

  /// Refus d'enregistrement, 5xx. Le serveur est joignable : ce n'est pas la connexion du fidèle qui est en cause. Suivi de « Réessayer »
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas pu enregistrer votre accord.'**
  String get legalGateErrorServer;

  /// Issue du refus 422 : redemande le document au serveur. Pas « Réessayer » — ce n'est pas le même envoi qu'on rejoue, c'est le texte qu'on va chercher
  ///
  /// In fr, this message translates to:
  /// **'Recharger'**
  String get legalGateReload;

  /// Mention légale NON bloquante du premier lancement, pour un invité. Elle existe parce que l'application attribue un identifiant à l'appareil dès l'ouverture — une donnée personnelle — et qu'un invité ne passe jamais par la barrière de consentement des membres (/legal/accept), seule à recueillir un accord explicite. Ce n'est donc pas une décoration : c'est le seul endroit où cela s'annonce à qui n'a pas de compte
  ///
  /// In fr, this message translates to:
  /// **'En utilisant l\'application, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.'**
  String get legalNoticeBody;

  /// Lien du bandeau vers /legal/cgu. Un libellé propre plutôt que l'abrégé du menu latéral (drawerTerms, « CGU ») : ici il n'y a pas de contrainte de largeur, et un sigle dans une phrase de consentement se lit moins bien qu'un mot
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get legalNoticeTerms;

  /// Lien du bandeau vers /legal/privacy. Abrégé, lui, parce qu'il partage sa ligne avec le lien des conditions et le bouton de fermeture
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get legalNoticePrivacy;

  /// Ferme le bandeau, définitivement (mémoire locale). Pas « Accepter » : il n'y a rien à cocher ni à envoyer ici — l'accord d'un invité est implicite par l'usage, et prétendre le recueillir donnerait à croire qu'il est tracé
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris'**
  String get legalNoticeDismiss;

  /// Bandeau NON bloquant de mise à jour, affiché quand la version installée est sous le seuil réglé au portail. Il informe et renvoie au magasin ; il ne bloque rien, ne force rien, et l'application reste utilisable derrière. Tant qu'aucun seuil n'est réglé, il ne s'affiche pour personne
  ///
  /// In fr, this message translates to:
  /// **'Une nouvelle version de l\'application est disponible.'**
  String get appUpdateBody;

  /// Ouvre la fiche de l'application dans le magasin. Un verbe d'action et non « Ouvrir le magasin » : ce qu'on vient faire est la mise à jour, le magasin n'en est que le chemin
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get appUpdateAction;

  /// Ferme le bandeau pour la session en cours — pas définitivement, contrairement à legalNoticeDismiss. Pas « J'ai compris » : il n'y a rien à comprendre ici, seulement un geste qu'on remet à plus tard, et le bandeau reviendra au prochain lancement tant que la version n'aura pas monté
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get appUpdateDismiss;

  /// Mini-lecteur : badge d'un direct de la régie (#149), à la place de la ligne d'orateur. Affiché seulement quand l'antenne connue signale un direct (RadioAntenna.live) — jamais pour dire que la radio tourne, c'est miniPlayerOnAirBadge. Capitales voulues, comme un voyant d'antenne ; court, il tient dans une pastille rouge
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get miniPlayerLiveBadge;

  /// Mini-lecteur : badge de la radio hors direct (#149), à la place de la ligne d'orateur. Le mot de la page radio (radioLive) : la radio tourne 24 h/24, « EN DIRECT » est réservé au direct de la régie. Dit ce qu'on écoute, pas que le son sort — il reste en pause. Court : il tient dans une pastille
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne'**
  String get miniPlayerOnAirBadge;

  /// Mini-lecteur : libellé d'accessibilité de la vignette et du titre, qui ouvrent la fiche (ou l'écran de l'antenne). {title} est le titre de ce qui joue
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le lecteur : {title}'**
  String miniPlayerOpen(String title);

  /// Mini-lecteur : libellé d'accessibilité du bouton −30 s. Le pas est celui de la notification et de la fiche (kContentSkipInterval) ; si la constante change, ce texte change avec elle
  ///
  /// In fr, this message translates to:
  /// **'Reculer de 30 secondes'**
  String get miniPlayerSkipBackward;

  /// Mini-lecteur : libellé d'accessibilité du bouton +30 s. Même pas que miniPlayerSkipBackward
  ///
  /// In fr, this message translates to:
  /// **'Avancer de 30 secondes'**
  String get miniPlayerSkipForward;

  /// Mini-lecteur : le gros bouton en fin de lecture. Relance depuis le début
  ///
  /// In fr, this message translates to:
  /// **'Rejouer'**
  String get miniPlayerReplay;

  /// Mini-lecteur : le gros bouton quand l'écoute a échoué avant d'avoir jamais commencé (pas de réseau à l'ouverture). Pas « Reprendre » : il n'y a aucune position à retrouver. Pas « Réessayer » non plus, mot banni du lecteur
  ///
  /// In fr, this message translates to:
  /// **'Relancer l\'écoute'**
  String get miniPlayerRelaunch;

  /// Mini-lecteur : libellé d'accessibilité de la croix. Arrête le son, retire la notification et ferme le mini-lecteur ; la position de reprise est gardée
  ///
  /// In fr, this message translates to:
  /// **'Fermer le lecteur'**
  String get miniPlayerClose;
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
