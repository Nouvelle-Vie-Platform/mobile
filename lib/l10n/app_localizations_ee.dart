// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ewe (`ee`).
class AppLocalizationsEe extends AppLocalizations {
  AppLocalizationsEe([String locale = 'ee']) : super(locale);

  @override
  String get appName => 'Nouvelle Vie';

  @override
  String get splashTagline => 'Míeɖe gbeƒã kple xɔse.';

  @override
  String get navHome => 'Aƒe';

  @override
  String get navMedia => 'Médias';

  @override
  String get navAnnouncements => 'Annonces';

  @override
  String get navGroups => 'Dzeɖoɖowo';

  @override
  String get navProfile => 'Profil';

  @override
  String get navBible => 'Bible';

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
  String get registerTermsPrefix =>
      'Après la vérification, il vous sera demandé d\'accepter nos ';

  @override
  String get registerTermsLink =>
      'conditions d\'utilisation et notre politique de confidentialité.';

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
  String get radioTitle => 'New Life Radio';

  @override
  String get radioOffAir => 'Hors antenne';

  @override
  String get radioLive => 'À l\'antenne';

  @override
  String get radioUnstable => 'Connexion instable…';

  @override
  String get radioRetrying => 'Reconnexion…';

  @override
  String get radioFailureAntenna => 'Antenne indisponible';

  @override
  String get radioUnavailableMessage =>
      'New Life Radio ne diffuse pas pour le moment.';

  @override
  String get radioLongPressTip => 'Appui long pour ouvrir le live';

  @override
  String get radioOpenLiveHint => 'ouvrir le live';

  @override
  String get radioLiveBadge => 'EN DIRECT';

  @override
  String radioListeners(int count) {
    return '$count à l\'écoute';
  }

  @override
  String get radioReactionHeart => 'Envoyer un cœur';

  @override
  String get radioReactionPray => 'Envoyer une prière';

  @override
  String get radioReactionPraise => 'Envoyer une louange';

  @override
  String get radioReactionFire => 'Envoyer une flamme';

  @override
  String get radioReactionAmen => 'Amen';

  @override
  String get radioReactionAmenLabel => 'Dire Amen';

  @override
  String get radioCommentsLabel => 'Commentaires du direct';

  @override
  String radioCommentSemantics(String name, String body) {
    return '$name : $body';
  }

  @override
  String get radioMessageOptionsHint => 'options du message';

  @override
  String get radioNewMessages => 'Nouveaux messages';

  @override
  String get radioCommentHint => 'Écrire…';

  @override
  String get radioSilencedNotice =>
      'Un modérateur a suspendu vos commentaires jusqu\'à la fin du direct.';

  @override
  String get radioCommentClosed =>
      'Le direct est terminé : les commentaires sont fermés.';

  @override
  String get radioCommentThrottled =>
      'Doucement : un message toutes les cinq secondes.';

  @override
  String get radioCommentInvalid =>
      'Votre message doit faire de 1 à 200 caractères.';

  @override
  String get radioCommentFailed => 'Message non envoyé. Réessayez.';

  @override
  String get radioPseudonymTitle => 'Choisissez un pseudo';

  @override
  String get radioPseudonymMessage =>
      'Il s\'affichera à côté de vos messages pendant les directs.';

  @override
  String get radioPseudonymHint => 'Votre pseudo';

  @override
  String get radioPseudonymConfirm => 'Valider';

  @override
  String get radioPseudonymInvalid => 'Entre 2 et 24 caractères.';

  @override
  String get radioPseudonymThrottled => 'Trop d\'essais. Réessayez plus tard.';

  @override
  String get radioPseudonymFailed => 'Pseudo non enregistré. Réessayez.';

  @override
  String get radioReportAction => 'Signaler ce message';

  @override
  String get radioReported => 'Merci, un modérateur va le regarder.';

  @override
  String get radioAlreadyReported => 'Vous avez déjà signalé ce message.';

  @override
  String get radioMessageGone => 'Ce message n\'est plus disponible.';

  @override
  String get radioActionFailed => 'Action impossible. Réessayez.';

  @override
  String get radioModHide => 'Masquer';

  @override
  String get radioModKeep => 'Garder';

  @override
  String get radioModSilence => 'Réduire au silence';

  @override
  String get radioModResetPseudonym => 'Réinitialiser le pseudo';

  @override
  String get radioModHidden => 'Message masqué.';

  @override
  String get radioModKept => 'Message gardé.';

  @override
  String get radioModSilenced =>
      'Auteur réduit au silence jusqu\'à la fin du direct.';

  @override
  String get radioModPseudonymReset => 'Pseudo réinitialisé.';

  @override
  String get radioModNotGuest =>
      'Seul le pseudo d\'un invité peut être réinitialisé.';

  @override
  String get radioReportedQueue => 'Messages signalés';

