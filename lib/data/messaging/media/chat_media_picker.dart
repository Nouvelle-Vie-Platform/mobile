import '../../../models/message_media.dart';

/// Un fichier choisi dans le téléphone.
class PickedFile {
  const PickedFile({required this.path, required this.name, this.sizeBytes});

  final String path;
  final String name;
  final int? sizeBytes;
}

/// Un contact choisi : **son nom et ses numéros, rien d'autre** (plan §4).
class PickedContact {
  const PickedContact({required this.name, required this.phones});

  final String name;
  final List<ContactPhone> phones;
}

/// Ce que rend la demande de position.
sealed class LocationOutcome {
  const LocationOutcome();
}

class LocationFound extends LocationOutcome {
  const LocationFound(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// La permission est refusée — ou la localisation est coupée.
class LocationUnavailable extends LocationOutcome {
  const LocationUnavailable({required this.serviceDisabled});

  final bool serviceDisabled;
}

/// **Les sources d'un média joint** (M4, #143), derrière une couture : la
/// feuille du trombone et le bouton appareil photo n'appellent que ce contrat,
/// et les tests posent un double — les greffons lèveraient
/// `MissingPluginException` sous `flutter test`.
///
/// Toutes les méthodes rendent `null` quand la personne **annule** : refermer
/// un sélecteur sans rien choisir est le geste le plus fréquent, et il ne doit
/// rien poser au fil.
///
/// Les permissions sont demandées **au moment du geste**, jamais avant : la
/// position quand on choisit « Position », l'appareil photo par le système
/// quand on l'ouvre. Le contact passe par le **sélecteur du système** : aucune
/// permission de lecture du carnet, l'application ne voit que le contact
/// choisi.
abstract interface class ChatMediaPicker {
  Future<String?> takePhoto();
  Future<String?> pickPhoto();
  Future<String?> recordVideo();
  Future<String?> pickVideo();
  Future<PickedFile?> pickDocument();
  Future<PickedFile?> pickAudioFile();
  Future<LocationOutcome?> currentLocation();
  Future<PickedContact?> pickContact();
}

/// Double inerte : rien n'est choisi.
class InertChatMediaPicker implements ChatMediaPicker {
  const InertChatMediaPicker();

  @override
  Future<String?> takePhoto() async => null;
  @override
  Future<String?> pickPhoto() async => null;
  @override
  Future<String?> recordVideo() async => null;
  @override
  Future<String?> pickVideo() async => null;
  @override
  Future<PickedFile?> pickDocument() async => null;
  @override
  Future<PickedFile?> pickAudioFile() async => null;
  @override
  Future<LocationOutcome?> currentLocation() async => null;
  @override
  Future<PickedContact?> pickContact() async => null;
}

/// **Ouvrir hors de l'application** : une position dans l'application de
/// cartes, un document dans celle du système, un numéro dans le composeur.
/// Ne lève jamais ; rend `false` si rien ne s'est ouvert.
abstract interface class MediaOpener {
  Future<bool> openMap({
    required double latitude,
    required double longitude,
    String? label,
  });

  Future<bool> openFile(String path, {String? mime});

  Future<bool> dial(String number);
}

class InertMediaOpener implements MediaOpener {
  const InertMediaOpener();

  @override
  Future<bool> openMap({
    required double latitude,
    required double longitude,
    String? label,
  }) async =>
      false;

  @override
  Future<bool> openFile(String path, {String? mime}) async => false;

  @override
  Future<bool> dial(String number) async => false;
}
