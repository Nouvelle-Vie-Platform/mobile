/// **Le bouton d'antenne de l'accueil** — celui qui jouait la RTBF belge (#104).
///
/// Il portait un libellé en dur (« Suivre le live ») et ne faisait qu'**ouvrir une
/// page**, laquelle démarrait un flux de radio publique belge. Il lance désormais
/// New Life Radio, au premier contact, et montre avant qu'on appuie si l'antenne
/// émet : il s'atténue quand elle se tait.
///
/// ## Le geste, et pourquoi il est écrit à la main
///
/// ```
/// À L'ARRÊT          1 appui  → lance
///                    2 appuis → lance + ouvre la page
///
/// EN CONNEXION       1 appui  → (déjà parti)
///                    2 appuis → ouvre la page, connexion intacte
///                    3, 4, 5… → rien
///
/// EN LECTURE         1 appui  → arrête
///                    2 appuis → relance + ouvre la page
/// ```
///
/// Tout tient dans une phrase : **le premier appui agit, le second ajoute la
/// navigation, et les suivants ne font rien.** Le second rend aussi ce que le
/// premier avait retiré — c'est ce qui donne « relance + ouvre la page » en
/// lecture, sans une seule ligne qui parle de relancer.
///
/// ⚠️ Il n'existait **aucun double-appui dans l'application** avant celui-ci, et
/// `GestureDetector.onDoubleTap` ne pouvait pas le porter : il impose un délai au
/// simple appui. Le mécanisme vit dans `tap_burst.dart`, qui dit pourquoi en
/// détail.
///
/// ⚠️ **L'inertie de la connexion protège la connexion, pas la navigation.** On ne
/// peut ni relancer ni arrêter tant que ça cherche — c'est exactement ce qui casse
/// une connexion en cours —, mais ouvrir la page reste possible, et l'auditeur y
/// voit la même animation continuer. Elle ne couvre que la connexion *initiale* :
/// une antenne déjà entendue s'arrête toujours, y compris pendant qu'elle remplit
/// son tampon.
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
import '../../state/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'tap_burst.dart';

class RadioCtaPill extends ConsumerStatefulWidget {
  const RadioCtaPill({super.key});

  /// Le bouton lui-même — visé par clé et non par libellé : ce qu'un test fait
  /// avec lui (appuyer une, deux, cinq fois) ne doit pas dépendre de l'état dans
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

  final TapBurst _burst = TapBurst();

  /// **Ce que le premier appui de la rafale a retiré**, et que le second doit
  /// rendre.
  ///
  /// C'est toute la mécanique de « 2 appuis → relance + ouvre la page » : le
  /// second appui n'a pas à savoir dans quel état on était, il défait ce que le
  /// premier a fait puis navigue.
  bool _firstTapStopped = false;

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

  void _onTap() {
    final rank = _burst.register(ref.read(nowProvider)());
    switch (rank) {
      case 1:
        _firstTap();
      case 2:
        _secondTap();
      default:
        // 3ᵉ, 4ᵉ, 5ᵉ… : rien. Une rafale n'a que deux sens ; au-delà, l'auditeur
        // insiste, et répondre à son insistance ferait couper ce qu'il attend.
        break;
    }
  }

  void _firstTap() {
    final status = ref.read(radioListeningProvider);
    _firstTapStopped = false;

    // L'inertie : pendant la connexion initiale, le premier appui ne touche à
    // rien — le flux est déjà parti.
    if (!status.allowsTransport) return;

    final radio = ref.read(radioListeningProvider.notifier);
    if (status.isOn) {
      radio.stop();
      _firstTapStopped = true;
      return;
    }
    radio.start(title: context.l10n.radioTitle);
  }

  void _secondTap() {
    // **Rendre ce que le premier appui a retiré**, puis ouvrir la page. En
    // connexion il n'avait rien retiré : la connexion reste intacte.
    if (_firstTapStopped) {
      ref.read(radioListeningProvider.notifier).start(
            title: context.l10n.radioTitle,
          );
      _firstTapStopped = false;
    }
    context.pushNamed(AppRoute.radio);
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
              child: GestureDetector(
                key: RadioCtaPill.buttonKey,
                onTap: _onTap,
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
          ],
        );
      },
    );
  }
}
