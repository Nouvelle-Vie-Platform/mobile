import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/network/api_client.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/auth_providers.dart';
import 'state/downloads_providers.dart';
import 'state/locale_providers.dart';
import 'state/session_gate.dart';
import 'state/startup_providers.dart';
import 'state/sync_providers.dart';
import 'state/theme_provider.dart';
import 'state/vocabulary_providers.dart';
import 'theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    // Point de jonction du 401 : `ApiClient` est un singleton de la couche
    // réseau, sans accès à Riverpod ni à GoRouter — et il ne doit pas en
    // acquérir. C'est ici, où les deux existent, qu'on branche la réaction.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;

    // **L'intention en attente doit rester vivante**, et c'est la seule raison
    // de cette ligne. `requireSession()` met un geste de côté et le rejoue à
    // l'ouverture de la session ; cette réaction est un `ref.listen` **interne**
    // au provider, et Riverpod 3 met en pause les abonnements d'un provider que
    // personne n'écoute. Sans cet abonnement-ci, le geste serait mis de côté et
    // jamais repris — sans erreur, sans trace : la personne se connecte, revient,
    // et son geste a disparu. Même motif que le routeur, que `build` observe.
    _intents = ref.listenManual(sessionGateProvider, (_, __) {});

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
        scheduler.onCycleSucceeded = (_) async {
          await ref.read(downloadLifecycleProvider).reconcile();
          await ref.read(downloadManagerProvider).reconcile();
        };
        // Le rapport ne remonte à aucun écran : une synchronisation qui échoue
        // laisse simplement le magasin en l'état, et l'écran affiche ce qu'il a.
        unawaited(scheduler.start());
      });
    }
  }

  @override
  void dispose() {
    _intents?.close();
    ApiClient.instance.onUnauthorized = null;
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
    ref.read(routerProvider).goNamed(AppRoute.authWelcome);
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
      builder: (context, child) => VocabularyBoundary(
        child: _ContentLocaleSync(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Recopie dans [contentLocaleProvider] la locale que `MaterialApp` a
/// **réellement résolue**.
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
