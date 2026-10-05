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
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/radio_providers.dart';
import '../state/season_providers.dart';
import '../widgets/content_player_view.dart';

class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Le titre entre par la **clé de famille** du provider : c'est ce qui le fait
    // arriver jusqu'au lecteur, donc jusqu'à la notification et à l'écran
    // verrouillé, sans sortir des `.arb`. Voir `radioContentProvider`.
    final title = l10n.radioTitle;

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
      openSource: () =>
          ref.read(radioListeningProvider.notifier).start(title: title),
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
