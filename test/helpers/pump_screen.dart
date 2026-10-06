import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/legal_notice_store.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/measurement/play_reporter.dart';
import 'package:maison_du_miracle/data/measurement/play_spool.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';
import 'package:maison_du_miracle/data/radio/radio_live_repository.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart'
    show SyncCollectionKey;
import 'package:maison_du_miracle/data/messaging/group_history.dart';
import 'package:maison_du_miracle/data/messaging/group_mute_setter.dart';
import 'package:maison_du_miracle/data/messaging/group_read_advancer.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_signals_api.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/announcement_repository.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/data/repositories/branch_repository.dart';
import 'package:maison_du_miracle/data/repositories/echanges_repository.dart';
import 'package:maison_du_miracle/data/repositories/group_admin_client.dart';
import 'package:maison_du_miracle/data/repositories/group_message_composer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/data/repositories/playback_progress_reporter.dart';
import 'package:maison_du_miracle/data/repositories/menu_repository.dart';
import 'package:maison_du_miracle/data/repositories/my_requests_repository.dart';
import 'package:maison_du_miracle/data/repositories/receipts_repository.dart';
import 'package:maison_du_miracle/l10n/l10n_setup.dart';
import 'package:maison_du_miracle/state/announcement_providers.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/downloads_providers.dart';
import 'package:maison_du_miracle/state/echanges_providers.dart';
import 'package:maison_du_miracle/state/gathering_providers.dart';
import 'package:maison_du_miracle/state/group_management_providers.dart';
import 'package:maison_du_miracle/state/legal_notice_providers.dart';
import 'package:maison_du_miracle/state/measurement_providers.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/state/mediatheque_providers.dart';
import 'package:maison_du_miracle/state/menu_providers.dart';
import 'package:maison_du_miracle/state/radio_live_providers.dart';
import 'package:maison_du_miracle/state/receipts_providers.dart';
import 'package:maison_du_miracle/state/requests_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/state/theme_provider.dart';
import 'package:maison_du_miracle/state/playback_progress_providers.dart';
import 'package:maison_du_miracle/state/push_providers.dart';
import 'package:maison_du_miracle/models/auth_channels.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';
import 'package:maison_du_miracle/state/auth_channels_providers.dart';
import 'package:maison_du_miracle/state/device_settings_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';
import 'package:maison_du_miracle/state/vocabulary_providers.dart';
import 'package:maison_du_miracle/theme/app_theme.dart';
import 'package:maison_du_miracle/widgets/mini_player_host.dart';

import 'chat_media_doubles.dart';
import 'playback_doubles.dart';

