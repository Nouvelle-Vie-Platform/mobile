import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/network/api_client.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/auth_providers.dart';
import 'state/locale_providers.dart';
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
        // Le rapport ne remonte à aucun écran : une synchronisation qui échoue
        // laisse simplement le magasin en l'état, et l'écran affiche ce qu'il a.
        unawaited(ref.read(syncSchedulerProvider).start());
      });
    }
  }

  @override
  void dispose() {
    ApiClient.instance.onUnauthorized = null;
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
