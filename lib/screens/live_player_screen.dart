import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/live_stream_config.dart';
import '../l10n/l10n_extension.dart';
import '../models/gathering_view.dart';
import '../state/player_providers.dart';
import '../widgets/content_player_view.dart';

/// Provider synthétique du flux live.
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

/// Écran lecteur du flux en direct.
class LivePlayerScreen extends ConsumerWidget {
  const LivePlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContentPlayerView(
      content: _liveContentProvider,
      chromeTitle: context.l10n.liveAppBarTitle,
      retractedTitle: 'Direct indisponible',
      retractedMessage: 'Le flux en direct est actuellement indisponible.',
      onRetry: () => ref.invalidate(_liveContentProvider),
      downloadContentType: null,
      isLive: true,
      backgroundImage: 'assets/images/live_bg.png', // <-- Votre image de fond
      onStop: () {
        ref.read(contentPlayerProvider).stop();
        Navigator.of(context).pop();
      },
    );
  }
}
