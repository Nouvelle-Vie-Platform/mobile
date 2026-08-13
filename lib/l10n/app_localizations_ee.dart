// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ewe (`ee`).
class AppLocalizationsEe extends AppLocalizations {
  AppLocalizationsEe([String locale = 'ee']) : super(locale);

  @override
  String get appName => 'Maison du Miracle';

  @override
  String get splashTagline => 'Míeɖe gbeƒã kple xɔse.';

  @override
  String get navHome => 'Aƒe';

  @override
  String get navMedia => 'Médias';

  @override
  String get navAnnouncements => 'Annonces';

  @override
  String get navGroups => 'Hawo';

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
  String get onboardingWelcome => 'Woezɔ';

  @override
  String get onboardingTitleHighlight => 'Dans la Maison\ndu Miracle';

  @override
  String get onboardingSubtitle =>
      'Une communauté vivante, connectée et engagée pour la gloire de Dieu.';

  @override
  String get actionNext => 'Yi ŋgɔ';

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
  String get loginSubtitle => 'Ge ɖe eme be nàyi edzi.';

  @override
  String get fieldEmailOrPhone => 'Email ou numéro';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get actionLogin => 'Ge ɖe eme';

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
  String get registerSubtitle => 'Va míaƒe habɔbɔ la me.';

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
    return 'Ŋdi $name!';
  }

  @override
  String get homeGreetingNoName => 'Bonjour !';

  @override
  String get homeBlessing => 'Mawu nayra wò egbe.';

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
  String get actionSeeAll => 'Kpɔ wo katã';

  @override
  String get actionListen => 'Écouter';

  @override
  String get sectionLatestTeachings => 'Derniers enseignements';

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
  String get groupsTitle => 'Nye hawo';

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
  String get prayersTabCommunity => 'Habɔbɔ';

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
  String get anonymousLabel => 'Ŋkɔ maɖemaɖe';

  @override
  String get anonymousSubtitle => 'Votre identité restera confidentielle.';

  @override
  String get actionSend => 'Ɖo ɖa';

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
  String get settings => 'Ɖoɖowo';

  @override
  String get helpSupport => 'Kpekpeɖeŋu';

  @override
  String get logout => 'Do go';

  @override
  String get donationsAppBarTitle => 'Dons & Offrandes';

  @override
  String get donationsTitle => 'Do alɔ Mawu ƒe dɔ la';

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
  String get actionContinue => 'Yi edzi';

  @override
  String get donationsSecure => 'Vos dons sont sécurisés';

  @override
  String get authStart => 'Dze egɔme';

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
  String get authContinue => 'Yi edzi';

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
  String get titleBrother => 'Nɔviŋutsu';

  @override
  String get titleSister => 'Nɔvinyɔnu';

  @override
  String get fieldYourName => 'Wò ŋkɔ';

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
  String get actionSave => 'Dzra ɖo';

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
  String get actionCancel => 'Gbugbɔ';

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
  String get homeUpcomingEmptyTitle => 'Aucun rassemblement à venir';

  @override
  String get homeUpcomingEmptyMessage =>
      'Le calendrier n\'annonce rien pour le moment. Revenez bientôt.';

  @override
  String homeUpcomingHorizonMessage(String date) {
    return 'Le calendrier n\'annonce rien jusqu\'au $date.';
  }

  @override
  String get agendaEmptyMonthTitle => 'Aucun événement ce mois-ci';

  @override
  String get agendaEmptyMonthMessage => 'Rien n\'est prévu pour cette période.';

  @override
  String get agendaHorizonTitle => 'Fin du calendrier';

  @override
  String get agendaHorizonMessage =>
      'Les événements plus lointains ne sont pas encore annoncés.';

  @override
  String get agendaPreviousMonth => 'Mois précédent';

  @override
  String get agendaNextMonth => 'Mois suivant';

  @override
  String agendaDaySummary(int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '$count événement',
      zero: 'aucun événement',
    );
    return '$day — $_temp0';
  }

  @override
  String get eventDetailTitle => 'Événement';

  @override
  String get eventDetailAbout => 'À propos';

  @override
  String get absenceRetractedTitle => 'Woɖe nu sia ɖa';

  @override
  String get absenceRetractedMessage => 'Nu sia megali o. Sɔlemeha la ɖee ɖa.';

  @override
  String get absenceNotSyncedTitle => 'Womekɔ ɖe mɔ̃a dzi haɖe o';

  @override
  String get absenceNotSyncedMessage =>
      'Nu sia meva mɔ̃ sia dzi haɖe o. Ava do le kɔkɔɖedzi si gbɔna megbe.';

  @override
  String get absenceNoMediaTitle => 'Nuɖeɖi la gbɔna';

  @override
  String get absenceNoMediaMessage =>
      'Nuɖeɖi la meva ɖe internet dzi haɖe o. Gbugbɔ va le ŋkeke ʋɛ aɖewo megbe.';

  @override
  String get absenceOfflineMediaTitle => 'Mele mɔ nu o';

  @override
  String get absenceOfflineMediaMessage =>
      'Womeɖi nuɖeɖi sia ɖe mɔ̃a dzi o. Gbugbɔ ka internet ŋu hafi nàse.';

  @override
  String get absenceBack => 'Trɔ yi megbe';

  @override
  String get gatheringAppBarTitle => 'Takpekpe';

  @override
  String get gatheringRetractedTitle => 'Takpekpe sia megali o';

  @override
  String get gatheringRetractedMessage =>
      'Il a été retiré par l\'église. La lecture est arrêtée.';

  @override
  String get sectionGatherings => 'Takpekpewo';

  @override
  String get teachingRetractedTitle => 'Nufiafia sia megali o';

  @override
  String get teachingRetractedMessage =>
      'Woɖee ɖa le nudzraɖoƒe la. Sese la tɔ.';

  @override
  String get playerErrorTitle => 'Sese la tɔ';

  @override
  String get playerErrorMessage =>
      'Gbeɖiɖi la tɔ. Kpɔ wò internet ŋu, eye nàgbugbɔ ase edzi.';

  @override
  String get playerErrorRetry => 'Gbugbɔ se edzi';

  @override
  String get composeAnnouncement => 'Publier une annonce';

  @override
  String get composerNewTitle => 'Nouvelle annonce';

  @override
  String get composerEditTitle => 'Modifier l\'annonce';

  @override
  String get composerAccountLabel => 'Publier au nom de';

  @override
  String get composerTitleLabel => 'Titre';

  @override
  String get composerTitleHint => 'Facultatif';

  @override
  String get composerBodyLabel => 'Message';

  @override
  String get composerBodyHint => 'Ce que l\'église doit savoir';

  @override
  String get composerBackgroundLabel => 'Fond';

  @override
  String get composerBackgroundNone => 'Aucun';

  @override
  String get composerImageLabel => 'Image de fond';

  @override
  String get composerImageAdd => 'Choisir une image';

  @override
  String get composerImageReplace => 'Remplacer l\'image';

  @override
  String get composerImageRemove => 'Retirer l\'image';

  @override
  String get composerImageKept => 'Image déjà publiée conservée';

  @override
  String get composerTimingLabel => 'Publication';

  @override
  String get composerTimingNow => 'Maintenant';

  @override
  String get composerTimingScheduled => 'Programmer';

  @override
  String get composerTimingDraft => 'Brouillon';

  @override
  String get composerScheduleLabel => 'Date de publication';

  @override
  String get composerSchedulePick => 'Choisir la date';

  @override
  String get composerExpiryLabel => 'Fin de publication';

  @override
  String get composerExpiryNever => 'N\'expire jamais';

  @override
  String get composerExpiryPick => 'Choisir une fin';

  @override
  String get composerExpiryClear => 'Retirer la fin';

  @override
  String get composerPublish => 'Publier';

  @override
  String get composerSave => 'Enregistrer';

  @override
  String get composerDelete => 'Supprimer l\'annonce';

  @override
  String get composerDeleteConfirmTitle => 'Supprimer cette annonce ?';

  @override
  String get composerDeleteConfirmBody =>
      'Elle disparaîtra de l\'application de tous les fidèles.';

  @override
  String get composerDeleteConfirmAction => 'Supprimer';

  @override
  String get composerNoAccountTitle => 'Aucun compte disponible';

  @override
  String get composerNoAccountBody =>
      'Vos comptes officiels ne sont pas encore arrivés sur cet appareil. Réessayez après la prochaine synchronisation.';

  @override
  String get composerMissingTitle => 'Annonce introuvable';

  @override
  String get composerMissingBody =>
      'Elle a été retirée. Il n\'y a plus rien à modifier.';

  @override
  String get composerIssueNothing =>
      'Ajoutez au moins un titre, un message ou une image.';

  @override
  String get composerIssueSchedule => 'Choisissez la date de publication.';

  @override
  String get composerIssueExpiry =>
      'La fin de publication doit venir après la publication.';

  @override
  String get composerErrorNetworkTitle => 'Connexion requise';

  @override
  String get composerErrorNetworkBody =>
      'Publier une annonce demande une connexion internet. Votre saisie est conservée : reconnectez-vous, puis réessayez.';

  @override
  String get composerErrorForbiddenTitle =>
      'Vous ne publiez plus pour ce compte';

  @override
  String get composerErrorForbiddenBody =>
      'Le bureau de ce compte officiel a changé. Rapprochez-vous d\'un responsable si c\'est une erreur.';

  @override
  String get composerErrorRejectedTitle => 'Annonce refusée';

  @override
  String get composerErrorRejectedBody =>
      'Le serveur n\'a pas accepté cette annonce. Corrigez la saisie, puis réessayez.';

  @override
  String get composerErrorGoneTitle => 'Annonce introuvable';

  @override
  String get composerErrorGoneBody =>
      'Elle a été supprimée entre-temps, peut-être par un autre membre du compte.';

  @override
  String get composerErrorServerTitle => 'Serveur indisponible';

  @override
  String get composerErrorServerBody =>
      'Le serveur ne répond pas correctement. Réessayez dans un instant.';

  @override
  String get composerErrorUnauthorizedTitle => 'Session expirée';

  @override
  String get composerErrorUnauthorizedBody => 'Reconnectez-vous pour publier.';

  @override
  String get composerPublished => 'Annonce publiée';

  @override
  String get composerUpdated => 'Annonce mise à jour';

  @override
  String get composerDeleted => 'Annonce supprimée';

  @override
  String get statusEdit => 'Modifier l\'annonce';

  @override
  String get statusDelete => 'Supprimer l\'annonce';
}
