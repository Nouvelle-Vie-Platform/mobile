/// **L'écran de New Life Radio** — anciennement `LivePlayerScreen`, qui jouait la
/// RTBF belge (#104).
///
/// Il est **réutilisé, pas réécrit** : il savait déjà lire un flux, l'afficher et
/// l'arrêter, et il démarre au montage (`isLive: true`), parce qu'un flux qu'on
/// ouvre sans le suivre n'a pas de sens. Ce qui change est sa **source** — une
/// route publique au lieu d'une constante — et son **libellé**.
///
/// ⚠️ Le fichier a été renommé avec son contenu. Le culte en direct est une
/// **autre** fonctionnalité, qui n'existe pas vraiment aujourd'hui et qui méritera
/// son propre chantier ; garder le nom « live » sur un écran qui diffuse la radio
/// aurait installé le mensonge pour longtemps.
///
/// ## C'est ici que la cause se lit (#125)
///
/// Le bouton de l'accueil porte un libellé fixe (44092f0) : il ne nomme aucune
/// panne. C'est donc cet écran qui dit pourquoi l'antenne ne joue pas, à la
/// place de la scène centrale de la fiche ([RadioAirStatus]).
///
/// ## La page live (#135)
///
/// L'écran a pris la forme d'un live (décision 12 du plan radio live) : fond
/// de saison plein écran, badge « EN DIRECT » et compteur en haut, fil en bas à
/// gauche, réactions à droite — `widgets/radio_live/`. **L'écoute n'a pas
/// bougé** : `ContentPlayerView` charge toujours par `openSource`, relance par
/// `RadioListening.start`, et dispose ses pièces dans la scène
/// ([ContentPlayerView.scene]) au lieu de sa fiche. La couche sociale
/// (`radioLiveProvider`) vit **à côté** du son : elle s'ouvre avec la page, se
/// ferme avec elle, et sa panne ne coupe rien.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/radio/radio_failure.dart';
import '../data/radio/radio_status.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../state/radio_live_providers.dart';
import '../state/radio_providers.dart';
import '../state/season_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_error_state.dart';
import '../widgets/content_player_view.dart';
import '../widgets/radio_live/radio_live_scene.dart';

class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Le titre entre par la **clé de famille** du provider : c'est ce qui le fait
    // arriver jusqu'au lecteur, donc jusqu'à la notification et à l'écran
    // verrouillé, sans sortir des `.arb`. Voir `radioContentProvider`.
    final title = l10n.radioTitle;
    Future<void> start() =>
        ref.read(radioListeningProvider.notifier).start(title: title);

    // **La couche sociale vit tant que la page vit** (#135), et pas une
    // seconde de plus : `radioLiveProvider` est `autoDispose`, et cette écoute
    // est ce qui le garde ouvert — y compris pendant que la route d'antenne
    // charge, quand la scène n'est pas encore montée. Quitter la page le jette,
    // et le canal temps réel se ferme avec lui. Un `listen` et non un `watch` :
    // un cœur qui monte ne doit pas reconstruire le lecteur.
    ref.listen(radioLiveProvider, (_, __) {});

    return ContentPlayerView(
      content: radioContentProvider(title),
      chromeTitle: title,
      // Une antenne dont on ne connaît pas l'adresse n'est pas « un contenu
      // retiré » : c'est l'antenne qui manque. Le bouton de l'accueil, lui, ne
      // nomme aucune cause — c'est ici qu'elle se lit.
      retractedTitle: l10n.radioFailureAntenna,
      retractedMessage: l10n.radioUnavailableMessage,
      onRetry: () => ref.invalidate(radioAntennaProvider),
      downloadContentType: null,
      isLive: true,
      // **L'écran n'ouvre plus l'antenne lui-même** (#110), et c'est le seul
      // moyen d'obtenir que *tout* chemin porte le cookie de MediaMTX (#108).
      //
      // `ContentPlayerView` chargeait l'URL de la playlist **sans en-têtes** :
      // un lien profond vers `/radio` — ou le second appui du bouton pendant les
      // cinq secondes du pré-vol, qui gagnait la course — ouvrait l'antenne nue
      // et prenait `401 {"error":"session not found"}`, sans qu'aucune phrase ne
      // relie le silence à sa cause.
      //
      // ⚠️ **Ce n'est pas un second pré-vol en série.** `start` est idempotent :
      // un démarrage déjà en vol le fait rendre tout de suite, et un lecteur qui
      // tient déjà l'antenne reçoit un simple `play()`. Rien n'est pris de plus
      // sur la fenêtre de rattrapage de 40 secondes de l'antenne.
      openSource: start,
      // **La scène dit l'état réel de l'antenne** (#125), à la place de « Lecture
      // interrompue » et d'« il faut du réseau » : ces deux phrases ignoraient la
      // reprise en cours et la cause classée, et leur « Reprendre » rouvrait
      // sans pré-vol. Ici, toute relance passe par `start`.
      //
      // **La page live** (#135) : la scène dispose les pièces du lecteur —
      // le gros bouton déjà câblé, l'arrêt — autour de la couche sociale.
      // L'état de l'écoute garde la place centrale qu'il avait.
      scene: (context, parts) => RadioLiveScene(
        parts: parts,
        title: title,
        status: RadioAirStatus(onRetry: start),
      ),
      // Le plancher de la cascade : la saison gagne quand le portail en a une.
      // Même image que l'écran de démarrage et que le splash natif.
      fallbackBackgroundAsset: kAppBackgroundAsset,
      onStop: () {
        // **Par le contrôleur, pas par le lecteur.** Un `stop()` posé directement
        // sur le lecteur couperait le son en laissant la reprise armée : le
        // contrôleur rouvrirait l'antenne quelques secondes plus tard, sans que
        // personne ne l'ait demandé.
        ref.read(radioListeningProvider.notifier).stop();
        Navigator.of(context).pop();
      },
    );
  }
}

