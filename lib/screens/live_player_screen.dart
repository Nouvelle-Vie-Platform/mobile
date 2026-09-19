import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/live_stream_config.dart';
import '../l10n/l10n_extension.dart';
import '../models/gathering_view.dart';
import '../models/content_view.dart';
import '../state/player_providers.dart';
import '../widgets/content_player_view.dart';

/// Provider synthétique du flux live — une `AsyncValue.data` statique, jamais
/// `loading` ni `error` : le contenu existe toujours, c'est l'URL qui peut
/// être indisponible, et c'est le lecteur (via [ContentPlayerView]) qui en
/// rend compte.
///
/// Posé ici, à côté de son seul consommateur, et non dans `player_providers`
/// pour ne pas mélanger les concerns : ce provider ne concerne que l'habillage
/// du lecteur live, pas l'état de lecture global.
final _liveContentProvider = Provider<AsyncValue<ContentView?>>((ref) {
  return AsyncValue.data(
    GatheringView(
      id: LiveStreamConfig.liveContentId,
      title: LiveStreamConfig.defaultTitle,
      // Couleur de marque primaire : le live n'a pas de rubrique dont hériter.
      color: kBrandFallbackColor,
      authorName: LiveStreamConfig.defaultAuthor,
      // Le flux MP3 direct est passé comme `playlistUrl` : ContentPlayerView
      // lit ce champ et le confie tel quel à ContentPlayer.load(url: ...).
      // just_audio sait jouer un flux MP3 en continu avec setUrl, il n'exige
      // pas un manifeste HLS.
      playlistUrl: LiveStreamConfig.defaultStreamUrl,
    ),
  );
});

/// Écran lecteur du **flux en direct**, construit sur le même [ContentPlayerView]
/// que les enseignements et les rassemblements.
///
/// Il n'y a rien à résoudre en base de données : le contenu est synthétique,
/// construit depuis [LiveStreamConfig]. [ContentPlayerView] reçoit un provider
/// statique ([_liveContentProvider]) dont la valeur est toujours
/// `AsyncValue.data(...)` — il passe donc directement dans l'état
/// `_buildPlayer`, charge l'URL et démarre la lecture.
///
/// La logique de retrait, de buffering, d'erreur et de pause/reprise est
/// entièrement portée par [ContentPlayerView] — rien n'est dupliqué ici.
class LivePlayerScreen extends ConsumerWidget {
  const LivePlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContentPlayerView(
      content: _liveContentProvider,
      chromeTitle: context.l10n.liveAppBarTitle,
      retractedTitle: context.l10n.liveRetractedTitle,
      retractedMessage: context.l10n.liveRetractedMessage,
      onRetry: () => ref.invalidate(_liveContentProvider),
      // Le bouton Télécharger n'a pas de sens pour un flux live continu.
      downloadContentType: null,
      // Mode live : top-bar sans info, play→stop, bouton pause conditionnel.
      isLive: true,
      onStop: () {
        ref.read(contentPlayerProvider).stop();
        Navigator.of(context).pop();
      },
    );
  }
}
