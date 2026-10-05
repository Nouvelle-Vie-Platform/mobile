/// **L'hôte du mini-lecteur** (#117) — le mini-lecteur au niveau de
/// l'application, au-dessus du `Navigator`.
///
/// Les routes sont plates (pas de `ShellRoute`) : la médiathèque, la recherche
/// et les autres écrans poussés recouvrent `/home` et sa barre d'onglets. Monté
/// dans `HomeShell`, le mini-lecteur disparaissait donc dès qu'on poussait un
/// écran. Il est désormais posé ici, par le `builder` de `MaterialApp.router`
/// (`app.dart`, et `pumpRouter` côté tests), **par-dessus** la pile.
///
/// Quatre règles qui se ratent en silence :
///
/// 1. **Il lit la route du sommet dans le routeur**, par
///    `routerDelegate.currentConfiguration` — jamais par `GoRouterState.of` :
///    au-dessus du `Navigator`, aucun état de route ne se lit dans le contexte.
///    Le délégué prévient à chaque `push`, `pop` et `go`. Dans la coquille
///    (`/home`), la carte se pose au-dessus de la barre et du bouton central ;
///    ailleurs, en bas de la zone sûre. Elle s'efface sur les routes de
///    [MiniPlayerHost.hiddenRoutes].
/// 2. **Il ne voit pas les fenêtres surgissantes** (dialogues, feuilles du bas,
///    menus) : elles ne changent pas la configuration du routeur. Un
///    [MiniPlayerPopupObserver], posé dans les `observers` du routeur, les
///    compte ; la carte s'efface tant qu'il y en a une. Sans lui, elle
///    flotterait **au-dessus** de la barrière et cacherait le bas d'une feuille.
/// 3. **Un écran peut demander à le masquer** par [MiniPlayerShield] — la
///    coquille le fait quand le menu latéral est ouvert et quand Annonces montre
///    un statut vidéo plein écran. La demande ne vaut que si la route de l'écran
///    est au sommet (`ModalRoute.isCurrentOf`) : une coquille recouverte par la
///    médiathèque ne masque rien.
/// 4. **La place qu'il prend est ajoutée au `MediaQuery.padding.bottom`** (et
///    `viewPadding`) de toute la pile, quand il est visible : les listes qui
///    finissent déjà par la marge basse de l'écran — médiathèque, accueil,
///    Échanges, Profil — et les `SafeArea` du bas (la saisie d'un fil)
///    s'écartent d'elles-mêmes, sans qu'aucun écran ne le connaisse. ⚠️ La
///    coquille est l'exception : sa barre est une `BottomAppBar` à `SafeArea`,
///    qui grandirait d'autant. Elle retire donc la marge autour de son
///    `Scaffold` ([WithoutMiniPlayerInset]) et la rend à ses onglets
///    ([WithMiniPlayerInset]).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../state/playback_controller.dart';
import '../theme/app_responsive.dart';
import '../theme/app_spacing.dart';
import 'app_bottom_nav.dart';
import 'mini_player.dart';

/// Pose le mini-lecteur par-dessus [child] — le `Navigator` de l'application.
class MiniPlayerHost extends ConsumerStatefulWidget {
  const MiniPlayerHost({super.key, required this.router, required this.child});

  /// Le routeur dont on lit la route du sommet. Passé et non lu dans
  /// `routerProvider` : les tests montent leurs propres routeurs.
  final GoRouter router;

  final Widget child;

  /// **Les routes où il s'efface.**
  ///
  /// - la fiche d'un enseignement et celle d'un rassemblement : elles portent
  ///   déjà le lecteur complet (`ContentPlayerView`), deux lecteurs à l'écran
  ///   seraient un doublon. Le rassemblement est masqué sans condition : sa
  ///   fiche **est** un `ContentPlayerView`, et la place du lecteur y est prise
  ///   même quand il n'y a rien à lire ;
  /// - l'antenne, pour la même raison ;
  /// - le démarrage, l'authentification et la barrière de consentement : des
  ///   parcours **bloquants**, où une carte de plus gênerait le seul geste
  ///   attendu (« Continuer », la case à cocher) sans rien apporter — la lecture
  ///   continue, et la carte revient dès qu'on en sort ;
  /// - la visionneuse plein écran des médias d'un fil.
  static const Set<String> hiddenRoutes = {
    AppRoute.splash,
    AppRoute.authIdentifier,
    AppRoute.authCode,
    AppRoute.legalAccept,
    AppRoute.teachingDetail,
    AppRoute.gatheringDetail,
    AppRoute.radio,
    AppRoute.mediaViewer,
  };

