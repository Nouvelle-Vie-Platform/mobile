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
  String get navGroups => 'Groupes';

  @override
  String get navProfile => 'Profil';

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
  String get fieldFullName => 'Nom complet';

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
    return 'Bonjour $name ! 👋';
  }

  @override
  String get homeBlessing => 'Que Dieu vous bénisse aujourd\'hui.';

  @override
  String get liveBannerTitle => 'Culte en direct';

  @override
  String get liveBannerSubtitle => 'Rejoindre maintenant';

  @override
  String get sectionUpcoming => 'À venir';

  @override
  String get actionSeeAll => 'Voir tout';

  @override
  String get sectionLatestTeachings => 'Derniers enseignements';

  @override
  String get mediaTitle => 'Médiathèque';

  @override
  String get mediaSearchHint => 'Rechercher un enseignement...';

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
}
