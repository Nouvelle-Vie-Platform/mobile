import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/network/api_client.dart';
import 'data/notes_media/note_media_providers.dart';
import 'features/bible/marks/bible_marks_outbox.dart';
import 'features/bible/personalize/bible_reminders.dart';
import 'features/bible/plans/plans_providers.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/auth_providers.dart';
import 'state/downloads_providers.dart';
import 'state/echanges_providers.dart';
import 'state/notes_providers.dart';
import 'state/locale_providers.dart';
import 'state/push_providers.dart';
import 'state/session_gate.dart';
import 'state/startup_providers.dart';
import 'state/sync_providers.dart';
import 'state/theme_provider.dart';
import 'state/vocabulary_providers.dart';
import 'theme/app_responsive.dart';
import 'theme/app_theme.dart';
import 'widgets/mini_player_host.dart';

/// Widget racine de l'application « Maison du Miracle ».
///
/// Consomme le [themeModeProvider] et le [routerProvider] via Riverpod, et
/// câble la réaction au **401** global (voir [_MaisonDuMiracleAppState]).
class MaisonDuMiracleApp extends ConsumerStatefulWidget {
  const MaisonDuMiracleApp({super.key});

  @override
  ConsumerState<MaisonDuMiracleApp> createState() => _MaisonDuMiracleAppState();
}

class _MaisonDuMiracleAppState extends ConsumerState<MaisonDuMiracleApp> {
  /// L'abonnement qui tient le porte-intention vivant — voir [initState].
  ProviderSubscription<SessionIntent?>? _intents;
  ProviderSubscription<Object?>? _bibleMarks;

  /// L'abonnement aux réveils reçus **application ouverte** — voir [_handleWake].
  StreamSubscription<Map<String, Object?>>? _wakes;

  /// L'abonnement qui **construit et tient** le lien temps réel `users/{id}`
  /// (#140) — voir `messagingLinkProvider`. Personne d'autre ne l'écoute : sans
  /// lui, le canal ne s'ouvrirait jamais.
  ProviderSubscription<Object?>? _messaging;
  ProviderSubscription<Object?>? _notifications;

