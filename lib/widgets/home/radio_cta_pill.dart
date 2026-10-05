/// **Le bouton d'antenne de l'accueil** — celui qui jouait la RTBF belge (#104).
///
/// Il portait un libellé en dur (« Suivre le live ») et ne faisait qu'**ouvrir une
/// page**, laquelle démarrait un flux de radio publique belge. Il lance désormais
/// New Life Radio, au premier contact, et montre avant qu'on appuie si l'antenne
/// émet : il s'atténue quand elle se tait.
///
/// ## Le geste : un appui agit, un appui long navigue (#134)
///
/// ```
/// APPUI SIMPLE   à l'arrêt     → lance
///                en connexion  → rien (le flux est déjà parti)
///                en lecture    → arrête
///
/// APPUI LONG     dans tous les états → ouvre la page, sans toucher au son
/// ```
///
/// ⚠️ **L'ancien double-appui coupait le son** (#104, `TapBurst`) : en lecture,
/// le premier appui arrêtait l'antenne et le second la relançait avant d'ouvrir
/// la page — la connexion était fermée puis rouverte, et ça s'entendait. L'appui
/// long, lui, ne touche jamais au lecteur : rien n'est arrêté puis relancé
/// (décision 14 du cadrage `radio-live-plan.md`).
///
/// ⚠️ **Pas de `onDoubleTap`, et l'appui long ne le remplace pas en douce.**
/// `onDoubleTap` imposerait un délai au simple appui : le détecteur attendrait
/// `kDoubleTapTimeout` avant de pouvoir dire qu'il n'y aura pas de second
/// contact. `onLongPress` n'a pas ce coût — au relâchement, la reconnaissance
/// d'appui long renonce d'elle-même et l'appui simple part **dans le même
/// événement** ; c'est le test « un appui simple agit sans aucune attente » qui
/// le tient, par un `pump()` sans durée.
///
/// ⚠️ **L'inertie de la connexion protège la connexion, pas la navigation.** On ne
/// peut ni relancer ni arrêter tant que ça cherche — c'est exactement ce qui casse
/// une connexion en cours —, mais l'appui long ouvre la page, et l'auditeur y
/// voit la même animation continuer. Elle ne couvre que la connexion *initiale* :
/// une antenne déjà entendue s'arrête toujours, y compris pendant qu'elle remplit
/// son tampon.
///
/// ## Le geste se découvre au moment où il sert
///
/// Un appui long ne se devine pas. Au **premier son** d'un lancement parti d'ici
/// (décision 15), un message dit qu'un appui long ouvre le live à tout moment.
/// Pas à l'échec — on n'invite pas vers une page en annonçant une panne —, pas
/// pour un lancement venu d'ailleurs (l'écran d'antenne, le mini-lecteur), et pas
/// quand l'accueil n'est plus au premier plan : l'auditeur qui a déjà ouvert la
/// page n'a plus rien à apprendre.
///
/// Les lecteurs d'écran annoncent l'action d'appui long (`onLongPressHint`) :
/// sans elle, le geste n'existerait que pour qui voit le message.
///
/// ## Le bouton éteint reste appuyable
///
/// Le libellé ne change pas — c'est le nom de l'antenne, dans tous les états.
/// Une antenne annoncée muette, ou un renoncement, se voit à l'**atténuation**
/// du bouton ; la cause d'une panne se lit sur `/radio`, pas ici.
///
/// L'atténuation **informe, elle n'interdit pas**. Si l'antenne a repris sans
/// qu'on le sache — l'état n'est lu qu'au lancement et au retour à l'écran —,
/// l'appui lance quand même, et marche. Même esprit qu'ADR-0040 pour
/// l'identifiant d'appareil, qui « sert à mesurer et à couper, jamais à
/// autoriser ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/radio/radio_status.dart';
import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../state/radio_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class RadioCtaPill extends ConsumerStatefulWidget {
  const RadioCtaPill({super.key});

  /// Le bouton lui-même — visé par clé et non par libellé : ce qu'un test fait
  /// avec lui (appuyer, appuyer longuement) ne doit pas dépendre de l'état dans
  /// lequel il le trouve.
  static const Key buttonKey = Key('radio_cta_button');

  /// Le témoin d'activité — connexion ou reprise. Une clé plutôt qu'un type :
  /// c'est « le bouton montre qu'il travaille » qu'on vérifie, pas le choix du
  /// widget qui tourne.
  static const Key workingKey = Key('radio_cta_working');

  @override
  ConsumerState<RadioCtaPill> createState() => _RadioCtaPillState();
}