/// **Ce que l'antenne fait, dit en une ligne — ou, après abandon, sa cause.**
///
/// Quatre états, lus sur [RadioStatus] et sur la route d'antenne, par ordre de
/// priorité :
///
/// | état | ce qui s'affiche |
/// | --- | --- |
/// | abandon | la cause (`radio_failure.dart`), et « Réessayer » |
/// | reprise | « Nouvelle tentative… » — **sans** nommer la panne qu'on combat |
/// | lecture | « À l'antenne » — pas « En direct », réservé au badge d'un direct de la régie (#135) |
/// | hors antenne | « Hors antenne », quand la route a dit `onAir: false` |
///
/// Sinon — au repos ou en connexion sur une antenne qui émet ou dont on ne sait
/// rien —, rien : le bouton de lecture montre déjà qu'il cherche, et le fond de
/// l'écran reste visible, comme avant.
///
/// ⚠️ **`onAir` nul n'est pas `onAir` faux** : seul [RadioAntenna.isSilent]
/// affiche « Hors antenne ». Un échec de lecture de la route, un premier
/// lancement, un corps illisible rendent une antenne inconnue, et dire « Hors
/// antenne » sur cette base affirmerait que l'église ne diffuse pas.
///
/// ⚠️ **La lecture et la reprise passent avant « hors antenne »** : l'état n'est
/// lu qu'au lancement et au retour à l'écran, et l'antenne a pu reprendre
/// entre-temps — le son qui sort l'emporte sur ce que la route disait.
class RadioAirStatus extends ConsumerWidget {
  const RadioAirStatus({super.key, required this.onRetry});

  /// La relance. **Toujours `RadioListening.start`**, jamais le contrôleur seul :
  /// c'est lui qui fait le pré-vol et porte le cookie (#108, #110), et c'est
  /// aussi lui qui efface le renoncement.
  final VoidCallback onRetry;

  /// Les témoins de chaque état, visés par clé dans les tests : c'est « l'écran
  /// montre la reprise » qu'on vérifie, pas la forme du widget qui la montre.
  static const Key offAirKey = Key('radio_air_off');
  static const Key liveKey = Key('radio_air_live');
  static const Key retryingKey = Key('radio_air_retrying');
  static const Key failedKey = Key('radio_air_failed');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(radioListeningProvider);
    final silent = ref.watch(
      radioAntennaProvider.select((a) => a.value?.isSilent ?? false),
    );

    final Widget line = switch (status.phase) {
      RadioPhase.failed => AppErrorState(
          key: failedKey,
          title: _cause(status.failure, l10n),
          message: l10n.radioGaveUpMessage,
          icon: _causeIcon(status.failure),
          onRetry: onRetry,
        ),
      RadioPhase.retrying => _StatusPill(
          key: retryingKey,
          leading: const SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white,
            ),
          ),
          label: l10n.radioRetrying,
        ),
      RadioPhase.playing => _StatusPill(
          key: liveKey,
          color: AppColors.primary,
          leading: const _LiveDot(),
          label: l10n.radioLive,
        ),
      RadioPhase.idle || RadioPhase.connecting when silent => _StatusPill(
          key: offAirKey,
          leading: const Icon(
            Icons.sensors_off_rounded,
            size: 12,
            color: Colors.white,
          ),
          label: l10n.radioOffAir,
        ),
      _ => const SizedBox.shrink(),
    };

    // Seul l'abandon occupe le centre de la page ; une pastille se range dans
    // la rangée du haut, à la place du badge EN DIRECT (`RadioLiveScene`).
    if (status.phase != RadioPhase.failed) return line;
    return Center(child: SingleChildScrollView(child: line));
  }

  /// Les trois phrases de `radio_failure.dart`. `null` ne devrait pas arriver
  /// sur un abandon — `_abandon` tombe sur « connexion » faute de cause — mais le
  /// type le permet, et le repli suit la même règle.
  static String _cause(RadioFailureKind? kind, AppLocalizations l10n) =>
      switch (kind) {
        RadioFailureKind.antenna => l10n.radioFailureAntenna,
        RadioFailureKind.unknown => l10n.radioFailureUnknown,
        RadioFailureKind.connection || null => l10n.radioFailureConnection,
      };

  static IconData _causeIcon(RadioFailureKind? kind) => switch (kind) {
        RadioFailureKind.antenna => Icons.sensors_off_rounded,
        RadioFailureKind.unknown => Icons.error_outline_rounded,
        RadioFailureKind.connection || null => Icons.wifi_off_rounded,
      };
}

/// Une ligne d'état courte, sur une pastille de la forme du badge EN DIRECT
/// (`RadioLiveScene`), dont elle partage la place : texte blanc sur un voile
/// sombre, ou sur le bleu de marque quand l'antenne joue — la pastille
/// « À l'antenne » du mini-lecteur.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    super.key,
    required this.leading,
    required this.label,
    this.color,
  });

  final Widget leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le voyant d'antenne : un point blanc fixe, comme celui du badge EN DIRECT.
/// Fixe, et pas clignotant — une animation continue de plus interdirait `pumpAndSettle` à tous les tests qui
/// montent cet écran, et le bouton de lecture dit déjà que ça joue.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(dimension: 8),
      );
}