  /// La marge dans la coquille : la gouttière sur les côtés, et en bas de quoi
  /// dégager le bouton central — la moitié d'un `FloatingActionButton` standard
  /// (56 px) dépasse au-dessus de la barre, plus un intervalle.
  static const EdgeInsets shellMargin = EdgeInsets.fromLTRB(
    AppSpacing.sm,
    AppSpacing.sm,
    AppSpacing.sm,
    56 / 2 + AppSpacing.sm,
  );

  /// La marge sur un écran empilé : rien à dégager, la carte se pose au ras de
  /// la zone sûre.
  static const EdgeInsets stackedMargin = EdgeInsets.all(AppSpacing.sm);

  /// **La hauteur qu'occupe le mini-lecteur**, marges comprises — zéro quand il
  /// est masqué. C'est la valeur ajoutée à `MediaQuery.padding.bottom` ; on ne
  /// la lit directement que là où un écran pose une marge **sans** passer par
  /// le `MediaQuery` (le formulaire d'un onglet réservé), ou pour la retirer.
  static double insetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MiniPlayerScope>()?.inset ??
      0;

  @override
  ConsumerState<MiniPlayerHost> createState() => _MiniPlayerHostState();
}

class _MiniPlayerHostState extends ConsumerState<MiniPlayerHost> {
  /// Les écrans qui demandent, en ce moment, à le masquer.
  final Set<Object> _shields = {};

  MiniPlayerPopupObserver? _popups;