class _RadioCtaPillState extends ConsumerState<RadioCtaPill>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<Color?> _iconColorAnim;

  /// **Un lancement parti d'ici attend son premier son**, pour dire alors
  /// qu'un appui long ouvre le live (décision 15).
  ///
  /// Posé par l'appui qui lance, et par lui seul : un lancement venu de l'écran
  /// d'antenne ou du mini-lecteur ne le pose pas. Levé au premier son, à
  /// l'échec, ou à l'arrêt — un seul message par lancement, et jamais pour
  /// annoncer une panne. La reprise (`retrying`) ne le lève pas : une antenne
  /// qui finit par répondre est un lancement réussi.
  bool _awaitingFirstSound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _iconColorAnim = ColorTween(
      begin: AppColors.danger.withValues(alpha: 0.3),
      end: AppColors.danger,
    ).animate(_animController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  /// **Le retour à l'écran relit l'antenne.**
  ///
  /// C'est la seconde moitié de la fraîcheur retenue par la décision 3 du cadrage
  /// — l'autre est le lancement, couvert par le premier `watch` de ce `build`. Pas
  /// de sondage, pas d'écoute continue : une antenne qui s'allume pendant qu'on
  /// regarde l'accueil n'est pas un cas qu'on cherche à servir, et le bouton
  /// éteint reste de toute façon appuyable.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(radioAntennaProvider);
  }

  /// **L'appui simple : lance ou arrête, tout de suite.**
  void _onTap() {
    final status = ref.read(radioListeningProvider);

    // L'inertie : pendant la connexion initiale, l'appui ne touche à rien — le
    // flux est déjà parti.
    if (!status.allowsTransport) return;

    final radio = ref.read(radioListeningProvider.notifier);
    if (status.isOn) {
      _awaitingFirstSound = false;
      radio.stop();
      return;
    }
    _awaitingFirstSound = true;
    radio.start(title: context.l10n.radioTitle);
  }

  /// **L'appui long : ouvre la page, et rien d'autre.**
  ///
  /// Aucune lecture de l'état, aucun appel au contrôleur d'écoute : c'est ce qui
  /// garantit qu'il ne coupe ni ne relance jamais le son, quel que soit l'état
  /// où il trouve l'antenne.
  void _onLongPress() {
    context.pushNamed(AppRoute.radio);
  }

  /// **Le premier son d'un lancement parti d'ici** — le moment où l'appui long
  /// se fait connaître.
  void _onStatusChanged(RadioStatus? previous, RadioStatus next) {
    if (!_awaitingFirstSound) return;
    switch (next.phase) {
      case RadioPhase.connecting:
      case RadioPhase.retrying:
        return; // pas encore : on attend la suite
      case RadioPhase.idle:
      case RadioPhase.failed:
        _awaitingFirstSound = false; // arrêté ou abandonné : rien à dire
        return;
      case RadioPhase.playing:
        _awaitingFirstSound = false;
    }
    // L'accueil n'est plus au premier plan — l'auditeur a déjà ouvert la page
    // ou s'en est allé ailleurs : le message tomberait hors de propos.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.radioLongPressTip)),
    );
  }

  Color? _getIconColor(RadioStatus status) {
    if (status.phase == RadioPhase.playing) {
      return AppColors.success;
    }
    return _iconColorAnim.value;
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(radioListeningProvider);
    ref.listen<RadioStatus>(radioListeningProvider, _onStatusChanged);
    // `.value` et non l'`AsyncValue` entière : une antenne qu'on n'a pas pu lire
    // n'est pas une antenne éteinte, et le bouton n'a rien à attendre pour
    // s'afficher au repos.
    final silent = ref.watch(radioAntennaProvider).value?.isSilent ?? false;

    // **Un libellé fixe** : le nom de l'antenne, dans tous les états. La phase se
    // lit sur l'icône et l'atténuation ; la cause d'une panne, sur `/radio`.
    final label = context.l10n.radioTitle;
    final dimmed =
        status.phase == RadioPhase.failed || (silent && !status.isOn);

    return AnimatedBuilder(
      animation: _iconColorAnim,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **Flexible, et le libellé avec lui** : sur un écran étroit (ou un
            // grand corps de texte), le libellé se replie en points de
            // suspension au lieu de faire déborder l'en-tête de l'accueil.
            Flexible(
              // **Un seul nœud d'accessibilité, qui annonce les deux gestes.**
              // Le détecteur s'en exclut : le nœud du `Semantics` porte les
              // deux actions, avec l'indice de l'appui long — sans quoi un
              // lecteur d'écran dirait seulement « bouton ».
              child: Semantics(
                container: true,
                button: true,
                onTap: _onTap,
                onLongPress: _onLongPress,
                onLongPressHint: context.l10n.radioOpenLiveHint,
                child: GestureDetector(
                  key: RadioCtaPill.buttonKey,
                  excludeFromSemantics: true,
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: dimmed ? 0.55 : 1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status.isWorking)
                          SizedBox(
                            key: RadioCtaPill.workingKey,
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _getIconColor(status),
                            ),
                          )
                        else
                          Icon(
                            Icons.sensors,
                            size: 18,
                            color: _getIconColor(status),
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyStrong.copyWith(
                              color: AppColors.neutralDark
                                  .withValues(alpha: dimmed ? 0.7 : 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
