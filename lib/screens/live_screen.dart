import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/live_stream_config.dart';
import '../l10n/l10n_extension.dart';
import '../models/content_view.dart';
import '../models/gathering_view.dart';
import '../state/player_providers.dart';
import '../widgets/content_player_view.dart';

/// Provider synthétique du flux live.
///
/// Si [LiveStreamConfig.defaultStreamUrl] n'est pas encore défini dans la config,
/// le flux utilise par défaut l'URL du direct RTBF Viva BXL.
final _liveContentProvider = Provider<AsyncValue<ContentView?>>((ref) {
  const defaultUrl = 'https://radio.rtbf.be/jam/mp3-160/me';
  final streamUrl = LiveStreamConfig.defaultStreamUrl.isNotEmpty
      ? LiveStreamConfig.defaultStreamUrl
      : defaultUrl;

  return AsyncValue.data(
    GatheringView(
      id: LiveStreamConfig.liveContentId,
      title: LiveStreamConfig.defaultTitle,
      color: kBrandFallbackColor,
      authorName: LiveStreamConfig.defaultAuthor,
      playlistUrl: streamUrl,
    ),
  );
});

/// Écran lecteur du flux en direct, réutilisant le lecteur personnalisé [ContentPlayerView].
///
/// L'option [isLive] activée permet de :
/// - Masquer la barre supérieure contenant les notes, favoris et description.
/// - Adapter les boutons de contrôle pour autoriser la pause, la reprise (Play) et l'arrêt (Stop).
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
      downloadContentType: null,
      isLive: true,
      onStop: () {
        ref.read(contentPlayerProvider).stop();
        Navigator.of(context).pop();
      },
    );
  }
}