  @override
  void initState() {
    super.initState();
    // Point de jonction du 401 : `ApiClient` est un singleton de la couche
    // réseau, sans accès à Riverpod ni à GoRouter — et il ne doit pas en
    // acquérir. C'est ici, où les deux existent, qu'on branche la réaction.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;

    // **La langue annoncée au serveur** (`Accept-Language`, #131) : celle que
    // `_ContentLocaleSync` recopie depuis la locale que `MaterialApp` a
    // réellement résolue. Un lecteur, relu à chaque requête — un changement de
    // langue est suivi dès la suivante —, et branché sur cette copie plutôt
    // que sur une résolution de plus : `PlatformDispatcher` relu ici
    // divergerait de l'écran. Avant la première image, le provider vaut le
    // français, qui est aussi ce que le serveur suppose sans en-tête.
    ApiClient.instance.interfaceLanguage =
        () => ref.read(contentLocaleProvider);

    // **L'intention en attente doit rester vivante**, et c'est la seule raison
    // de cette ligne. `requireSession()` met un geste de côté et le rejoue à
    // l'ouverture de la session ; cette réaction est un `ref.listen` **interne**
    // au provider, et Riverpod 3 met en pause les abonnements d'un provider que
    // personne n'écoute. Sans cet abonnement-ci, le geste serait mis de côté et
    // jamais repris — sans erreur, sans trace : la personne se connecte, revient,
    // et son geste a disparu. Même motif que le routeur, que `build` observe.
    _intents = ref.listenManual(sessionGateProvider, (_, __) {});
    // La file du module Bible observe la session (fusion à la connexion).
    _bibleMarks = ref.listenManual(bibleMarksOutboxProvider, (_, __) {});

    // **Le déclencheur « ouverture »** (ADR-0017). Sans lui, le magasin ne se
    // remplit jamais et la médiathèque reste muette : les écrans lisent le
    // magasin, et rien n'y écrit tant que personne n'a lancé un cycle. Une
    // chaîne rompue ici ne lève rien — un magasin vide ne se plaint pas —,
    // d'où `test/state/cold_start_test.dart`, qui la parcourt en entier.
    //
    // `start()` fait **deux** choses, et la seconde est aussi importante que la
    // première : elle abonne le planificateur au cycle de vie, et c'est de cet
    // abonnement que vient le déclencheur « retour au premier plan ». Le
    // troisième — tirer-pour-rafraîchir — est offert par
    // `pullToRefreshProvider`, que la médiathèque passe à son
    // `RefreshIndicator`. **Jamais de polling.**
    if (AppEnv.useBackend) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // **Le jeton avant le cycle, mais jamais au prix du premier écran.**
        //
        // L'ordre du démarrage est : porteur câblé et session d'appareil lancée
        // dans `main()` (sans l'attendre) → premier frame → *ici*. L'écran est
        // donc déjà peint quand cette attente commence, et elle ne retient rien
        // de visible. Elle existe parce qu'un cycle lancé sans aucun porteur
        // échoue pour rien : au premier lancement d'un invité, c'est le seul
        // cycle qui remplit le magasin, et le rater laisse une application
        // **muette** — pas une erreur.
        //
        // Et elle est **bornée** ([kDeviceSessionStartupGrace]) : en avion
        // l'ouverture de session ne rend la main qu'au bout du `connectTimeout`,
        // et le déclencheur « ouverture » n'a pas à dépendre du réseau. Passé le
        // délai on synchronise quand même — l'échec est gratuit, et « retour au
        // premier plan » rattrapera de lui-même.
        await ref.read(deviceBootstrapProvider).awaitToken();
        if (!mounted) return;
        final scheduler = ref.read(syncSchedulerProvider);
        // **Le cycle de vie des téléchargements** (#194) suit chaque cycle
        // réussi — donc les trois déclencheurs d'ADR-0017 d'un seul câblage :
        //
        // - `DownloadLifecycle.reconcile()` : révision → « mise à jour
        //   disponible » (`outdated`), retrait → purge + notification. Il
        //   s'appuie sur l'état du magasin **après** la sync (ADR-0026).
        // - `DownloadManager.reconcile()` : reprend par `Range` les
        //   téléchargements inachevés qu'une application tuée a laissés (#190,
        //   laissé non câblé par le socle). Après le cycle de vie, pour ne pas
        //   ré-enqueuer une ligne qu'un retrait vient de purger.
        //
        // Les providers sont lus **paresseusement** ici, à chaque cycle réussi :
        // le moteur de transfert (canaux natifs) n'est instancié qu'une fois la
        // première synchronisation passée. Un échec est avalé par le
        // planificateur — ce n'est pas une panne de synchronisation.
        //
        // **Le renvoi de la messagerie** (#140) suit le même câblage : un cycle
        // réussi dit que le réseau répond, c'est le moment de renvoyer les
        // messages en échec et les lectures non confirmées — au retour du
        // réseau (la reconnexion du canal lance un cycle), au retour au premier
        // plan, à l'ouverture. Chaque geste porte sa clé : jamais de doublon.
        scheduler.onCycleSucceeded = (_) async {
          await ref.read(downloadLifecycleProvider).reconcile();
          await ref.read(downloadManagerProvider).reconcile();
          await ref.read(messagingOutboxProvider)();
          // **Les pièces jointes des notes** (#192) d'abord : une montée qui
          // aboutit pose sa clé dans le brouillon, que l'envoi suivant porte.
          await ref.read(noteMediaComposerProvider).resendPending();
          // **Les brouillons de notes** (#190) : même raison, même moment.
          await ref.read(notesOutboxProvider)();
          // **Les marques du module Bible** (M2, #200) : même raison.
          await ref.read(bibleMarksOutboxProvider).run();
          // **Les rappels de la Bible** (#202) : le verset du jour a pu changer.
          await ref.read(bibleRemindersRefreshProvider)();
          // **Les plans de lecture** (#203) : jours cochés, plans suivis.
          await ref.read(biblePlansOutboxProvider)();
        };
        // Le rapport ne remonte à aucun écran : une synchronisation qui échoue
        // laisse simplement le magasin en l'état, et l'écran affiche ce qu'il a.
        unawaited(scheduler.start());

        // **Le canal temps réel de la messagerie** (#140), ouvert après le
        // premier cycle demandé et sous la même attente de porteur : un
        // abonnement sans jeton serait refusé. Le provider suit la session
        // (ouvert à la connexion, fermé à la déconnexion) et son lien suit le
        // cycle de vie (fermé en arrière-plan, rouvert au retour).
        _messaging = ref.listenManual(messagingLinkProvider, (_, __) {});

        // **Les notifications d'une conversation lue s'effacent** (M5), ici ou
        // sur un autre appareil (`read.advanced`). Inerte sans transport de
        // réveil : il n'y a alors rien à effacer.
        _notifications =
            ref.listenManual(notificationReconcilerProvider, (_, __) {});

        // **Le réveil push** (#97), posé au même endroit et pour la même raison que
        // le premier cycle : il a besoin d'un porteur, et `awaitToken()` vient de
        // l'attendre. `POST /devices/tokens` accepte les deux porteurs — un invité
        // s'enregistre donc aussi, et c'est le point de la tranche 2b serveur : un
        // invité qu'on ne peut pas prévenir d'un direct est un invité qui ne revient
        // pas.
        //
        // Rien n'est attendu : l'enregistrement est muet, et le premier écran n'a
        // pas à dépendre d'un aller-retour de plus. Sans transport (le défaut), tout
        // ceci est inerte et ne coûte pas un canal natif.
        unawaited(ref.read(pushEnrolmentProvider).start());
        _wakes = ref
            .read(pushTransportProvider)
            .wakes
            .listen(_handleWake, onError: _ignoreWakeError);
        unawaited(ref.read(wakeTapsProvider).listen(_openConversation));
      });
    }
  }

  /// **Un réveil reçu application ouverte.**
  ///
  /// Il passe par le handler, qui est le **même** que celui du réveil de
  /// l'application fermée : la règle « on synchronise, puis on lit le magasin » n'est
  /// écrite qu'une fois. Ce qui diffère est injecté — ici un cycle du planificateur
  /// et un notifieur inerte (voir `push_providers.dart`).
  void _handleWake(Map<String, Object?> data) {
    if (!mounted) return;
    unawaited(ref.read(pushWakeHandlerProvider).handle(data));
  }

  /// Un flux de réveils en erreur ne doit pas remonter en « unhandled async
  /// error » : personne n'attend ce `Future`, et un push raté n'est pas une panne
  /// d'application.
  void _ignoreWakeError(Object error) {
    debugPrint('[push] réveil ignoré : $error');
  }

  /// **Le tap sur une notification de réveil ouvre la conversation.**
  ///
  /// `goNamed` et non `pushNamed` : la notification peut avoir **lancé**
  /// l'application, et il n'y a alors aucune pile à empiler. La `GoRouter` est lue
  /// dans le conteneur et non sur un `BuildContext` capturé — la contrainte de tout
  /// geste que `requireSession()` peut rejouer après un détour par la connexion.
  ///
  /// L'identifiant vient du **magasin** (`ConversationDigest.groupId`), donc le fil
  /// ouvert contient bien le message annoncé.
  ///
  /// ⚠️ **`requireSession()`, et non une navigation nue.** `/group-chat/:id` est dans
  /// `memberOnlyRoutes` : naviguer tout droit ferait reconduire la personne à
  /// l'accueil par la garde, et le fil disparaîtrait sous ses doigts sans qu'elle
  /// apprenne pourquoi — le cul-de-sac exact que le mode invité existe pour
  /// supprimer (`test/screens/guest_affordances_test.dart` le verrouille sur la
  /// source). Le cas n'est pas théorique : la notification **reste dans la barre**
  /// après une déconnexion ou une session expirée, et c'est précisément alors qu'on
  /// la touche.
  void _openConversation(String groupId) {
    if (!mounted) return;
    ref.requireSession(
      action: () => ref.read(routerProvider).goNamed(
        AppRoute.groupChat,
        pathParameters: {'id': groupId},
      ),
    );
  }

  @override
  void dispose() {
    _intents?.close();
    _bibleMarks?.close();
    _messaging?.close();
    _notifications?.close();
    unawaited(_wakes?.cancel());
    ApiClient.instance.onUnauthorized = null;
    ApiClient.instance.interfaceLanguage = null;
    super.dispose();
  }

  /// Le serveur a refusé le token : `ApiClient` l'a purgé, l'état d'auth repasse
  /// à « invité », et **la personne est renvoyée vers l'écran de connexion**.
  ///
  /// ## Pourquoi ce n'est pas la même destination que la déconnexion
  ///
  /// Les deux gestes finissent sur le même *état* — invité — et sur deux
  /// *écrans* différents. Ça ressemble à une incohérence à lisser ; c'en est
  /// exactement l'inverse, et c'est une décision du client, prise sur ce cas
  /// nommément. Avant d'unifier, lire ceci :
  ///
  /// - **déconnexion explicite** → accueil invité, rien d'effacé. La personne a
  ///   choisi de partir ; on ne lui demande pas de revenir. Rien ne navigue :
  ///   l'état change et la garde du routeur en déduit l'accueil ;
  /// - **session expirée (401)** → écran de connexion. Elle n'a **rien choisi**,
  ///   et l'éjection lui dit quelque chose que le silence ne dit pas. La reposer
  ///   sur l'accueil invité serait la seule façon de lui cacher qu'elle a perdu
  ///   sa session — et c'est la contrainte de fond du client : « quand la
  ///   personne s'est déjà connectée, tout se passe exactement comme
  ///   présentement ».
  ///
  /// L'écran de connexion **est le formulaire** : l'éjection menait jusqu'ici
  /// sur l'écran de bienvenue, qui n'avait ni flèche de retour ni rien à faire
  /// — une page de plus à traverser pour quelqu'un qui n'avait rien demandé.
  /// `go` et non `push`, comme avant : il n'y a pas de pile à conserver, et c'est
  /// pour ça que le formulaire n'y montre aucune flèche de retour — il n'y a
  /// nulle part où revenir.
  ///
  /// L'éjection est une **navigation explicite**, et non plus une déduction de
  /// la garde : sous le mode invité, la garde est publique par défaut, et lui
  /// faire porter un cas « renvoie tout vers `/auth` » y remettrait le verrou
  /// qu'on vient d'en retirer. Un 401 est un **évènement**, pas un état.
  ///
  /// Et elle ne concerne **que** ceux qui avaient une session : un invité dont
  /// une requête se fait refuser reste devant son catalogue. C'est ce que dit la
  /// valeur de retour de `handleUnauthorized()`, et c'est un vrai cas — un
  /// invité sans jeton d'appareil (ouverture de session refusée) voit ses
  /// requêtes prendre un 401 qui n'est estampillé « appareil » par personne.
  void _handleUnauthorized() {
    if (!mounted) return;
    if (!ref.read(authProvider.notifier).handleUnauthorized()) return;
    ref.read(routerProvider).goNamed(AppRoute.authIdentifier);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      routerConfig: router,
      // **Sous `MaterialApp`, et c'est obligatoire** : `VocabularyBoundary` pose
      // les surcharges du portail sur l'arbre, et `context.words` y lit la
      // locale que le framework vient de résoudre — `Localizations` n'existe pas
      // au-dessus. Même motif que `_ContentLocaleSync`, à côté duquel il vit.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // **Le texte suit le réglage système, mais pas jusqu'à la démesure.**
        // Au-delà de [kMaxTextScale], des mises en page écrites pour 1.0
        // débordent — lignes coupées, boutons qui se chevauchent. Le réglage de
        // la personne reste respecté jusqu'au plafond ; c'est le seul endroit de
        // l'application où l'échelle de texte est décidée.
        maxScaleFactor: kMaxTextScale,
        child: VocabularyBoundary(
          child: _ContentLocaleSync(
            // **Le mini-lecteur (#117), au-dessus du `Navigator`** : les routes
            // sont plates, et un écran poussé recouvre la coquille d'onglets.
            // Sous la frontière de vocabulaire et l'échelle de texte bornée,
            // comme n'importe quel écran. Voir `MiniPlayerHost`.
            child: MiniPlayerHost(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recopie dans [contentLocaleProvider] la locale que `MaterialApp` a
/// **réellement résolue**.
///
/// Deux lecteurs en vivent : le repli des contenus, et l'en-tête
/// `Accept-Language` d'`ApiClient` (#131), branché dans `initState` de
/// l'application. Une seule copie, donc une seule langue sur l'écran et sur le
/// fil.
///
/// C'est le seul endroit de l'application où les deux existent : la résolution
/// de locale (langues du système ✕ [appSupportedLocales]) appartient au
/// framework et ne se lit que sous `MaterialApp`, tandis que le repli de
/// contenu se fait hors de l'arbre, dans les repositories. La re-dériver depuis
/// `PlatformDispatcher` donnerait une seconde résolution, qui divergerait de la
/// première.
///
/// L'écriture est **différée d'une image** : modifier un provider pendant la
/// construction de l'arbre est interdit, et la valeur par défaut (le français,
/// langue de repli du contenu) est exactement ce que `pick` aurait choisi de
/// toute façon.
class _ContentLocaleSync extends ConsumerStatefulWidget {
  const _ContentLocaleSync({required this.child});

  final Widget child;

  @override
  ConsumerState<_ContentLocaleSync> createState() => _ContentLocaleSyncState();
}

class _ContentLocaleSyncState extends ConsumerState<_ContentLocaleSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(contentLocaleProvider.notifier).set(locale);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
