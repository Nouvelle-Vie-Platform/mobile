import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/chat_media_providers.dart';

/// **Une vidéo du fil, plein écran** (M4, #143). Fond noir, lecture au
/// toucher ; la surface vient de `chatVideoSurfaceProvider` — le seul chemin
/// vers `video_player`, inerte dans les tests.
class ChatVideoScreen extends ConsumerWidget {
  const ChatVideoScreen({super.key, required this.url});

  /// URL présignée, ou chemin local d'un écho.
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ref.watch(chatVideoSurfaceProvider).build(context, url),
      ),
    );
  }
}
