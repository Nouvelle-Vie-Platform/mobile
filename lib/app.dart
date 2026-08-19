import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/network/api_client.dart';
import 'data/realtime/realtime_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/auth_providers.dart';
import 'state/downloads_providers.dart';
import 'state/locale_providers.dart';
import 'state/realtime_providers.dart';
import 'state/sync_providers.dart';
import 'state/theme_provider.dart';
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
  /// L'abonnement au [realtimeServiceProvider], gardé pour être fermé au
  /// démontage. Il **redémarre** le service quand la session change : le
  /// provider se recrée alors (nouveau `userId`), Riverpod dispose l'ancien
  /// service, et ce rappel appelle `start()` sur le neuf. Voir plus bas.
  ProviderSubscription<RealtimeService>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    // Point de jonction du 401 : `ApiClient` est un singleton de la couche
    // réseau, sans accès à Riverpod ni à GoRouter — et il ne doit pas en
    // acquérir. C'est ici, où les deux existent, qu'on branche la réaction.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

        // **Le temps-réel (SSE Transmit)**, à côté des trois déclencheurs de
        // sync (`docs/temps-reel-sse.md` §2). Le `RealtimeService` ouvre une
        // connexion SSE au premier plan, s'abonne à tous mes groupes/DM et
        // déclenche une sync `SyncTrigger.realtime` à chaque événement (D1) :
        // le SSE **accélère** la sync, il ne peint jamais le message.
        //
        // On écoute le provider plutôt que de le lire une fois : à un
        // changement de session il se recrée (nouveau `userId`), Riverpod
        // dispose l'ancien service — observateur retiré, socket fermée — et ce
        // rappel démarre le neuf. `fireImmediately` couvre le tout premier
        // démarrage (l'app est au premier plan, la connexion s'ouvre d'emblée).
        _realtimeSub = ref.listenManual<RealtimeService>(
          realtimeServiceProvider,
          (previous, next) => next.start(),
          fireImmediately: true,
        );
      });
    }
  }

  @override
  void dispose() {
    ApiClient.instance.onUnauthorized = null;
    // Ferme l'écoute du temps-réel ; le service lui-même est disposé par le
    // `ref.onDispose` de son provider quand le conteneur Riverpod s'en va.
    _realtimeSub?.close();
    super.dispose();
  }

  /// Le serveur a refusé le token : `ApiClient` l'a purgé, on repasse l'état
  /// d'auth à « déconnecté ». La garde `redirect` du routeur, déjà branchée sur
  /// `authProvider`, ramène alors à `/auth` depuis n'importe quel écran — nul
  /// besoin de manipuler le routeur ici.
  void _handleUnauthorized() {
    if (!mounted) return;
    ref.read(authProvider.notifier).handleUnauthorized();
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
      builder: (context, child) =>
          _ContentLocaleSync(child: child ?? const SizedBox.shrink()),
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
