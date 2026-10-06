import 'package:file_picker/file_picker.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/message_media.dart';
import 'chat_media_picker.dart';
import 'media_mime.dart';

/// **Les implémentations de l'appareil** (M4, #143) — le seul fichier qui
/// importe les greffons des pièces jointes.
///
/// | geste | greffon | permission |
/// |---|---|---|
/// | photo, vidéo | `image_picker` (déjà là) | appareil photo : par le système |
/// | document, fichier audio | `file_picker` | aucune (sélecteur du système) |
/// | position | `geolocator` | `ACCESS_FINE_LOCATION`, demandée au geste |
/// | contact | `flutter_native_contact_picker` | **aucune** (sélecteur du système) |
/// | ouvrir une carte | `url_launcher` | — |
/// | ouvrir un document | `open_file` | — |
///
/// Tous sont des **Swift Packages** (CocoaPods ne ressuscite pas).
class DeviceChatMediaPicker implements ChatMediaPicker {
  DeviceChatMediaPicker({
    ImagePicker? images,
    FlutterNativeContactPicker? contacts,
  })  : _images = images ?? ImagePicker(),
        _contacts = contacts ?? FlutterNativeContactPicker();

  final ImagePicker _images;
  final FlutterNativeContactPicker _contacts;

  /// La vidéo prise sur place est bornée à la source : inutile de filmer
  /// dix minutes pour se les voir refuser (le plafond servi est 3 min par
  /// défaut ; le composeur revérifie la durée réelle).
  static const Duration _maxCapture = Duration(minutes: 3);

  @override
  Future<String?> takePhoto() async =>
      (await _images.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<String?> pickPhoto() async =>
      (await _images.pickImage(source: ImageSource.gallery))?.path;

  @override
  Future<String?> recordVideo() async => (await _images.pickVideo(
        source: ImageSource.camera,
        maxDuration: _maxCapture,
      ))
          ?.path;

  @override
  Future<String?> pickVideo() async =>
      (await _images.pickVideo(source: ImageSource.gallery))?.path;

  @override
  Future<PickedFile?> pickDocument() => _pickFile(
        type: FileType.custom,
        extensions: kDocumentMimeByExtension.keys.toList(),
      );

  @override
  Future<PickedFile?> pickAudioFile() => _pickFile(
        type: FileType.custom,
        extensions: kAudioFileMimeByExtension.keys.toList(),
      );

  Future<PickedFile?> _pickFile({
    required FileType type,
    required List<String> extensions,
  }) async {
    try {
      final file = await FilePicker.pickFile(
        type: type,
        allowedExtensions: extensions,
      );
      final path = file?.path;
      if (file == null || path == null) return null;
      return PickedFile(path: path, name: file.name, sizeBytes: file.size);
    } on Object {
      return null;
    }
  }

  @override
  Future<LocationOutcome?> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(serviceDisabled: true);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationUnavailable(serviceDisabled: false);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFound(position.latitude, position.longitude);
    } on Object {
      return const LocationUnavailable(serviceDisabled: false);
    }
  }

  @override
  Future<PickedContact?> pickContact() async {
    try {
      final contact = await _contacts.selectContact();
      if (contact == null) return null;
      final phones = [
        for (final number in contact.phoneNumbers ?? const <String>[])
          if (number.trim().isNotEmpty) ContactPhone(number: number.trim()),
      ];
      final name = contact.fullName?.trim();
      if (phones.isEmpty) return null;
      return PickedContact(
        name: name == null || name.isEmpty ? phones.first.number : name,
        // Le serveur en accepte dix ; au-delà, c'est un annuaire.
        phones: phones.take(10).toList(),
      );
    } on Object {
      return null;
    }
  }
}

/// Ouvrir hors de l'application.
class DeviceMediaOpener implements MediaOpener {
  const DeviceMediaOpener();

  /// **Aucune clé d'API** : l'application de cartes du téléphone est ouverte
  /// sur les coordonnées (`geo:` sur Android, Plans sur iOS), et le site
  /// d'OpenStreetMap en repli. Pas de carte statique servie par un tiers
  /// payant.
  @override
  Future<bool> openMap({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final coords = '$latitude,$longitude';
    final query = label == null || label.isEmpty
        ? coords
        : '$coords(${Uri.encodeComponent(label)})';
    final candidates = [
      Uri.parse('geo:$coords?q=$query'),
      Uri.parse('https://maps.apple.com/?ll=$coords&q=$coords'),
      Uri.parse(
        'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude'
        '#map=17/$latitude/$longitude',
      ),
    ];
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } on Object {
        // Schéma non pris en charge : le suivant.
      }
    }
    return false;
  }

  @override
  Future<bool> openFile(String path, {String? mime}) async {
    try {
      final result = await OpenFile.open(path, type: mime);
      return result.type == ResultType.done;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> dial(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } on Object {
      return false;
    }
  }
}
