/// Configuration du flux en direct (streaming radio/audio/vidéo).
///
/// Centralise l'URL et les métadonnées par défaut du direct pour permettre
/// de les modifier facilement ou de les surcharger ultérieurement via
/// une API distante ou des réglages administrateur.
class LiveStreamConfig {
  LiveStreamConfig._();

  /// URL de diffusion en direct par défaut.
  ///
  /// Placeholder configurable : le jour où le serveur servira l'URL du culte,
  /// on la lira ici plutôt que de la disperser dans les écrans.
  static const String defaultStreamUrl = 'https://radio.rtbf.be/jam/mp3-160/me';

  /// Identifiant unique réservé au direct dans [ContentPlayer].
  static const String liveContentId = 'live_stream';

  /// Titre diffusé au système (notification, lock screen, UI).
  static const String defaultTitle = 'En direct';

  /// Auteur/Pasteur affiché pour le direct.
  static const String defaultAuthor = 'Eglise Evangelique Nouvelle Vie';
}