/// Monte un écran isolé dans un environnement minimal (ProviderScope + thème).
///
/// Utilise `pump()` (et non `pumpAndSettle`) car certains écrans affichent des
/// animations infinies (ex. le spinner du splash) qui ne se stabilisent jamais.
///
/// [overrides] permet d'injecter des providers de test (ex. un faux
/// repository) pour vérifier le câblage des données. Ils sont appliqués
/// **après** les repli ci-dessous, et peuvent donc les remplacer.
///
/// Les repositories d'auth et de branches sont forcés sur leurs
/// implémentations **en mémoire** : les versions HTTP ouvriraient une socket
/// dès le montage (`GET /auth/me`, `GET /sync/branches`) et `flutter test`
/// répond **400 à tout accès réseau**.
///
/// Celui de la médiathèque l'est pour une raison voisine mais distincte : son
/// implémentation par défaut lit le **magasin Drift**, qui ouvrirait un fichier
/// de base de données sur la machine de test. Un test d'écran n'a pas à laisser
/// de trace sur le disque ; ceux qui veulent le vrai magasin surchargent
/// `appDatabaseProvider` par une base en mémoire (voir `test/data/local/`).
/// [mediatheque] remplace ce double par un autre. C'est un paramètre nommé et
/// non un `Override` de plus : Riverpod 3 **refuse** deux surcharges du même
/// provider dans un même conteneur, un test ne peut donc pas simplement
/// « repasser par-dessus » celui posé ici.
///
/// Celui des **rassemblements** ([gatherings]) est posé de la même façon et pour
/// la même raison : la seconde famille de la médiathèque lit le même magasin
/// Drift, et l'accueil la rend désormais.
///
/// Celui des **menus** ([menu]) l'est pour la même raison, et son défaut dit
/// quelque chose : `InMemoryMenuRepository` rend un menu **vide**, c'est-à-dire
/// l'état d'une application dont le premier cycle n'a rien ramené. La médiathèque
/// montre alors son onglet implicite (le catalogue entier) et l'accueil reste
/// piloté par les rubriques — les deux replis que tout test d'écran doit exercer
/// sans avoir à parler de menus. Ceux qui veulent un vrai menu passent
/// `StoreMenuRepository(db.menuDao)`.
///
/// Celui des **annonces** ([announcements]) aussi, et il est le plus facile à
/// oublier : `HomeShell` monte les quatre onglets dans un `IndexedStack`, donc
/// la visionneuse de statuts vit dès qu'un test monte la coquille — et
/// ouvrirait le magasin Drift sans que le test parle jamais d'annonces.
///
/// Le magasin lui-même est posé **en mémoire**, et non simplement contourné :
/// tous les chemins ne passent pas par un repository. La reprise de lecture
/// (#43), branchée sur le lecteur par #40, lit et écrit son `PlaybackDao` en
/// direct — un écran de lecture ouvrirait donc un fichier de base sur la
/// machine de test, et sur un harnais sans canal de plugin il n'en ouvrirait
/// même pas : il lèverait. Une base en mémoire ne coûte rien tant que personne
/// ne l'interroge (Drift ouvre à la première requête).
///
/// Le **rapporteur de progression** est posé muet pour la raison qui vaut déjà
/// pour l'auth : son implémentation par défaut est HTTP dès que
/// `AppEnv.useBackend` est vrai — et il l'est hors surcharge.
///
/// Le **rapporteur d'écoute** et sa **file d'attente** le sont aussi, et pour la
/// même raison (#115) : le suivi d'écoute vit dans le contrôleur global, donc
/// tout test qui lance un enseignement — depuis la fiche **ou** depuis une carte
/// de l'accueil — ouvre une mesure, et trente secondes poussées au lecteur
/// enverraient un `POST /teachings/:id/plays`. [progress], [plays] et
/// [playSpool] sont des paramètres nommés pour qu'un test puisse **lire** ce que
/// ses doubles ont reçu — et non des `Override` de plus, que Riverpod 3
/// refuserait.
///
/// La **mention légale du premier lancement** est posée « déjà vue », et c'est le
/// seul repli de cette liste qui cache quelque chose plutôt que d'éviter une
/// socket. Motif : la coquille la monte, comme elle monte les quatre onglets, et
/// un test qui ne parle pas du bandeau n'a pas à savoir qu'il existe — il ne doit
/// surtout pas se mettre à échouer parce qu'un bandeau est venu se poser entre
/// deux de ses `tap`. Les tests **du** bandeau passent leur propre double
/// ([legalNotice]), et seul le vrai magasin porte la réponse de production.
///
/// **L'antenne de New Life Radio** ([radio]) est posée sur un double fixe (#104),
/// pour la raison de l'auth : l'implémentation réelle est HTTP dès que
/// `AppEnv.useBackend` est vrai — et il l'est hors surcharge —, donc le bouton
/// d'antenne de l'accueil ouvrirait une socket au premier frame, et tout test qui
/// monte l'accueil ou la coquille monte ce bouton.
///
/// Le défaut est [RadioAntenna.unknown] — ce que sait une application dont la
/// route n'a pas encore répondu —, et c'est ce qu'un test qui ne parle pas de radio
/// doit voir : un bouton **au repos**, jamais « Hors antenne ». ⚠️ Une seule
/// surcharge est posée, celle du **repository** : le provider d'état la lit
/// normalement, pour que le chemin éprouvé soit celui de production. Les tests qui
/// veulent une antenne précise ou un échec passent par ce paramètre nommé —
/// Riverpod 3 refuse deux surcharges du même provider.
///
/// **Le pré-vol de la poignée de main** ([handshake]) est posé de la même façon et
/// pour la même raison (#108) : son implémentation réelle ouvre une socket vers le
/// serveur de flux **dès le premier appui** sur le bouton d'antenne, et
/// `flutter test` répond 400 à tout accès réseau. Le défaut est
/// `DirectRadioHandshake` — l'URL passe telle quelle, sans en-tête —, c'est-à-dire
/// ce que voit un test qui ne parle pas de cookie. Les tests qui éprouvent la
/// poignée de main passent par ce paramètre nommé, et jamais par un `Override` de
/// plus : Riverpod 3 refuse deux surcharges du même provider.
///
/// Le **contrôleur d'écoute**, lui, n'est pas doublé : il observe le lecteur, et
/// `contentPlayerProvider` est déjà inerte par défaut.
///
/// Le **canal temps réel `users/{id}`** ([channel]) est posé **muet** (#140),
/// et l'envoi de la lecture ([readSender]) et l'historique ([history]) inertes,
/// pour la raison de l'auth et de l'envoyeur de messages : les implémentations
/// réelles parlent au réseau dès que `AppEnv.useBackend` est vrai, et
/// `flutter test` répond 400 à tout accès réseau.
/// Monte un **routeur** plutôt qu'un écran isolé, dans le même environnement.
///
/// Nécessaire dès qu'un test porte sur la navigation : `context.pop()` et
/// `context.canPop()` sont les extensions de **go_router**, qui consultent sa
/// pile à lui. Un test bâti sur un `Navigator.push` nu passerait à côté de ce
/// que fait réellement l'application.
Future<void> pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  List<Override> overrides = const [],
  AppDatabase? database,
  AuthRepository? auth,
  ThemePreferences? theme,
  // Les deux repositories de contenu sont des **paramètres nommés ici aussi**,
  // et pas des `Override` que l'appelant ajouterait : `_commonOverrides` en pose
  // déjà un pour chacun, et Riverpod 3 refuse deux surcharges du même provider
  // dans un même conteneur. Un test de navigation qui veut le vrai magasin passe
  // donc par là.
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  MenuRepository? menu,
  LegalNoticeStore? legalNotice,
  VocabularyOverrides? vocabulary,
  AuthChannelOffer? authChannels,
  String? updateThreshold,
  EchangesRepository? echanges,
  GroupAdminClient? groupAdmin,
  MyRequestsRepository? myRequests,
  RequestSubmitter? requestSubmitter,
  MessagingChannel? channel,
  GroupReadSender? readSender,
  GroupHistory? history,
  ReceiptsRepository? receipts,
  MessagingSignalsApi? signals,
  RadioRepository? radio,
  RadioHandshakeResolver? handshake,
  RadioChannel? radioChannel,
  RadioLiveRepository? radioLive,
  PlaybackProgressReporter? progress,
  PlayReporter? plays,
  PlaySpool? playSpool,
  AnnouncementRepository? announcements,
}) async {
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._commonOverrides(
          db,
          auth: auth,
          theme: theme,
          mediatheque: mediatheque,
          gatherings: gatherings,
          menu: menu,
          legalNotice: legalNotice,
          vocabulary: vocabulary,
          authChannels: authChannels,
          updateThreshold: updateThreshold,
          echanges: echanges,
          groupAdmin: groupAdmin,
          myRequests: myRequests,
          requestSubmitter: requestSubmitter,
          channel: channel,
          readSender: readSender,
          history: history,
          receipts: receipts,
          signals: signals,
          radio: radio,
          handshake: handshake,
          radioChannel: radioChannel,
          radioLive: radioLive,
          progress: progress,
          plays: plays,
          playSpool: playSpool,
          announcements: announcements,
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        routerConfig: router,
        // Comme `app.dart` : la frontière vit **sous** `MaterialApp`, parce que
        // `context.words` y lit la locale que le framework vient de résoudre.
        //
        // **Le mini-lecteur aussi** (#117) : `app.dart` le pose au-dessus du
        // `Navigator`, et un test de navigation doit voir ce que voit le fidèle.
        builder: (context, child) => VocabularyBoundary(
          child: MiniPlayerHost(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Les surcharges que tout montage partage — voir l'en-tête pour le pourquoi
/// de chacune.
List<Override> _commonOverrides(
  AppDatabase db, {
  AuthRepository? auth,
  ThemePreferences? theme,
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  AnnouncementRepository? announcements,
  MenuRepository? menu,
  LegalNoticeStore? legalNotice,
  VocabularyOverrides? vocabulary,
  AuthChannelOffer? authChannels,
  String? updateThreshold,
  EchangesRepository? echanges,
  GroupAdminClient? groupAdmin,
  MyRequestsRepository? myRequests,
  RequestSubmitter? requestSubmitter,
  MessagingChannel? channel,
  GroupReadSender? readSender,
  GroupHistory? history,
  ReceiptsRepository? receipts,
  MessagingSignalsApi? signals,
  RadioRepository? radio,
  RadioHandshakeResolver? handshake,
  RadioChannel? radioChannel,
  RadioLiveRepository? radioLive,
  PlaybackProgressReporter? progress,
  PlayReporter? plays,
  PlaySpool? playSpool,
  List<DownloadNotificationRow> notifications = const [],
  Map<String, GroupMuteRowView> mutes = const {},
  GroupMuteSender? muteSender,
  bool notificationPreview = true,
}) =>
    [
      appDatabaseProvider.overrideWithValue(db),
      // **L'antenne de New Life Radio** (#104) — voir l'en-tête pour le pourquoi.
      radioRepositoryProvider.overrideWithValue(
        radio ?? const FixedRadioRepository(RadioAntenna.unknown),
      ),
      // **Le pré-vol de la poignée de main de MediaMTX** (#108) — voir l'en-tête.
      radioHandshakeProvider.overrideWithValue(
        handshake ?? const DirectRadioHandshake(),
      ),
      // **La page live** (#135) — le canal temps réel posé **muet** et les
      // routes du fil posées **inertes**, pour la raison de l'antenne :
      // l'implémentation réelle est SSE et HTTP dès que `AppEnv.useBackend` est
      // vrai, donc ouvrir `/radio` ouvrirait une socket que `flutter test`
      // refuse, et laisserait derrière elle la minuterie de réouverture. Le
      // défaut est une radio **hors direct**, sans compteur — ce qu'un test qui
      // ne parle pas du live doit voir. Paramètres nommés et non `Override` de
      // plus : Riverpod 3 refuse deux surcharges du même provider.
      radioChannelProvider.overrideWithValue(
        radioChannel ?? const SilentRadioChannel(),
      ),
      radioLiveRepositoryProvider.overrideWithValue(
        radioLive ?? const InertRadioLiveRepository(),
      ),
      // **Le canal temps réel `users/{id}`, posé muet** (#140), pour la raison
      // de l'auth et de l'envoyeur de messages : l'implémentation réelle est SSE
      // dès que `AppEnv.useBackend` est vrai — et il l'est hors surcharge —, donc
      // l'ouvrir ouvrirait une socket que `flutter test` refuse, et laisserait
      // derrière elle la minuterie de réouverture. Le défaut est **aucun
      // événement** : le régime « sans temps réel » que l'application doit tenir
      // sans rien changer à l'écran. [channel] est un paramètre nommé et non un
      // `Override` de plus — Riverpod 3 refuse deux surcharges du même provider.
      messagingChannelProvider
          .overrideWithValue(channel ?? const SilentMessagingChannel()),
      // **La lecture et l'historique, sans réseau** (#140) — même raison :
      // ouvrir un fil qui porte des non-lus ferait avancer la lecture, donc
      // poster. La lecture locale est posée dans le vrai magasin (on peut la
      // relire), l'envoi est inerte ([readSender] le remplace) ; l'historique ne
      // va pas au-delà du magasin ([history] le remplace).
      groupReadAdvancerProvider.overrideWith(
        (ref) => GroupReadAdvancer(
          dao: db.groupDao,
          sender: readSender ?? const InertGroupReadSender(),
          storeRead: (row) =>
              MessagingStoreWriter(db).store(SyncCollectionKey.groupReads, row),
        ),
      ),
      groupHistoryProvider.overrideWithValue(history ?? const NoGroupHistory()),
      // **Les accusés, la frappe, la présence, la confidentialité** (#142) :
      // les six routes posées **inertes** (l'implémentation réelle est HTTP dès
      // que `AppEnv.useBackend` est vrai) et les coches posées **par un flux
      // nu** — lues dans le magasin, elles ouvriraient un flux Drift, qui fige
      // le montage sous l'horloge factice. Paramètres nommés : Riverpod 3
      // refuse deux surcharges du même provider.
      messagingSignalsApiProvider
          .overrideWithValue(signals ?? const InertMessagingSignalsApi()),
      receiptsRepositoryProvider.overrideWith(
        (ref, actor) => receipts ?? const EmptyReceiptsRepository(),
      ),
      // **La rubrique Échanges, posée sur un double vide** (#96), pour les deux
      // raisons qui valent déjà pour la médiathèque et les annonces : son
      // implémentation réelle lit le **magasin Drift** — donc ouvre des flux qu'une
      // horloge factice fige —, et `HomeShell` monte les quatre onglets dans un
      // `IndexedStack`, si bien que le hub vit dès qu'un test monte la coquille.
      //
      // Le défaut est **vide**, et c'est ce qu'un test qui ne parle pas d'Échanges
      // doit voir : un magasin qui n'a pas encore reçu mes conversations.
      // [echanges] est un paramètre nommé et non un `Override` de plus — Riverpod 3
      // refuse deux surcharges du même provider dans un même conteneur.
      // Une famille se surcharge **en entier** : tous les acteurs reçoivent le
      // même double, ce qui est exactement ce qu'un test veut — il n'a pas à savoir
      // quel identifiant la session en mémoire a résolu.
      echangesRepositoryProvider.overrideWith(
        (ref, actor) => echanges ?? InMemoryEchangesRepository(),
      ),
      // **Mes requêtes** (#148), posées sur un double vide pour la raison de la
      // rubrique Échanges : l'implémentation réelle lit le magasin Drift, dont
      // un flux attendu sous l'horloge factice fige le montage — et l'onglet vit
      // dans la page Échanges, que la coquille monte. Une famille se surcharge
      // en entier : tous les acteurs reçoivent le même double.
      myRequestsRepositoryProvider.overrideWith(
        (ref, actor) => myRequests ?? InMemoryMyRequestsRepository(),
      ),
      // **L'envoi d'une requête**, posé indisponible par défaut : le réel est
      // HTTP dès que `AppEnv.useBackend` est vrai, et un appui sur « Envoyer »
      // ouvrirait une socket que `flutter test` refuse.
      // **Les gestes de groupe** (#145), posés **inertes**, pour la raison de
      // l'envoyeur de messages : le réel est HTTP dès que `AppEnv.useBackend`
      // est vrai, et `GET /groups/capabilities` partirait au montage de
      // « Nouvelle discussion ». Le cycle qui suit un geste réussi est muet.
      // [groupAdmin] est un paramètre nommé — Riverpod 3 refuse deux
      // surcharges du même provider.
      groupAdminClientProvider
          .overrideWithValue(groupAdmin ?? const InertGroupAdminClient()),
      groupActionsProvider.overrideWith(
        (ref) => GroupActions(
          client: groupAdmin ?? const InertGroupAdminClient(),
          resynchronize: () async {},
        ),
      ),
      requestSubmitterProvider.overrideWithValue(
        requestSubmitter ?? const UnavailableRequestSubmitter(),
      ),
      // **L'envoyeur est inerte**, pour la raison de l'auth et du rapporteur de
      // progression : l'implémentation réelle est HTTP dès que `AppEnv.useBackend`
      // est vrai — et il l'est hors surcharge —, donc un appui sur « envoyer »
      // ouvrirait une socket que `flutter test` refuse, en laissant la minuterie de
      // Dio derrière lui.
      groupMessageComposerProvider.overrideWith(
        (ref) => GroupMessageComposer(
          dao: db.groupDao,
          sender: const InertGroupMessageSender(),
          resynchronize: () async {},
        ),
      ),
      // **Les canaux de connexion ouverts** (#83), posés **par un flux nu**, pour
      // la raison déjà donnée pour le vocabulaire : lus depuis le magasin, ils
      // ouvrent un flux Drift, et un flux Drift attendu sous l'horloge factice du
      // harnais fige le montage.
      //
      // Le défaut est l'**e-mail seul** — ce que propose une application qui n'a
      // pas encore synchronisé, et ce qu'un test qui ne parle pas de canaux doit
      // voir. [authChannels] est un paramètre nommé et non un `Override` de
      // plus : Riverpod 3 refuse deux surcharges du même provider.
      authChannelsProvider.overrideWith(
        (ref) => Stream.value(authChannels ?? AuthChannelOffer.emailOnly),
      ),
      // **Les mots réglés au portail** (#81), posés **par un flux nu** et pour la
      // raison la plus coûteuse de ce dépôt : lus depuis le magasin, ils ouvrent
      // un flux Drift, et un flux Drift attendu sous l'horloge factice du harnais
      // fige le montage — processus à 0 % de CPU jusqu'à expiration. Et tout
      // écran les lit désormais, puisque `context.words` est posé sous
      // `MaterialApp`.
      //
      // Le défaut est **aucune surcharge**, c'est-à-dire le `.arb` compilé : ce
      // que montre une application qui n'a pas encore synchronisé, et ce qu'un
      // test qui ne parle pas de vocabulaire doit voir. [vocabulary] est un
      // paramètre nommé et non un `Override` de plus — Riverpod 3 refuse deux
      // surcharges du même provider dans un même conteneur.
      vocabularyProvider.overrideWith(
        (ref) => Stream.value(vocabulary ?? VocabularyOverrides.empty),
      ),
      // **Le seuil du bandeau de mise à jour** (#91), posé **par un flux nu**,
      // pour la raison déjà donnée pour le vocabulaire et les canaux : lu depuis
      // le magasin, il ouvre un flux Drift, et un flux Drift attendu sous
      // l'horloge factice du harnais fige le montage. Et tout test qui monte la
      // coquille le lit, puisque le bandeau y vit.
      //
      // Le défaut est **aucun seuil**, donc **aucun bandeau** : ce que voit une
      // application qui n'a pas encore synchronisé, et ce qu'un test qui ne parle
      // pas de mise à jour doit voir. [updateThreshold] est un paramètre nommé et
      // non un `Override` de plus — Riverpod 3 refuse deux surcharges du même
      // provider dans un même conteneur.
      updateBannerMinVersionProvider.overrideWith(
        (ref) => Stream.value(updateThreshold),
      ),
      playbackProgressReporterProvider
          .overrideWithValue(progress ?? FakePlaybackProgressReporter()),
      // **La mesure d'écoute, muette** (#115) — voir l'en-tête.
      playReporterProvider.overrideWithValue(plays ?? FakePlayReporter()),
      playSpoolProvider.overrideWithValue(playSpool ?? FakePlaySpool()),
      networkTransportProvider.overrideWithValue(FixedNetworkTransport()),
      // Les réglages d'apparence sont posés **par un flux nu**, et pour la
      // raison la plus coûteuse de ce dépôt : lus depuis le magasin, ils
      // ouvrent un flux Drift, et un flux Drift attendu sous l'horloge factice
      // du harnais fige le montage — processus à 0 % de CPU jusqu'à expiration.
      // L'onglet Profil les lit, donc tout test qui monte la coquille les lit.
      themePreferencesProvider.overrideWith(
          (ref) => Stream.value(theme ?? const ThemePreferences())),
      // Le bouton de téléchargement de `ContentPlayerView` (#192) observe ce
      // flux Drift, et un écran de lecture le monte donc dès qu'il offre le
      // téléchargement (l'enseignement). Posé **par un flux nu**, exactement
      // comme les réglages d'apparence et pour la même raison : un flux Drift
      // attendu sous l'horloge factice du harnais fige le montage — 0 % de CPU
      // jusqu'à expiration. Les tests qui veulent le vrai magasin surchargent
      // eux-mêmes ce provider (voir `test/widgets/content_download_button_test`).
      downloadForContentProvider
          .overrideWith((ref, contentId) => Stream.value(null)),
      // Le bandeau de purge de la page Téléchargements (#194) observe ce flux
      // Drift. Posé **par un flux nu** pour la même raison que les autres : un
      // flux Drift attendu sous l'horloge factice du harnais fige le montage.
      // Les tests qui veulent le vrai magasin surchargent eux-mêmes.
      downloadNotificationsProvider
          .overrideWith((ref) => Stream.value(notifications)),
      authRepositoryProvider
          .overrideWithValue(auth ?? InMemoryAuthRepository()),
      branchRepositoryProvider
          .overrideWithValue(const InMemoryBranchRepository()),
      mediathequeRepositoryProvider
          .overrideWithValue(mediatheque ?? InMemoryMediathequeRepository()),
      gatheringRepositoryProvider
          .overrideWithValue(gatherings ?? InMemoryGatheringRepository()),
      menuRepositoryProvider
          .overrideWithValue(menu ?? const InMemoryMenuRepository()),
      announcementRepositoryProvider
          .overrideWithValue(announcements ?? InMemoryAnnouncementRepository()),
      legalNoticeStoreProvider.overrideWithValue(
        legalNotice ?? InMemoryLegalNoticeStore(seen: true),
      ),
      // **La sourdine et l'aperçu des notifications** (M5), posés **par des
      // flux nus** pour la raison du vocabulaire : lus depuis le magasin, ils
      // ouvrent des flux Drift qu'une horloge factice fige — et le menu du fil
      // comme l'onglet Profil les lisent. Le défaut est **aucune sourdine** et
      // **aperçu affiché**. Le réglage d'une sourdine est posé inerte (le réel
      // est HTTP) ; [muteSender] le remplace. Paramètres nommés et non
      // `Override` de plus — Riverpod 3 refuse deux surcharges du même provider.
      groupMuteProvider
          .overrideWith((ref, groupId) => Stream.value(mutes[groupId])),
      notificationPreviewProvider
          .overrideWith((ref) => Stream.value(notificationPreview)),
      groupMuteSetterProvider.overrideWith(
        (ref) => GroupMuteSetter(
          sender: muteSender ?? const InertGroupMuteSender(),
          storeMute: (row) =>
              MessagingStoreWriter(db).store(SyncCollectionKey.groupMutes, row),
        ),
      ),
      // **Les médias du fil** (M4, #143) — enregistreur, lecteur, compresseur,
      // chemin présigné : tous des greffons ou du réseau, posés inertes.
      ...chatMediaTestOverrides(db),
    ];

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  MediathequeRepository? mediatheque,
  GatheringRepository? gatherings,
  AnnouncementRepository? announcements,
  MenuRepository? menu,
  AppDatabase? database,
  AuthRepository? auth,
  ThemePreferences? theme,
  LegalNoticeStore? legalNotice,
  VocabularyOverrides? vocabulary,
  AuthChannelOffer? authChannels,
  String? updateThreshold,
  EchangesRepository? echanges,
  GroupAdminClient? groupAdmin,
  MyRequestsRepository? myRequests,
  RequestSubmitter? requestSubmitter,
  MessagingChannel? channel,
  GroupReadSender? readSender,
  GroupHistory? history,
  ReceiptsRepository? receipts,
  MessagingSignalsApi? signals,
  RadioRepository? radio,
  RadioHandshakeResolver? handshake,
  RadioChannel? radioChannel,
  RadioLiveRepository? radioLive,
  PlaybackProgressReporter? progress,
  PlayReporter? plays,
  PlaySpool? playSpool,
  List<DownloadNotificationRow> notifications = const [],
  Map<String, GroupMuteRowView> mutes = const {},
  GroupMuteSender? muteSender,
  bool notificationPreview = true,
}) async {
  // Paramètres nommés et non `Override` de plus, pour la raison déjà donnée
  // ci-dessus : Riverpod 3 refuse deux surcharges du même provider. [database]
  // existe pour les tests qui doivent **relire** le magasin après coup — la
  // suppression de compte le vide, et on ne peut le vérifier que sur
  // l'instance que l'écran a réellement utilisée.
  final db = database ?? AppDatabase(NativeDatabase.memory());
  if (database == null) addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ..._commonOverrides(
          db,
          auth: auth,
          theme: theme,
          mediatheque: mediatheque,
          gatherings: gatherings,
          announcements: announcements,
          menu: menu,
          legalNotice: legalNotice,
          vocabulary: vocabulary,
          authChannels: authChannels,
          updateThreshold: updateThreshold,
          echanges: echanges,
          groupAdmin: groupAdmin,
          myRequests: myRequests,
          requestSubmitter: requestSubmitter,
          channel: channel,
          readSender: readSender,
          history: history,
          receipts: receipts,
          signals: signals,
          radio: radio,
          handshake: handshake,
          radioChannel: radioChannel,
          radioLive: radioLive,
          progress: progress,
          plays: plays,
          playSpool: playSpool,
          notifications: notifications,
          mutes: mutes,
          muteSender: muteSender,
          notificationPreview: notificationPreview,
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: VocabularyBoundary(child: screen),
      ),
    ),
  );
  await tester.pump();
  // Laisse expirer les minuteries de résolution de session (mock ~300 ms, via
  // `authProvider`) pour éviter les « pending timer » au teardown. On avance
  // l'horloge plutôt que `pumpAndSettle` (certains écrans animent à l'infini).
  await tester.pump(const Duration(seconds: 1));
}
