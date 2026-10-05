// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Nouvelle Vie';

  @override
  String get splashTagline => 'Nous annonçons avec foi.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navMedia => 'Médias';

  @override
  String get navAnnouncements => 'Annonces';

  @override
  String get navGroups => 'Échanges';

  @override
  String get navProfile => 'Profil';

  @override
  String get navBible => 'Bible';

  @override
  String get pageUnderConstruction => 'Page en construction';

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
  String get registerTermsPrefix =>
      'Après la vérification, il vous sera demandé d\'accepter nos ';

  @override
  String get registerTermsLink =>
      'conditions d\'utilisation et notre politique de confidentialité.';

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
  String get radioTitle => 'New Life Radio';

  @override
  String get radioOffAir => 'Hors antenne';

  @override
  String get radioLive => 'À l\'antenne';

  @override
  String get radioRetrying => 'Nouvelle tentative…';

  @override
  String get radioFailureConnection => 'Vérifiez votre connexion';

  @override
  String get radioFailureAntenna => 'Antenne indisponible';

  @override
  String get radioFailureUnknown => 'Écoute impossible';

  @override
  String get radioGaveUpMessage =>
      'L\'application a cessé de réessayer. Relancez l\'écoute quand vous voulez.';

  @override
  String get radioUnavailableMessage =>
      'New Life Radio ne diffuse pas pour le moment.';

  @override
  String get radioLongPressTip =>
      'Astuce : un appui long sur ce bouton ouvre le live à tout moment.';

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
  String get actionSeeAll => 'Voir tout';

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
  String get requestsEmptyTitle => 'Aucune requête';

  @override
  String get requestsEmpty => 'Vos requêtes et suggestions apparaîtront ici.';

  @override
  String get requestsAdd => 'Nouvelle requête';

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
  String get prayersTabCommunity => 'Communauté';

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
  String get mediaSettingsLead =>
      'Ces réglages ne changent rien à ce que vous entendez sur le réseau de l\'église. Ils protègent votre forfait quand vous êtes dehors.';

  @override
  String get mediaSettingsStreaming => 'Écoute d\'un message';

  @override
  String get mediaSettingsLive => 'Direct';

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
  String get mediaQualityAuto => 'Automatique';

  @override
  String get mediaQualityLow => 'Économie';

  @override
  String get mediaQualityMid => 'Standard';

  @override
  String get mediaQualityHigh => 'Haute';

  @override
  String mediaQualityImpactAuto(int mb) {
    return '≈ $mb Mo par heure en données mobiles, meilleure qualité en wifi.';
  }

  @override
  String mediaQualityImpactLow(int mb) {
    return '≈ $mb Mo par heure · suffisant pour la prédication, la chorale y perd.';
  }

  @override
  String mediaQualityImpactMid(int mb) {
    return '≈ $mb Mo par heure · la louange retrouve son ampleur.';
  }

  @override
  String mediaQualityImpactHigh(int mb) {
    return '≈ $mb Mo par heure · chaque nuance, au prix fort.';
  }

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
      'Votre code de connexion vous sera envoyé par email.';

  @override
  String get authNoticePhoneOnly =>
      'Votre code de connexion vous sera envoyé sur votre téléphone.';

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
  String get branchMotherChurch => 'Église Mère';

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
  String get absenceRetractedTitle => 'Contenu retiré';

  @override
  String get absenceRetractedMessage =>
      'Ce contenu n\'est plus disponible. Il a été retiré par l\'église.';

  @override
  String get absenceNotSyncedTitle => 'Pas encore synchronisé';

  @override
  String get absenceNotSyncedMessage =>
      'Ce contenu n\'est pas encore arrivé sur cet appareil. Il apparaîtra après la prochaine synchronisation.';

  @override
  String get absenceNoMediaTitle => 'Enregistrement à venir';

  @override
  String get absenceNoMediaMessage =>
      'L\'enregistrement n\'est pas encore en ligne. Revenez d\'ici quelques jours.';

  @override
  String get absenceOfflineMediaTitle => 'Écoute impossible hors ligne';

  @override
  String get absenceOfflineMediaMessage =>
      'La médiathèque s\'écoute en ligne. Reconnectez-vous à internet pour lancer la lecture.';

  @override
  String get absenceBack => 'Retour';

  @override
  String get gatheringAppBarTitle => 'Rassemblement';

  @override
  String get gatheringRetractedTitle =>
      'Ce rassemblement n\'est plus disponible';

  @override
  String get gatheringRetractedMessage =>
      'Il a été retiré par l\'église. La lecture est arrêtée.';

  @override
  String get sectionGatherings => 'Rassemblements';

  @override
  String get teachingRetractedTitle => 'Ce message n\'est plus disponible';

  @override
  String get teachingRetractedMessage =>
      'Il a été retiré de la médiathèque. La lecture est arrêtée.';

  @override
  String get playerErrorTitle => 'Lecture interrompue';

  @override
  String get playerErrorMessage =>
      'Le son s\'est arrêté. Vérifiez votre connexion, puis reprenez la lecture.';

  @override
  String get playerErrorRetry => 'Reprendre';

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
}