  @override
  String radioReportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count signalements',
      one: '1 signalement',
    );
    return '$_temp0';
  }

  @override
  String get radioReportedEmpty => 'Aucun message en attente.';

  @override
  String get radioStopListening => 'Arrêter l\'écoute';

  @override
  String get actionSeeAll => 'Kpɔ wo katã';

  @override
  String get actionListen => 'Écouter';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionLoading => 'Chargement…';

  @override
  String get sectionLatestTeachings => 'Dernières publications';

  @override
  String get mediaTitle => 'Médiathèque';

  @override
  String get mediaSearchHint => 'Rechercher un message...';

  @override
  String get filterAll => 'Tout';

  @override
  String get filterTeachings => 'Messages';

  @override
  String get seriesTag => 'Thème';

  @override
  String seriesMessagesCount(int count) {
    return '$count messages';
  }

  @override
  String get groupsDiscoverMore => 'Découvrir plus de groupes';

  @override
  String get communityTitle => 'Échanges';

  @override
  String get echangesDiscover => 'Groupes à rejoindre';

  @override
  String echangesHostedBy(String name) {
    return 'Animé par $name';
  }

  @override
  String get requestsTitle => 'Requêtes';

  @override
  String get echangesTabMessages => 'Messages';

  @override
  String get echangesTabRequests => 'Requêtes';

  @override
  String get requestsEmptyTitle => 'Aucune requête';

  @override
  String get requestsEmpty =>
      'Vos demandes de prière, suggestions et réclamations apparaîtront ici, avec leur suivi.';

  @override
  String get requestsAdd => 'Nouvelle requête';

  @override
  String get requestsLoadError => 'Impossible de lire vos requêtes.';

  @override
  String get requestStatusNew => 'Nouvelle';

  @override
  String get requestStatusInProgress => 'En cours';

  @override
  String get requestStatusResolved => 'Traitée';

  @override
  String get requestStatusArchived => 'Archivée';

  @override
  String requestSentOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String get memberMessage => 'Message';

  @override
  String get memberProfileSubtitle => 'Membre de la communauté';

  @override
  String get groupInfoAbout => 'Description';

  @override
  String get groupInfoSharedMedia => 'Médias partagés';

  @override
  String get mediaSaved => 'Image enregistrée dans vos photos';

  @override
  String get mediaSaveErrorPermission =>
      'Accès aux photos refusé. Autorisez-le dans les réglages.';

  @override
  String get mediaSaveErrorNetwork =>
      'Échec du téléchargement. Vérifiez votre connexion.';

  @override
  String get mediaSaveErrorUnsupported =>
      'Enregistrement indisponible sur cet appareil.';

  @override
  String get mediaSaveError => 'Impossible d\'enregistrer l\'image.';

  @override
  String groupMembers(int count) {
    return '$count membres';
  }

  @override
  String groupMembersWithRole(int count, String role) {
    return '$count membres • $role';
  }

  @override
  String get chatAuthorRemoved => 'Membre retiré';

  @override
  String get chatReadOnly =>
      'Seuls les animateurs peuvent écrire dans ce groupe.';

  @override
  String get chatEmpty =>
      'Aucun message pour l\'instant. Soyez le premier à écrire.';

  @override
  String get echangesEmptyTitle => 'Aucune conversation';

  @override
  String get echangesEmpty =>
      'Vos groupes et discussions apparaîtront ici. Tirez vers le bas pour rafraîchir.';

  @override
  String get echangesLoadError => 'Impossible de lire vos conversations.';

  @override
  String get echangesJoinOpen => 'Ouvert à tous';

  @override
  String get echangesJoinOnRequest => 'Sur demande';

  @override
  String get echangesJoinPending => 'Demande envoyée';

  @override
  String get groupRoleLeader => 'Animateur';

  @override
  String get groupRoleModerator => 'Modérateur';

  @override
  String get groupRoleMember => 'Membre';

  @override
  String get chatMessageHint => 'Votre message...';

  @override
  String get chatToday => 'Aujourd\'hui';

  @override
  String chatUnreadSeparator(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '$count message non lu',
    );
    return '$_temp0';
  }

  @override
  String get chatMediaUnsupported =>
      'Ce message contient un média que cette version de l\'application ne sait pas encore afficher.';

  @override
  String get echangesMediaPreview => 'Pièce jointe';

  @override
  String get chatMessageFailed => 'Non envoyé. Touchez pour réessayer.';

  @override
  String get chatRetry => 'Réessayer';

  @override
  String get chatDiscard => 'Supprimer';

  @override
  String echangesUnreadBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '$count message non lu',
    );
    return '$_temp0';
  }

  @override
  String get teachingAppBarTitle => 'Message';

  @override
  String get actionDownload => 'Télécharger';

  @override
  String get actionMyNotes => 'Mes notes';

  @override
  String get actionShare => 'Partager';

  @override
  String get tabDescription => 'Description';

  @override
  String contentGuests(String names) {
    return 'Avec $names';
  }

  @override
  String get listAnd => 'et';

  @override
  String get teachingVerses => 'Versets';

  @override
  String tabNotesCount(int count) {
    return 'Notes ($count)';
  }

  @override
  String get actionDownloadAudio => 'Télécharger l\'audio';

  @override
  String get downloadStateDownloading => 'Téléchargement en cours';

  @override
  String downloadProgressPercent(int percent) {
    return '$percent %';
  }

  @override
  String get downloadStatePaused => 'En pause';

  @override
  String get downloadStateWaitingWifi => 'En attente de wifi';

  @override
  String get downloadStateComplete => 'Téléchargé';

  @override
  String get downloadStateFailed => 'Échec du téléchargement';

  @override
  String get downloadActionPause => 'Mettre en pause';

  @override
  String get downloadActionResume => 'Reprendre le téléchargement';

  @override
  String get downloadActionRetry => 'Réessayer le téléchargement';

  @override
  String get downloadActionDelete => 'Supprimer le téléchargement';

  @override
  String get downloadDeleteConfirmTitle => 'Supprimer le téléchargement ?';

  @override
  String get downloadDeleteConfirmMessage =>
      'Le fichier sera effacé de cet appareil. Vous pourrez le télécharger de nouveau plus tard.';

  @override
  String get downloadDeleteConfirmAction => 'Supprimer';

  @override
  String get downloadStateQueued => 'En attente';

  @override
  String get profileDownloads => 'Téléchargements';

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String get downloadsEmptyTitle => 'Aucun téléchargement';

  @override
  String get downloadsEmptyMessage =>
      'Les messages que vous téléchargez pour les écouter hors ligne apparaîtront ici.';

  @override
  String downloadsStorageUsed(String size) {
    return '$size Mo utilisés';
  }

  @override
  String downloadSize(String size) {
    return '$size Mo';
  }

  @override
  String get downloadsUnknownTitle => 'Message téléchargé';

  @override
  String get downloadUpdateAvailable => 'Mise à jour disponible';

  @override
  String get downloadActionUpdate => 'Mettre à jour';

  @override
  String downloadPurgeNotice(String title) {
    return '« $title » a été retiré par la médiathèque et supprimé de vos téléchargements.';
  }

  @override
  String get downloadPurgeNoticeUnnamed =>
      'Un message a été retiré par la médiathèque et supprimé de vos téléchargements.';

  @override
  String get downloadPurgeDismiss => 'Ignorer';

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
  String prayerRequestPraying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres en prière',
      one: '$count membre en prière',
    );
    return '$_temp0';
  }

  @override
  String get newRequestAppBarTitle => 'Nouvelle requête';

  @override
  String get newRequestTypeLabel => 'Type de requête';

  @override
  String get requestTypePrayer => 'Demande de prière';

  @override
  String get requestTypeSuggestion => 'Suggestion';

  @override
  String get requestTypeComplaint => 'Réclamation';

  @override
  String get newRequestTitleLabel => 'Objet';

  @override
  String get newRequestTitleHint => 'En quelques mots';

  @override
  String get newRequestTitleTooShort => 'Au moins 3 caractères.';

  @override
  String get newRequestContentEmpty => 'Écrivez votre message.';

  @override
  String get newRequestShareLabel => 'Partager avec la communauté';

  @override
  String get newRequestShareSubtitle =>
      'Elle apparaîtra sur le mur de prière. Sinon, seule l\'équipe pastorale la lira.';

  @override
  String get newRequestSent => 'Requête envoyée.';

  @override
  String get newRequestErrorNetwork =>
      'Envoi impossible : vérifiez votre connexion.';

  @override
  String get newRequestErrorGeneric => 'L\'envoi a échoué. Réessayez.';

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
  String get notesTab => 'Notes';

  @override
  String get notesGuestTitle => 'Vos notes vous attendent';

  @override
  String get notesGuestMessage =>
      'Connectez-vous pour écrire vos notes et les retrouver sur tous vos appareils.';

  @override
  String get notesEmptyTitle => 'Aucune note';

  @override
  String get notesEmptyMessage => 'Touchez + pour écrire votre première note.';

  @override
  String get notesFilterAll => 'Toutes';

  @override
  String get notesUntitled => 'Nouvelle note';

  @override
  String get notesBodyHint => 'Écrivez ici…';

  @override
  String get notesDone => 'Terminé';

  @override
  String get notesPin => 'Épingler';

  @override
  String get notesUnpin => 'Désépingler';

  @override
  String get notesDelete => 'Supprimer';

  @override
  String get notesDeleteConfirmTitle => 'Supprimer cette note ?';

  @override
  String get notesDeleteConfirmMessage =>
      'Elle sera retirée de tous vos appareils.';

  @override
  String get notesCategoryTitle => 'Catégorie';

  @override
  String get notesCategoryAdd => 'Ajouter une catégorie';

  @override
  String get notesCategoryNameHint => 'Nom de la catégorie';

  @override
  String get notesCategoryCreate => 'Ajouter';

  @override
  String get notesCategoryNone => 'Sans catégorie';

  @override
  String get notesCategoryEditTitle => 'Modifier la catégorie';

  @override
  String get notesCategoryDelete => 'Supprimer la catégorie';

  @override
  String notesCategoryDeleteConfirm(String name) {
    return 'Supprimer « $name » ? Ses notes resteront, sans catégorie.';
  }

  @override
  String get notesShareFailed => 'Le partage n\'a pas abouti.';

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
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer mon compte';

  @override
  String get deleteAccountLead =>
      'Cette action est définitive. Elle ne peut pas être annulée, et personne à l\'église ne peut la défaire pour vous.';

  @override
  String get deleteAccountErasedTitle => 'Ce qui est effacé';

  @override
  String get deleteAccountErasedIdentity =>
      'Votre identité : nom, civilité, email, téléphone.';

  @override
  String get deleteAccountErasedNotes => 'Vos notes spirituelles.';

  @override
  String get deleteAccountErasedProgress =>
      'Votre progression d\'écoute, sur cet appareil et sur les autres.';

  @override
  String get deleteAccountKeptTitle => 'Ce qui reste, sans votre nom';

  @override
  String get deleteAccountKeptMessages =>
      'Vos messages dans les groupes restent lisibles, détachés de vous.';

  @override
  String get deleteAccountKeptPrayers =>
      'Les prières que d\'autres ont portées avec vous ne disparaissent pas du mur.';

  @override
  String get deleteAccountReuse =>
      'Votre email redevient libre : vous pourrez vous réinscrire, mais ce sera un compte entièrement neuf, sans rien de celui-ci.';

  @override
  String get deleteAccountConfirmCheckbox =>
      'Je comprends que cette action est définitive.';

  @override
  String get deleteAccountAction => 'Supprimer définitivement';

  @override
  String get deleteAccountErrorNetwork =>
      'Suppression impossible : pas de réseau. Votre compte est intact.';

  @override
  String get deleteAccountErrorServer =>
      'Le serveur n\'a pas pu traiter la demande. Votre compte est intact, réessayez.';

  @override
  String get mediaSettings => 'Qualité';

  @override
  String get mediaSettingsTitle => 'Qualité & données';

  @override
  String get mediaSettingsStreaming => 'Écoute d\'un message';

  @override
  String get mediaSettingsDownload => 'Téléchargement';

  @override
  String get mediaSettingsDownloadOnCellular =>
      'Télécharger en données mobiles';

  @override
  String get mediaSettingsDownloadOnCellularSubtitle =>
      'Par défaut, les téléchargements attendent le wifi pour préserver votre forfait.';

  @override
  String get branchScopeTitle => 'Mon assemblée';

  @override
  String get branchScopeLead =>
      'Choisissez l\'assemblée dont vous voulez suivre les messages, les rassemblements et les annonces. L\'agenda et le mur de prière ne changent pas.';

  @override
  String get branchScopeAll => 'Toutes les assemblées';

  @override
  String get branchScopeAllSubtitle =>
      'Tout ce que publie l\'église, où qu\'elle le publie.';

  @override
  String get branchScopeEmpty =>
      'La liste des assemblées arrivera à la première synchronisation.';

  @override
  String get mediaSettingsRadio => 'Radio';

  @override
  String get mediaSettingsListening => 'Écoute';

  @override
  String get qualityQuestionRadio => 'Quelle qualité pour la radio ?';

  @override
  String get qualityQuestionListening => 'Quelle qualité pour l\'écoute ?';

  @override
  String get qualityQuestionDownload => 'Quelle qualité en téléchargement ?';

  @override
  String get qualityLead =>
      'La qualité s\'adapte à votre réseau, ou se fixe pour économiser vos données.';

  @override
  String get radioQualityMinimum => 'Minimum';

  @override
  String qualityPerHour(int mb) {
    return '≈ $mb Mo par heure';
  }

  @override
  String get qualityAdaptive => 'S\'adapte à votre réseau';

  @override
  String get mediaQualityAuto => 'Automatique';

  @override
  String get mediaQualityLow => 'Économie';

  @override
  String get mediaQualityMid => 'Standard';

  @override
  String get mediaQualityHigh => 'Haute';

  @override
  String get themeSectionTitle => 'Apparence';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeAutoHoursTitle => 'Heures de bascule';

  @override
  String get themeDarkFrom => 'Passe en sombre à';

  @override
  String get themeLightFrom => 'Revient au clair à';

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
  String get authAlreadyMember => 'Déjà membre ?';

  @override
  String get authIdentifierTitle => 'Rejoignez-nous';

  @override
  String get authIdentifierSubtitle =>
      'Entrez votre numéro ou votre email pour continuer.';

  @override
  String get authReasonCommunity => 'Connectez-vous pour accéder aux échanges.';

  @override
  String get authReasonProfile => 'Connectez-vous pour accéder à votre profil.';

  @override
  String get authPhoneHint => '90 12 34 56';

  @override
  String get authEmailHint => 'jean.kossi@email.com';

  @override
  String get authNoticeEmailOnly =>
      'Woaɖo wò gegeɖeme dzesi la ɖa to email dzi.';

  @override
  String get authNoticePhoneOnly =>
      'Woaɖo wò gegeɖeme dzesi la ɖa to wò kaƒomɔ̃ dzi.';

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
  String get branchMotherChurch => 'Église Mère';

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
  String get stateErrorRefusedMessage =>
      'Ce contenu n\'est pas accessible pour l\'instant. Votre connexion internet n\'est pas en cause.';

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
  String get absenceOfflineMediaTitle => 'Màte ŋu ase o ne internet meli o';

  @override
  String get absenceOfflineMediaMessage =>
      'Ele be nàka internet ŋu hafi ase nuɖeɖiwo. Gbugbɔ ka internet ŋu ne nàse.';

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
  String get teachingRetractedTitle => 'Gbedeasi sia megali o';

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

  @override
  String get drawerOpen => 'Ouvrir le menu';

  @override
  String get drawerTerms => 'CGU';

  @override
  String get drawerPrivacy => 'Politique de confidentialité';

  @override
  String get drawerAbout => 'À propos';

  @override
  String get aboutChurchName => 'Église Évangélique Nouvelle Vie';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String legalFooterUpdated(int version, String date) {
    return 'Version $version — mise à jour le $date';
  }

  @override
  String legalFooterVersion(int version) {
    return 'Version $version';
  }

  @override
  String get legalGateTitleFirst => 'Avant de commencer';

  @override
  String get legalGateTitleUpdated => 'Nos conditions ont changé';

  @override
  String get legalGateSubtitle => 'Votre accord est nécessaire pour continuer.';

  @override
  String get legalGateAcceptTerms =>
      'J\'ai lu et j\'accepte les conditions générales d\'utilisation.';

  @override
  String get legalGateAcceptPrivacy =>
      'J\'ai lu et j\'accepte la politique de confidentialité.';

  @override
  String get legalGateErrorNetwork =>
      'Connexion requise pour enregistrer votre accord.';

  @override
  String get legalGateErrorUnauthorized =>
      'Votre session a expiré. Reconnectez-vous pour enregistrer votre accord.';

  @override
  String get legalGateErrorOutdated => 'Ces conditions ont été mises à jour.';

  @override
  String get legalGateErrorServer =>
      'Le serveur n\'a pas pu enregistrer votre accord.';

  @override
  String get legalGateReload => 'Recharger';

  @override
  String get legalNoticeBody =>
      'En utilisant l\'application, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.';

  @override
  String get legalNoticeTerms => 'Conditions d\'utilisation';

  @override
  String get legalNoticePrivacy => 'Confidentialité';

  @override
  String get legalNoticeDismiss => 'J\'ai compris';

  @override
  String get appUpdateBody =>
      'Une nouvelle version de l\'application est disponible.';

  @override
  String get appUpdateAction => 'Mettre à jour';

  @override
  String get appUpdateDismiss => 'Plus tard';

  @override
  String get miniPlayerLiveBadge => 'EN DIRECT';

  @override
  String get miniPlayerOnAirBadge => 'À l\'antenne';

  @override
  String miniPlayerOpen(String title) {
    return 'Ouvrir le lecteur : $title';
  }

  @override
  String get miniPlayerSkipBackward => 'Reculer de 30 secondes';

  @override
  String get miniPlayerSkipForward => 'Avancer de 30 secondes';

  @override
  String get miniPlayerReplay => 'Rejouer';

  @override
  String get miniPlayerRelaunch => 'Relancer l\'écoute';

  @override
  String get miniPlayerClose => 'Fermer le lecteur';

  @override
  String get chatSearchHint => 'Rechercher';

  @override
  String get chatSearchTitle => 'Rechercher';

  @override
  String chatSearchMinLength(int count) {
    return 'Tapez au moins $count caractères pour chercher dans les noms et les messages.';
  }

  @override
  String get chatSearchChats => 'Discussions';

  @override
  String get chatSearchMessages => 'Messages';

  @override
  String get chatSearchMore => 'Plus de résultats';

  @override
  String get chatSearchOffline =>
      'L\'historique plus ancien n\'a pas pu être consulté. Les résultats ci-dessus viennent du téléphone.';

  @override
  String get chatSearchNoResult => 'Aucun résultat.';

  @override
  String get chatSearchUnknownChat => 'Discussion';

  @override
  String get chatArchive => 'Archiver';

  @override
  String get chatUnarchive => 'Désarchiver';

  @override
  String get chatPin => 'Épingler';

  @override
  String get chatUnpin => 'Désépingler';

  @override
  String get chatMarkRead => 'Marquer comme lu';

  @override
  String get chatPinnedLabel => 'Épinglée';

  @override
  String chatPinLimit(int count) {
    return 'Vous pouvez épingler $count discussions au plus. Désépinglez-en une d\'abord.';
  }

  @override
  String get chatArrangeFailed => 'Cette discussion n\'a pas pu être rangée.';

  @override
  String get chatArchivedNotice => 'Discussion archivée';

  @override
  String get chatUndo => 'Annuler';

  @override
  String chatArchivedRow(int count) {
    return 'Archivées ($count)';
  }

  @override
  String get chatArchivedTitle => 'Archivées';

  @override
  String get chatArchivedEmptyTitle => 'Aucune discussion archivée';

  @override
  String get chatArchivedEmpty =>
      'Faites glisser une discussion vers la gauche pour l\'archiver. Elle reste ici même quand un message arrive.';

  @override
  String get m6NewConversation => 'Nouvelle discussion';

  @override
  String get m6NewGroup => 'Nouveau groupe';

  @override
  String get m6SearchContacts => 'Rechercher un nom';

  @override
  String get m6NoContacts =>
      'Personne à qui écrire pour l\'instant : vous pouvez écrire aux membres de vos groupes.';

  @override
  String get m6NoContactMatch => 'Aucun nom ne correspond.';

  @override
  String get m6DirectFirstMessage =>
      'Écrivez le premier message : la discussion commencera avec lui.';

  @override
  String get m6CreateGroupTitle => 'Nouveau groupe';

  @override
  String get m6GroupNameLabel => 'Nom du groupe';

  @override
  String get m6GroupNameTooShort => 'Au moins 3 caractères';

  @override
  String get m6GroupDescriptionLabel => 'Description (facultative)';

  @override
  String get m6GroupMembersLabel => 'Membres';

  @override
  String get m6CreateGroupSubmit => 'Créer le groupe';

  @override
  String get m6CreateGroupFailed =>
      'Le groupe n\'a pas été créé. Vérifiez votre connexion, puis touchez de nouveau « Créer le groupe ».';

  @override
  String get m6Join => 'Rejoindre';

  @override
  String get m6RequestJoin => 'Demander';

  @override
  String get m6Leave => 'Quitter le groupe';

  @override
  String get m6LeaveConfirm =>
      'Vous ne recevrez plus les messages de ce groupe.';

  @override
  String get m6Cancel => 'Annuler';

  @override
  String get m6AddMembers => 'Ajouter des membres';

  @override
  String get m6AddMembersSubmit => 'Ajouter';

  @override
  String get m6NoOneToAdd =>
      'Toutes les personnes de vos groupes sont déjà membres.';

  @override
  String get m6MakeModerator => 'Nommer modérateur';

  @override
  String get m6RemoveModerator => 'Retirer le rôle de modérateur';

  @override
  String get m6RemoveMember => 'Retirer du groupe';

  @override
  String get m6RemoveConfirm =>
      'Cette personne ne recevra plus les messages du groupe.';

  @override
  String get m6MemberOptions => 'Options du membre';

  @override
  String get m6PendingRequests => 'Demandes d\'adhésion';

  @override
  String get m6Approve => 'Accepter';

  @override
  String get m6Reject => 'Refuser';

  @override
  String get m6RequestUnnamed => 'Une personne sans nom renseigné';

  @override
  String get m6ActionRefused => 'Ce geste n\'est pas permis ici.';

  @override
  String get m6ActionUnreachable =>
      'Pas de réponse du serveur. Vérifiez votre connexion.';

  @override
  String get chatTyping => 'écrit…';

  @override
  String chatTypingNamed(String name) {
    return '$name écrit…';
  }

  @override
  String chatTypingSeveral(int count) {
    return '$count personnes écrivent…';
  }

  @override
  String get chatPresenceOnline => 'en ligne';

  @override
  String chatLastSeenToday(String time) {
    return 'vu aujourd\'hui à $time';
  }

  @override
  String chatLastSeenYesterday(String time) {
    return 'vu hier à $time';
  }

  @override
  String chatLastSeenOn(String date, String time) {
    return 'vu le $date à $time';
  }

  @override
  String get chatReceiptSent => 'Envoyé';

  @override
  String get chatReceiptDelivered => 'Distribué';

  @override
  String get chatReceiptRead => 'Lu';

  @override
  String get messageInfoAction => 'Infos';

  @override
  String get messageInfoTitle => 'Infos du message';

  @override
  String get messageInfoReadBy => 'Lu par';

  @override
  String get messageInfoDeliveredTo => 'Distribué à';

  @override
  String get messageInfoPending => 'Pas encore reçu';

  @override
  String get messageInfoEmpty => 'Personne n\'attend ce message.';

  @override
  String get messageInfoError =>
      'Impossible de charger les infos du message. Vérifiez votre connexion.';

  @override
  String messageInfoToday(String time) {
    return 'aujourd\'hui à $time';
  }

  @override
  String messageInfoYesterday(String time) {
    return 'hier à $time';
  }

  @override
  String messageInfoOn(String date, String time) {
    return '$date à $time';
  }

  @override
  String get privacyMenu => 'Confidentialité';

  @override
  String get privacyMenuSubtitle => 'Accusés de lecture, vu à et en ligne';

  @override
  String get privacyTitle => 'Confidentialité';

  @override
  String get privacyReadReceipts => 'Accusés de lecture';

  @override
  String get privacyReadReceiptsHint =>
      'Si vous les désactivez, les autres ne verront plus que vous avez lu leurs messages, et vous ne verrez plus quand ils ont lu les vôtres. Ne s\'applique pas aux groupes.';

  @override
  String get privacyPresence => 'Vu à et en ligne';

  @override
  String get privacyPresenceHint =>
      'Si vous le désactivez, les autres ne verront plus quand vous êtes en ligne, et vous ne verrez plus quand ils le sont.';

  @override
  String get privacyLoadError =>
      'Impossible de charger vos réglages de confidentialité.';

  @override
  String get privacySaveError =>
      'Le réglage n\'a pas pu être enregistré. Réessayez.';

  @override
  String get notificationYou => 'Vous';

  @override
  String get notificationNewMessage => 'Nouveau message';

  @override
  String notificationNewMessageFrom(String name) {
    return 'Nouveau message de $name';
  }

  @override
  String get notificationReply => 'Répondre';

  @override
  String get notificationReplyHint => 'Votre message';

  @override
  String get notificationMarkRead => 'Marquer comme lu';

  @override
  String notificationSummaryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: '1 nouveau message',
    );
    return '$_temp0';
  }

  @override
  String notificationSummaryText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count discussions',
      one: 'dans 1 discussion',
    );
    return '$_temp0';
  }

  @override
  String get notificationPreviewSetting => 'Afficher le contenu des messages';

  @override
  String get notificationPreviewSettingHint =>
      'Dans les notifications. Sinon : « Nouveau message »';

  @override
  String get chatMuteMenu => 'Options de la discussion';

  @override
  String get chatMute => 'Mettre en sourdine';

  @override
  String get chatMuteTitle => 'Mettre en sourdine pendant…';

  @override
  String get chatMuteEightHours => '8 heures';

  @override
  String get chatMuteOneWeek => '1 semaine';

  @override
  String get chatMuteForever => 'Toujours';

  @override
  String get chatUnmute => 'Réactiver les notifications';

  @override
  String get chatMuteFailed =>
      'La sourdine n\'a pas pu être réglée. Vérifiez votre connexion.';

  @override
  String get conversationMuted => 'En sourdine';

  @override
  String get chatMessageDeleted => 'Ce message a été supprimé';

  @override
  String get chatMessageEdited => 'Modifié';

  @override
  String get chatMessageForwarded => 'Transféré';

  @override
  String get chatQuoteDeleted => 'Message supprimé';

  @override
  String get chatQuoteMedia => 'Média';

  @override
  String get chatQuoteAudio => 'Message vocal';

  @override
  String get chatQuoteImage => 'Photo';

  @override
  String get chatQuoteYou => 'Vous';

  @override
  String chatReplyingTo(String name) {
    return 'Réponse à $name';
  }

  @override
  String get chatReplying => 'Réponse';

  @override
  String get chatEditing => 'Modifier le message';

  @override
  String get chatCancelReply => 'Annuler la réponse';

  @override
  String get chatCancelEdit => 'Annuler la modification';

  @override
  String get chatActionReply => 'Répondre';

  @override
  String get chatActionCopy => 'Copier';

  @override
  String get chatActionForward => 'Transférer';

  @override
  String get chatActionEdit => 'Modifier';

  @override
  String get chatActionDeleteForMe => 'Supprimer pour moi';

  @override
  String get chatActionDeleteForEveryone => 'Supprimer pour tous';

  @override
  String get chatMoreReactions => 'Plus de réactions';

  @override
  String get chatCopied => 'Message copié';

  @override
  String get chatDeleteForEveryoneConfirm =>
      'Ce message sera remplacé par « Ce message a été supprimé » pour tout le monde.';

  @override
  String get chatForwardTitle => 'Transférer à…';

  @override
  String get chatForwardSend => 'Envoyer';

  @override
  String get chatForwardEmpty => 'Aucune discussion où transférer.';

  @override
  String get chatForwardLimit => '5 discussions au plus.';

  @override
  String get chatForwardDone => 'Message transféré';

  @override
  String get chatGestureWindowClosed =>
      'Le délai est passé : ce n\'est plus possible.';

  @override
  String get chatGestureRefused => 'Ce n\'est pas possible pour ce message.';

  @override
  String get chatGestureUnreachable => 'Pas de connexion. Réessayez.';

  @override
  String get chatReactionsTitle => 'Réactions';

  @override
  String get chatReactionsRemove => 'Touchez pour retirer';

  @override
  String get chatQuoteNotFound => 'Message introuvable';

  @override
  String get m4ChatAttach => 'Joindre';

  @override
  String get m4ChatCamera => 'Appareil photo';

  @override
  String get m4ChatRecordVoice => 'Maintenir pour enregistrer un vocal';

  @override
  String get m4AttachGallery => 'Galerie';

  @override
  String get m4AttachVideo => 'Vidéo';

  @override
  String get m4AttachRecordVideo => 'Filmer';

  @override
  String get m4AttachDocument => 'Document';

  @override
  String get m4AttachAudio => 'Audio';

  @override
  String get m4AttachLocation => 'Position';

  @override
  String get m4AttachContact => 'Contact';

  @override
  String get m4PreviewVoice => '🎤 Message vocal';

  @override
  String get m4PreviewAudio => '🎵 Audio';

  @override
  String get m4PreviewImage => '📷 Photo';

  @override
  String get m4PreviewVideo => '🎥 Vidéo';

  @override
  String get m4PreviewDocument => '📄 Document';

  @override
  String get m4PreviewLocation => '📍 Position';

  @override
  String get m4PreviewContact => '👤 Contact';

  @override
  String get m4VoiceSlideToCancel => '‹ Glisser pour annuler';

  @override
  String get m4VoiceCancel => 'Annuler le vocal';

  @override
  String get m4VoiceSend => 'Envoyer le vocal';

  @override
  String get m4VoiceLockHint => 'Glisser vers le haut pour verrouiller';

  @override
  String get m4VoiceMicDenied =>
      'Autorisez le micro pour enregistrer un vocal.';

  @override
  String get m4VoiceTooShort => 'Maintenez le micro pour enregistrer.';

  @override
  String get m4MediaErrorTooLarge => 'Fichier trop volumineux.';

  @override
  String get m4MediaErrorTooLong => 'Trop long pour être envoyé.';

  @override
  String get m4MediaErrorType => 'Ce type de fichier n\'est pas accepté.';

  @override
  String get m4MediaErrorMissing => 'Le fichier n\'est plus sur le téléphone.';

  @override
  String get m4MediaErrorUnreadable => 'Ce fichier n\'a pas pu être préparé.';

  @override
  String get m4MediaUnavailable => 'Média indisponible';

  @override
  String get m4MediaUnsupportedKind =>
      'Ce type de message n\'est pas encore pris en charge.';

  @override
  String get m4LocationTitle => 'Envoyer ma position ?';

  @override
  String get m4LocationLabelHint => 'Nom du lieu (facultatif)';

  @override
  String get m4LocationDisabled =>
      'La localisation est désactivée sur ce téléphone.';

  @override
  String get m4LocationDenied =>
      'Autorisez la localisation pour partager votre position.';

  @override
  String get m4LocationOpen => 'Ouvrir dans Cartes';

  @override
  String get m4LocationDefaultLabel => 'Position partagée';

  @override
  String get m4ContactCall => 'Appeler';

  @override
  String get m4DocumentOpenFailed => 'Impossible d\'ouvrir ce document.';

  @override
  String get m4DocumentUnsupported =>
      'Ce type de fichier ne peut pas être envoyé.';

  @override
  String get m4CaptionHint => 'Ajouter une légende…';

  @override
  String get m4Send => 'Envoyer';

  @override
  String get m4Cancel => 'Annuler';

  @override
  String get m4SharedMedia => 'Médias partagés';

  @override
  String get m4QuoteVideo => 'Vidéo';

  @override
  String get m4QuoteDocument => 'Document';

  @override
  String get m4QuoteLocation => 'Position';

  @override
  String get m4QuoteContact => 'Contact';

  @override
  String get sharedContentTitle => 'Médias, liens et docs';

  @override
  String get sharedContentMedia => 'Médias';

  @override
  String get sharedContentLinks => 'Liens';

  @override
  String get sharedContentDocs => 'Docs';

  @override
  String get sharedContentMediaEmpty => 'Aucune image ni vidéo partagée';

  @override
  String get sharedContentLinksEmpty => 'Aucun lien partagé';

  @override
  String get sharedContentDocsEmpty => 'Aucun document partagé';

  @override
  String qualityHoursPerGigabyte(int hours) {
    return '1 Go de forfait ≈ $hours h d\'écoute';
  }

  @override
  String qualityHoursPerGigabyteAtLeast(int hours) {
    return '1 Go de forfait ≈ $hours h d\'écoute au moins';
  }

  @override
  String get qualityNowWifi => 'Vous êtes en wifi';

  @override
  String get qualityNowCellular => 'Vous êtes en données mobiles';

  @override
  String get qualityNetworkEdge => 'Passe même en 2G (EDGE)';

  @override
  String get qualityNetworkWeak => 'Une 2G correcte ou la 3G suffisent';

  @override
  String get qualityNetwork3g => 'La 3G suffit';

  @override
  String get qualityNetworkGood => 'Une bonne 3G ou la 4G';

  @override
  String get qualityNetworkStrong => 'Demande la 4G ou le wifi';

  @override
  String get qualityNetworkAdaptive =>
      'Tous réseaux : descend seule quand ça faiblit';

  @override
  String get qualityNetworkListeningAuto =>
      'Économe en données mobiles, pleine en wifi';

  @override
  String get qualitySoundVoice => 'Voix claire, musique sourde';

  @override
  String get qualitySoundVoiceMusic => 'Voix nette, musique correcte';

  @override
  String get qualitySoundClear => 'Voix et musique nettes';

  @override
  String get qualitySoundFull => 'Voix et musique pleines';

  @override
  String get qualitySoundAdaptive => 'La meilleure que permet votre réseau';

  @override
  String get radioOfflineTitle => 'Pas de réseau pour l\'instant';

  @override
  String get radioOfflineMessage =>
      'La radio repart toute seule dès que le réseau revient.';

  @override
  String get noteEditorPlaceholder => 'Ŋlɔ wò nuŋlɔɖi…';

  @override
  String get noteEditorOpenFormat => 'Mise en forme';

  @override
  String get noteEditorFormatTitle => 'Nɔnɔme';

  @override
  String get noteEditorClose => 'Tu';

  @override
  String get noteEditorStyleTitle => 'Tanya';

  @override
  String get noteEditorStyleSubtitle => 'Sous-titre';

  @override
  String get noteEditorStyleHeading => 'Titre secondaire';

  @override
  String get noteEditorStyleBody => 'Nuŋɔŋlɔ';

  @override
  String get noteEditorBold => 'Gras';

  @override
  String get noteEditorItalic => 'Italique';

  @override
  String get noteEditorUnderline => 'Souligné';

  @override
  String get noteEditorStrike => 'Barré';

  @override
  String get noteEditorHighlight => 'Surligner';

  @override
  String get noteEditorTextColor => 'Couleur du texte';

  @override
  String get noteEditorBulletList => 'Liste à puces';

  @override
  String get noteEditorNumberedList => 'Liste numérotée';

  @override
  String get noteEditorChecklist => 'Cases à cocher';

  @override
  String get noteEditorOutdent => 'Diminuer le retrait';

  @override
  String get noteEditorIndent => 'Augmenter le retrait';

  @override
  String get noteEditorMonostyle => 'Monostyle';

  @override
  String get noteEditorQuote => 'Citation';

  @override
  String get noteLinkAdd => 'Ajouter un lien';

  @override
  String get noteLinkSheetTitle => 'Ajouter un lien';

  @override
  String get noteLinkToNote => 'Une note';

  @override
  String get noteLinkToTeaching => 'Un enseignement';

  @override
  String get noteLinkToWeb => 'Une adresse web';

  @override
  String get noteLinkToBible => 'La Bible';

  @override
  String get noteLinkSearch => 'Rechercher';

  @override
  String get noteLinkInvalidUrl => 'Adresse web invalide';

  @override
  String get noteLinkInsert => 'Insérer le lien';

  @override
  String get noteLinkNoResult => 'Aucun résultat';

  @override
  String get noteLinkNoteMissing => 'Cette note n\'existe plus';

  @override
  String get noteLinkCannotOpen => 'Impossible d\'ouvrir ce lien';

  @override
  String get noteAttachmentButton => 'Joindre';

  @override
  String get noteAttachmentChooseMedia => 'Choisir une photo ou une vidéo';

  @override
  String get noteAttachmentTakeMedia => 'Prendre une photo ou une vidéo';

  @override
  String get noteAttachmentTakePhoto => 'Photo';

  @override
  String get noteAttachmentTakeVideo => 'Vidéo';

  @override
  String get noteAttachmentRecordAudio => 'Enregistrer un audio';

  @override
  String get noteAttachmentAttachFile => 'Joindre un fichier';

  @override
  String get noteAttachmentRecording => 'Enregistrement…';

  @override
  String get noteAttachmentRecordStop => 'Terminer';

  @override
  String get noteAttachmentRecordCancel => 'Annuler';

  @override
  String get noteAttachmentMicDenied =>
      'Autorisez le micro pour enregistrer un audio.';

  @override
  String get noteAttachmentRecordingName => 'Enregistrement audio';

  @override
  String get noteAttachmentPreparing => 'En préparation…';

  @override
  String get noteAttachmentUploading => 'Envoi…';

  @override
  String get noteAttachmentFailed => 'Échec de l\'envoi';

  @override
  String get noteAttachmentRetry => 'Réessayer';

  @override
  String get noteAttachmentUnavailable => 'Pièce jointe indisponible';

  @override
  String get bibleTabHome => 'Accueil';

  @override
  String get bibleTabBible => 'Bible';

  @override
  String get bibleTabFavorites => 'Favori';

  @override
  String get bibleTabNotes => 'Notes';

  @override
  String get bibleTabMore => 'Plus';

  @override
  String get bibleBackToHome => 'Retour à l\'accueil';

  @override
  String get bibleOldTestament => 'Ancien Testament';

  @override
  String get bibleNewTestament => 'Nouveau Testament';

  @override
  String get bibleBookSearchHint => 'Recherche rapide de livre';

  @override
  String get bibleNoBookFound => 'Aucun livre ne correspond';

  @override
  String bibleChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0';
  }

  @override
  String get bibleChooseChapter => 'Choisir un chapitre';

  @override
  String get bibleChooseVerse => 'Choisir un verset';

  @override
  String bibleStartReading(String reference) {
    return 'Commencer $reference';
  }

  @override
  String get bibleSelectTitle => 'Choisir un passage';

  @override
  String get bibleSelectHint => 'Touchez des versets pour choisir un passage';

  @override
  String bibleInsertReference(String reference) {
    return 'Insérer $reference';
  }

  @override
  String get bibleChangeChapter => 'Changer de chapitre';

  @override
  String get bibleVersionTooltip => 'Version de la Bible';

  @override
  String get bibleChapterUnavailable =>
      'Ce chapitre n\'est pas disponible dans cette version.';

  @override
  String get bibleSoonTitle => 'Bientôt ici';

  @override
  String get bibleHomeSoon =>
      'Verset du jour, passage du dimanche, plans de lecture et quiz arriveront ici.';

  @override
  String get bibleFavoritesSoon =>
      'Vos versets favoris, chapitres marqués et passages surlignés se rangeront ici.';

  @override
  String get bibleMoreSoon =>
      'Plans de lecture, quiz, versions et paramètres arriveront ici.';

  @override
  String get bibleM2Copy => 'Copier';

  @override
  String get bibleM2Copied => 'Versets copiés';

  @override
  String get bibleM2Favorite => 'Favori';

  @override
  String get bibleM2Note => 'Note';

  @override
  String get bibleM2Share => 'Partager';

  @override
  String get bibleM2Highlight => 'Surligner';

  @override
  String get bibleM2ClearHighlight => 'Effacer le surlignage';

  @override
  String get bibleM2Bookmark => 'Marque-page';

  @override
  String get bibleM2FilterAll => 'Tous';

  @override
  String get bibleM2FilterVerses => 'Versets';

  @override
  String get bibleM2FilterChapters => 'Chapitres';

  @override
  String get bibleM2FilterHighlights => 'Surlignés';

  @override
  String get bibleM2EmptyTitle => 'Rien ici pour l\'instant';

  @override
  String get bibleM2Empty =>
      'Touchez un verset dans le lecteur pour le mettre en favori ou le surligner, ou marquez un chapitre.';

  @override
  String get bibleM4AppearanceTitle => 'Thèmes & polices';

  @override
  String get bibleM4AppearanceSample =>
      'Texte d\'exemple — Le Seigneur garde ceux qui le cherchent, au matin comme au soir.';

  @override
  String get bibleM4Theme => 'Thème';

  @override
  String get bibleM4ThemeLight => 'Clair';

  @override
  String get bibleM4ThemeDark => 'Sombre';

  @override
  String get bibleM4ThemeSepia => 'Sépia';

  @override
  String get bibleM4Font => 'Police';

  @override
  String get bibleM4FontSystem => 'Système';

  @override
  String get bibleM4FontSize => 'Taille du texte';

  @override
  String get bibleM4LineHeight => 'Interligne';

  @override
  String get bibleM4AudioPrevious => 'Chapitre précédent';

  @override
  String get bibleM4AudioNext => 'Chapitre suivant';

  @override
  String get bibleM4AudioPlay => 'Lecture';

  @override
  String get bibleM4AudioPause => 'Pause';

  @override
  String get bibleM4AudioClose => 'Arrêter la lecture';

  @override
  String get bibleM4StudioTitle => 'Studio de partage';

  @override
  String get bibleM4StudioBackground => 'Fond';

  @override
  String get bibleM4StudioInk => 'Couleur du texte';

  @override
  String get bibleM4StudioShowReference => 'Afficher la référence';

  @override
  String get bibleM4StudioSave => 'Enregistrer';

  @override
  String get bibleM4StudioShare => 'Partager';

  @override
  String get bibleM4StudioSaved => 'Image enregistrée dans la galerie';

  @override
  String get bibleM4StudioSaveFailed => 'Impossible d\'enregistrer l\'image';

  @override
  String get bibleM4VersionsTitle => 'Versions et hors ligne';

  @override
  String get bibleM4VersionsHint =>
      'Téléchargez une version pour la lire sans réseau, et choisissez la version active.';

  @override
  String bibleM4SizeMb(String size) {
    return '$size Mo';
  }

  @override
  String get bibleM4VersionBuiltIn => 'intégrée';

  @override
  String get bibleM4Download => 'Télécharger';

  @override
  String get bibleM4VersionSoon => 'Bientôt';

  @override
  String get bibleM4Remove => 'Supprimer';

  @override
  String get bibleM4ActiveVersion => 'Version active';

  @override
  String get bibleM4MySpaceTitle => 'Mon espace';

  @override
  String bibleM4Streak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours de lecture de suite',
      one: '1 jour de lecture de suite',
      zero: 'Aucune série en cours',
    );
    return '$_temp0';
  }

  @override
  String get bibleM4Badges => 'Badges';

  @override
  String get bibleM4NoBadges =>
      'Vos badges de plans et de défis paraîtront ici.';

  @override
  String bibleM4ChaptersRead(int count, int total) {
    return '$count chapitres lus sur $total';
  }

  @override
  String bibleM4Favorites(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favoris',
      one: '1 favori',
      zero: 'Aucun favori',
    );
    return '$_temp0';
  }

  @override
  String bibleM4Notes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
      zero: 'Aucune note',
    );
    return '$_temp0';
  }

  @override
  String bibleM4Quizzes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quiz joués',
      one: '1 quiz joué',
      zero: 'Aucun quiz joué',
    );
    return '$_temp0';
  }

  @override
  String get bibleM4SettingsTitle => 'Paramètres';

  @override
  String get bibleM4Voice => 'Voix de lecture';

  @override
  String get bibleM4VoiceSystem => 'Voix du système';

  @override
  String get bibleM4VoicePiper => 'Voix naturelle (« siwis »)';

  @override
  String bibleM4VoicePiperSize(String size) {
    return 'À télécharger ($size Mo), lue sans réseau';
  }

  @override
  String get bibleM4VoicePiperReady => 'Installée — lue sans réseau';

  @override
  String get bibleM4VoicePiperFailed =>
      'Le téléchargement a échoué. Réessayez.';

  @override
  String get bibleM4Reminders => 'Rappels';

  @override
  String get bibleM4VerseOfDayTitle => 'Verset du jour';

  @override
  String get bibleM4PlanReminderTitle => 'Lecture du plan';

  @override
  String get bibleM4PlanReminderBody =>
      'C\'est l\'heure de votre lecture du jour.';

  @override
  String get bibleM4ChangeTime => 'Changer l\'heure';

  @override
  String get bibleM4About => 'À propos';

  @override
  String get bibleM4Licenses =>
      'Voix « siwis » : modèle Piper fr_FR-siwis-medium, entraîné sur le corpus SIWIS (Université d\'Édimbourg), licence CC BY 4.0 ; lue par sherpa-onnx (Apache 2.0) et espeak-ng (GPL 3.0). Polices : Atkinson Hyperlegible (Braille Institute) et Literata (The Literata Project Authors), SIL Open Font License 1.1.';

  @override
  String get bibleM4OfflineShortcut => 'Hors ligne';

  @override
  String get bibleM4ShareAsImage => 'Partager en image';

  @override
  String get bibleM4ListenFromHere => 'Écouter à partir d\'ici';

  @override
  String get bibleSearchTitle => 'Rechercher';

  @override
  String get bibleSearchHint => 'Un mot, ou une référence (jn 3 16)';

  @override
  String bibleSearchGoTo(String reference) {
    return 'Aller à $reference';
  }

  @override
  String bibleSearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '1 résultat',
      zero: 'Aucun résultat',
    );
    return '$_temp0';
  }

  @override
  String get bibleSearchScopeAll => 'Tout';

  @override
  String get bibleSearchScopeOld => 'AT';

  @override
  String get bibleSearchScopeNew => 'NT';

  @override
  String get bibleSearchScopeBook => 'Livre';

  @override
  String get bibleSearchMore => 'Voir plus';

  @override
  String get bibleSearchHistory => 'Recherches récentes';

  @override
  String get bibleSearchClearHistory => 'Effacer';

  @override
  String get bibleSearchIndexing => 'Préparation de la recherche…';

  @override
  String get bibleSearchEmpty =>
      'Cherchez un mot dans la Bible, ou tapez une référence.';

  @override
  String get bibleSearchNoResults => 'Aucun verset ne contient ces mots.';

  @override
  String get bibleSearchCompare => 'Comparer les versions';

  @override
  String get bibleSearchCompareTitle => 'Résultats comparatifs';
}
