// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Maison du Miracle';

  @override
  String get splashTagline => 'Nous annonçons avec foi.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navMedia => 'Médias';

  @override
  String get navAnnouncements => 'Annonces';

  @override
  String get navGroups => 'Groupes';

  @override
  String get navProfile => 'Profil';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navDonations => 'Dons';

  @override
  String get announcementsTitle => 'Annonces';

  @override
  String get announcementsEmptyTitle => 'Aucune annonce';

  @override
  String get announcementsEmptyBody =>
      'Les annonces de l\'église apparaîtront ici.';

  @override
  String get statusVideoBadge => 'Vidéo';

  @override
  String get statusListTitle => 'Toutes les annonces';

  @override
  String get statusOpenList => 'Voir toutes les annonces';

  @override
  String get statusMute => 'Couper le son';

  @override
  String get statusUnmute => 'Activer le son';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count minutes',
      one: 'Il y a $count minute',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count heures',
      one: 'Il y a $count heure',
    );
    return '$_temp0';
  }

  @override
  String get timeYesterday => 'Hier';

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a $count jour',
    );
    return '$_temp0';
  }

  @override
  String get onboardingWelcome => 'Bienvenue';

  @override
  String get onboardingTitleHighlight => 'Dans la Maison\ndu Miracle';

  @override
  String get onboardingSubtitle =>
      'Une communauté vivante, connectée et engagée pour la gloire de Dieu.';

  @override
  String get actionNext => 'Suivant';

  @override
  String get onboardingVerse =>
      '« Venez à moi, vous tous qui êtes fatigués, et je vous donnerai du repos. »\n— Matthieu 11:28';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboardingJoinTitle => 'Nous rejoindre';

  @override
  String get onboardingJoinSubtitle => 'Choisissez comment continuer.';

  @override
  String get authPhone => 'Téléphone';

  @override
  String get authEmail => 'Email';

  @override
  String get actionJoin => 'Rejoindre';

  @override
  String get onboardingCodeTitle => 'Vérification';

  @override
  String get onboardingCodeSubtitle => 'Saisissez le code que vous avez reçu.';

  @override
  String get onboardingCodeHint => 'Code de vérification';

  @override
  String get actionValidate => 'Valider';

  @override
  String get onboardingAlreadyMember => 'Déjà membre ? ';

  @override
  String get loginTitle => 'Heureux de vous revoir !';

  @override
  String get loginSubtitle => 'Connectez-vous pour continuer.';

  @override
  String get fieldEmailOrPhone => 'Email ou numéro';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get actionLogin => 'Se connecter';

  @override
  String get orContinueWith => 'Ou continuer avec';

  @override
  String get noAccountYet => 'Pas encore de compte ? ';

  @override
  String get actionRegister => 'S\'inscrire';

  @override
  String get registerAppBarTitle => 'Inscription';

  @override
  String get registerTitle => 'Créer votre compte';

  @override
  String get registerSubtitle => 'Rejoignez notre communauté.';

  @override
  String get fieldPhone => 'Téléphone';

  @override
  String get fieldLocalBranch => 'Branche locale';

  @override
  String get registerTermsPrefix => 'En créant un compte, vous acceptez nos ';

  @override
  String get registerTermsLink => 'Conditions d\'utilisation.';

  @override
  String homeGreeting(String name) {
    return 'Bonjour $name !';
  }

  @override
  String get homeGreetingNoName => 'Bonjour !';

  @override
  String get homeBlessing => 'Que Dieu vous bénisse aujourd\'hui.';

  @override
  String get liveBannerTitle => 'Culte en direct';

  @override
  String get liveBannerSubtitle => 'Rejoindre maintenant';

  @override
  String get sectionUpcoming => 'À venir';

  @override
  String get sectionUpcomingServices => 'Cultes à venir';

  @override
  String get homeWatchLive => 'Regarder le direct';

  @override
  String get actionSeeAll => 'Voir tout';

  @override
  String get actionListen => 'Écouter';

  @override
  String get sectionLatestTeachings => 'Derniers enseignements';

  @override
  String get sectionSundayMessage => 'Messages du dimanche';

  @override
  String get sectionBibleStudy => 'Études bibliques';

  @override
  String get sectionPrayerTimes => 'Moments de prière';

  @override
  String get mediaTitle => 'Médiathèque';

  @override
  String get mediaSearchHint => 'Rechercher un enseignement...';

  @override
  String get mediaRecommended => 'Recommandés pour vous';

  @override
  String get filterAll => 'Tout';

  @override
  String get filterSermons => 'Prêches';

  @override
  String get filterTeachings => 'Enseignements';

  @override
  String get filterMusic => 'Musique';

  @override
  String get seriesTag => 'Série';

  @override
  String seriesMessagesCount(int count) {
    return '$count messages';
  }

  @override
  String get groupsTitle => 'Mes groupes';

  @override
  String get groupsDiscoverMore => 'Découvrir plus de groupes';

  @override
  String get communityTitle => 'Communauté';

  @override
  String get communityTabInbox => 'Inbox';

  @override
  String get communityTabRequests => 'Requêtes';

  @override
  String groupMembers(int count) {
    return '$count membres';
  }

  @override
  String groupMembersWithRole(int count, String role) {
    return '$count membres • $role';
  }

  @override
  String get chatMessageHint => 'Votre message...';

  @override
  String get chatToday => 'Aujourd\'hui';

  @override
  String get teachingAppBarTitle => 'Enseignement';

  @override
  String get actionDownload => 'Télécharger';

  @override
  String get actionMyNotes => 'Mes notes';

  @override
  String get actionShare => 'Partager';

  @override
  String get tabDescription => 'Description';

  @override
  String get teachingVerses => 'Versets';

  @override
  String tabNotesCount(int count) {
    return 'Notes ($count)';
  }

  @override
  String get actionDownloadAudio => 'Télécharger l\'audio';

  @override
  String get agendaSeeAll => 'Voir tout l\'agenda';

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mer';

  @override
  String get weekdayThu => 'Jeu';

  @override
  String get weekdayFri => 'Ven';

  @override
  String get weekdaySat => 'Sam';

  @override
  String get weekdaySun => 'Dim';

  @override
  String get liveAppBarTitle => 'Culte en direct';

  @override
  String get liveAudioOnly => 'Audio seul';

  @override
  String get liveQuality => 'Qualité';

  @override
  String get liveAboutTitle => 'À propos de ce live';

  @override
  String get liveAboutBody =>
      'Soyez bénis par la Parole de Dieu et restez connectés.';

  @override
  String liveConnectedPeople(String count) {
    return '$count personnes connectées';
  }

  @override
  String get liveCommentHint => 'Écrire un message...';

  @override
  String get prayersAppBarTitle => 'Espace de prière';

  @override
  String get prayersTabMine => 'Mes requêtes';

  @override
  String get prayersTabCommunity => 'Communauté';

  @override
  String get prayersNewRequest => 'Nouvelle requête';

  @override
  String get newRequestAppBarTitle => 'Nouvelle requête';

  @override
  String get newRequestTypeLabel => 'Type de requête';

  @override
  String get requestTypeSuggestion => 'Suggestion';

  @override
  String get requestTypeComplaint => 'Plainte';

  @override
  String get requestTypeReport => 'Signalement';

  @override
  String get requestTypeOther => 'Autre';

  @override
  String get newRequestDescribeLabel => 'Décrivez votre requête';

  @override
  String get newRequestDescribeHint => 'Écrivez votre message ici...';

  @override
  String get anonymousLabel => 'Anonyme';

  @override
  String get anonymousSubtitle => 'Votre identité restera confidentielle.';

  @override
  String get actionSend => 'Envoyer';

  @override
  String get notesAppBarTitle => 'Mes notes';

  @override
  String get notesSearchHint => 'Rechercher une note...';

  @override
  String get profileRole => 'Membre Nouvelle Vie';

  @override
  String get profileEdit => 'Modifier';

  @override
  String get profileStatServices => 'Cultes';

  @override
  String get profileStatNotes => 'Notes';

  @override
  String get profileMyBranch => 'Ma branche';

  @override
  String get profileMyContributions => 'Mes contributions';

  @override
  String get profileMyNotes => 'Mes notes spirituelles';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get settings => 'Paramètres';

  @override
  String get helpSupport => 'Aide & Support';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get donationsAppBarTitle => 'Dons & Offrandes';

  @override
  String get donationsTitle => 'Soutenez l\'œuvre de Dieu';

  @override
  String get donationsSubtitle =>
      'Donnez selon ce que Dieu met dans votre cœur.';

  @override
  String get donationsAmountLabel => 'Montant';

  @override
  String get donationsPaymentMethodLabel => 'Méthode de paiement';

  @override
  String get paymentCard => 'Carte bancaire';

  @override
  String get actionContinue => 'Continuer';

  @override
  String get donationsSecure => 'Vos dons sont sécurisés';

  @override
  String get authStart => 'Commencer';

  @override
  String get authAlreadyMember => 'Déjà membre ?';

  @override
  String get authIdentifierTitle => 'Rejoignez-nous';

  @override
  String get authIdentifierSubtitle =>
      'Entrez votre numéro ou votre email pour continuer.';

  @override
  String get authPhoneHint => '90 12 34 56';

  @override
  String get authEmailHint => 'jean.kossi@email.com';

  @override
  String get authContinue => 'Continuer';

  @override
  String get authOrContinueWith => 'Ou continuer avec';

  @override
  String get authDialCode => 'Indicatif';

  @override
  String get authCodeTitle => 'Vérification';

  @override
  String authCodeSubtitle(String target) {
    return 'Saisissez le code à 6 chiffres envoyé à $target.';
  }

  @override
  String get authResend => 'Renvoyer le code';

  @override
  String authResendIn(int seconds) {
    return 'Renvoyer dans $seconds s';
  }

  @override
  String get authCodeInvalid => 'Code invalide ou expiré';

  @override
  String get profileFormTitle => 'Nous aimerions en savoir plus sur vous';

  @override
  String get profileFormSubtitle =>
      'Ces informations restent facultatives et modifiables.';

  @override
  String get titleBrother => 'Frère';

  @override
  String get titleSister => 'Sœur';

  @override
  String get fieldYourName => 'Votre prénom';

  @override
  String get fieldYourBranch => 'Votre branche';

  @override
  String get branchImNew => 'Je suis nouveau';

  @override
  String get branchesEmpty => 'Aucune branche à sélectionner pour le moment.';

  @override
  String get branchesUnavailable =>
      'Liste des branches indisponible. Tu pourras la choisir plus tard.';

  @override
  String get actionLater => 'Plus tard';

  @override
  String get actionSave => 'Enregistrer';

  @override
  String get profileEditAction => 'Modifier mon profil';

  @override
  String get profileIncompleteBanner => 'Complétez votre profil';

  @override
  String get profileIncompleteBannerCta => 'Compléter';

  @override
  String get logoutConfirmTitle => 'Se déconnecter ?';

  @override
  String get logoutConfirmMessage =>
      'Vous devrez saisir un nouveau code pour vous reconnecter.';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get statusNewLabel => 'Nouveau — pas encore rattaché';

  @override
  String get errorGeneric => 'Une erreur est survenue. Réessayez.';

  @override
  String get profileTitleLabel => 'Civilité';

  @override
  String get profileTitleRequired => 'Sélectionnez Frère ou Sœur';

  @override
  String get authCodeTooManyAttempts =>
      'Trop de tentatives. Réessayez plus tard.';

  @override
  String get authCodeResent => 'Code renvoyé.';

  @override
  String get stateLoading => 'Chargement en cours…';

  @override
  String get stateEmptyTitle => 'Rien à afficher';

  @override
  String get stateEmptyMessage => 'Il n\'y a aucun contenu ici pour le moment.';

  @override
  String get stateEndOfList => 'Fin de la liste';

  @override
  String get stateErrorTitle => 'Connexion perdue';

  @override
  String get stateErrorMessage =>
      'Impossible de charger le contenu. Vérifiez votre connexion internet, puis réessayez.';

  @override
  String get stateErrorServerMessage =>
      'Le serveur ne répond pas pour l\'instant. Réessayez dans un instant.';

  @override
  String get stateRetry => 'Réessayer';

  @override
  String get agendaEmptyMonthTitle => 'Aucun événement ce mois-ci';

  @override
  String get agendaEmptyMonthMessage => 'Rien n\'est prévu pour cette période.';

  @override
  String get agendaHorizonTitle => 'Fin du calendrier';

  @override
  String get agendaHorizonMessage =>
      'Les événements plus lointains ne sont pas encore annoncés.';
}
