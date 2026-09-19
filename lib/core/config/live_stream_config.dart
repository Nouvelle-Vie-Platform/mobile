/// Configuration du flux en direct (streaming radio/audio/vidéo).
///
/// Centralise l'URL et les métadonnées par défaut du direct pour permettre
/// de les modifier facilement ou de les surcharger ultérieurement via
/// une API distante ou des réglages administrateur.
class LiveStreamConfig {
  LiveStreamConfig._();

  /// URL de diffusion en direct par défaut.
  /// Actuellement configurée sur le flux audio RTBF.
  static String defaultStreamUrl =
      'https://radio.rtbf.be/viva-bxl/mp3-160/me';

  /// Identifiant unique réservé au direct dans [ContentPlayer].
  static const String liveContentId = 'live_stream';

  /// Titre diffusé au système (notification, lock screen, UI).
  static const String defaultTitle = 'Culte de Gloire — En direct';

  /// Auteur/Pasteur affiché pour le direct.
  static const String defaultAuthor = 'Pasteur Samuel';
}
