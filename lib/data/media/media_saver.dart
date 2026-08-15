/// Enregistrement d'un média dans la galerie de l'appareil, **derrière une
/// abstraction** — comme `StatusImagePicker` ou `AppVersionReader` : les tests
/// posent un enregistreur inerte, sans canal de plugin ni accès réseau.
///
/// L'implémentation réelle vit dans `gal_media_saver.dart` (plugin `gal`).
abstract class MediaSaver {
  const MediaSaver();

  /// Télécharge l'image à [url] et l'enregistre dans la galerie Photos.
  ///
  /// Lève [MediaSaveException] pour **toute** issue (permission refusée, panne
  /// réseau, plateforme non supportée, inattendu) : l'appelant choisit la phrase
  /// à afficher, il n'y a pas de valeur de retour.
  Future<void> saveImageFromUrl(String url);
}

/// Cause d'un échec d'enregistrement — mappe une phrase côté écran.
enum MediaSaveError { permissionDenied, network, unsupported, unknown }

class MediaSaveException implements Exception {
  const MediaSaveException(this.error);

  final MediaSaveError error;

  @override
  String toString() => 'MediaSaveException($error)';
}

/// Enregistreur **inerte** pour les tests : ne touche ni au réseau ni à un
/// plugin, considère chaque enregistrement comme réussi.
class InertMediaSaver extends MediaSaver {
  const InertMediaSaver();

  @override
  Future<void> saveImageFromUrl(String url) async {}
}