  /// La dernière hauteur mesurée de la carte, marges comprises.
  double _measured = 0;

  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _attach(widget.router);
  }

  @override
  void didUpdateWidget(MiniPlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    _detach(oldWidget.router);
    _attach(widget.router);
  }

  @override
  void dispose() {
    _detach(widget.router);
    super.dispose();
  }

  void _attach(GoRouter router) {
    router.routerDelegate.addListener(_refresh);
    _popups = MiniPlayerPopupObserver.of(router)?..addListener(_refresh);
  }

  void _detach(GoRouter router) {
    router.routerDelegate.removeListener(_refresh);
    _popups?.removeListener(_refresh);
    _popups = null;
  }

  /// **Reconstruire, mais jamais pendant une construction.**
  ///
  /// Le délégué du routeur et l'observateur préviennent pendant que le
  /// `Navigator` vide sa file — c'est-à-dire en pleine construction, sous
  /// l'hôte. Un `setState` sur un ancêtre à ce moment-là lève ; on attend donc
  /// la fin de l'image.
  void _refresh() {
    if (!mounted) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    binding.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _shield(Object token, {required bool active}) {
    final changed = active ? _shields.add(token) : _shields.remove(token);
    if (changed) _refresh();
  }

  void _onMeasured(double height) {
    if (height == _measured) return;
    _measured = height;
    _refresh();
  }

  /// Le nom de la route du sommet, ou `null` quand il n'y en a aucune de
  /// résolue (démarrage, page d'erreur) — la carte s'efface alors.
  ({bool known, String? name}) _top() {
    final config = widget.router.routerDelegate.currentConfiguration;
    if (config.isEmpty || config.isError) return (known: false, name: null);
    return (known: true, name: config.last.route.name);
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(playbackControllerProvider);
    final media = MediaQuery.of(context);
    final top = _top();

    final visible = request != null &&
        top.known &&
        !MiniPlayerHost.hiddenRoutes.contains(top.name) &&
        !(_popups?.hasPopup ?? false) &&
        _shields.isEmpty &&
        // **Clavier ouvert, carte effacée** : elle passerait sous le clavier,
        // et sa marge écarterait la saisie d'autant pour rien.
        media.viewInsets.bottom == 0;
    final inShell = top.name == AppRoute.home;
    final inset = visible ? _measured : 0.0;

    return _MiniPlayerScope(
      state: this,
      inset: inset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Toujours enveloppé, même à marge nulle : changer la forme de
          // l'arbre ici remonterait le `Navigator` entier.
          MediaQuery(data: _shift(media, inset), child: widget.child),
          if (visible)
            Positioned(
              left: 0,
              right: 0,
              bottom:
                  media.padding.bottom + (inShell ? AppBottomNav.barHeight : 0),
              // **Le routeur posé à la main** : au-dessus du `Navigator`,
              // `GoRouter.of` ne trouverait rien, et l'appui sur la carte doit
              // ouvrir la fiche dans *ce* routeur.
              child: InheritedGoRouter(
                goRouter: widget.router,
                child: ContentMaxWidth(
                  child: _MeasureHeight(
                    onChanged: _onMeasured,
                    child: MiniPlayer(
                      margin: inShell
                          ? MiniPlayerHost.shellMargin
                          : MiniPlayerHost.stackedMargin,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ajoute (ou retire, [delta] négatif) la place du mini-lecteur au bas de
/// `padding` et de `viewPadding`.
MediaQueryData _shift(MediaQueryData data, double delta) {
  if (delta == 0) return data;
  return data.copyWith(
    padding: data.padding.copyWith(
      bottom: math.max(0.0, data.padding.bottom + delta),
    ),
    viewPadding: data.viewPadding.copyWith(
      bottom: math.max(0.0, data.viewPadding.bottom + delta),
    ),
  );
}

class _MiniPlayerScope extends InheritedWidget {
  const _MiniPlayerScope({
    required this.state,
    required this.inset,
    required super.child,
  });

  final _MiniPlayerHostState state;
  final double inset;

  @override
  bool updateShouldNotify(_MiniPlayerScope oldWidget) =>
      inset != oldWidget.inset || state != oldWidget.state;
}

/// **Retire la place du mini-lecteur** du `MediaQuery` de [child].
///
/// Pour la coquille seule : sa `BottomAppBar` porte une `SafeArea`, et la
/// marge ajoutée par l'hôte la ferait grandir de la hauteur de la carte.
class WithoutMiniPlayerInset extends StatelessWidget {
  const WithoutMiniPlayerInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: _shift(MediaQuery.of(context), -MiniPlayerHost.insetOf(context)),
        child: child,
      );
}

/// **Rend la place du mini-lecteur** au `MediaQuery` de [child] — les onglets
/// de la coquille, sous un [WithoutMiniPlayerInset].
class WithMiniPlayerInset extends StatelessWidget {
  const WithMiniPlayerInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: _shift(MediaQuery.of(context), MiniPlayerHost.insetOf(context)),
        child: child,
      );
}

/// **Masque le mini-lecteur** tant que [hidden] est vrai **et** que la route
/// qui porte ce widget est au sommet.
///
/// Déclaratif : la demande tombe d'elle-même quand l'écran est démonté ou
/// recouvert. Sans hôte au-dessus (un écran monté seul en test), il ne fait
/// rien.
class MiniPlayerShield extends StatefulWidget {
  const MiniPlayerShield({
    super.key,
    required this.hidden,
    required this.child,
  });

  final bool hidden;
  final Widget child;

  @override
  State<MiniPlayerShield> createState() => _MiniPlayerShieldState();
}

class _MiniPlayerShieldState extends State<MiniPlayerShield> {
  _MiniPlayerHostState? _host;
  bool _active = false;
  bool _isCurrent = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .getElementForInheritedWidgetOfExactType<_MiniPlayerScope>()
        ?.widget as _MiniPlayerScope?;
    final host = scope?.state;
    if (host != _host) {
      _host?._shield(this, active: false);
      _host = host;
      _active = false;
    }
    _isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _sync();
  }

  @override
  void didUpdateWidget(MiniPlayerShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final active = widget.hidden && _isCurrent;
    if (active == _active) return;
    _active = active;
    _host?._shield(this, active: active);
  }

  @override
  void dispose() {
    _host?._shield(this, active: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// **Compte les fenêtres surgissantes** (`PopupRoute` : dialogues, feuilles du
/// bas, menus) de la pile principale.
///
/// À poser dans les `observers` du `GoRouter` : l'hôte l'y retrouve
/// ([MiniPlayerPopupObserver.of]). Un routeur qui n'en porte pas (la plupart des
/// routeurs de test) garde un mini-lecteur visible sous ses dialogues.
class MiniPlayerPopupObserver extends NavigatorObserver with ChangeNotifier {
  int _count = 0;

  /// Vrai tant qu'une fenêtre surgissante est ouverte.
  bool get hasPopup => _count > 0;

  /// L'observateur posé sur [router], s'il y en a un.
  static MiniPlayerPopupObserver? of(GoRouter router) {
    for (final observer in router.routerDelegate.builder.observers) {
      if (observer is MiniPlayerPopupObserver) return observer;
    }
    return null;
  }

  void _shift(Route<dynamic>? route, int delta) {
    if (route is! PopupRoute) return;
    _count = math.max(0, _count + delta);
    notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _shift(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _shift(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _shift(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _shift(oldRoute, -1);
    _shift(newRoute, 1);
  }
}

/// Rapporte la hauteur de son enfant après chaque mise en page qui la change.
///
/// Mesurée plutôt que calculée : la carte suit l'échelle de texte du système,
/// et une constante se désaccorderait au premier réglage d'accessibilité.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChanged, super.child});

  final ValueChanged<double> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChanged);

  ValueChanged<double> onChanged;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    // Jamais pendant la mise en page : l'hôte se reconstruirait au milieu.
    SchedulerBinding.instance.addPostFrameCallback((_) => onChanged(height));
  }
}
