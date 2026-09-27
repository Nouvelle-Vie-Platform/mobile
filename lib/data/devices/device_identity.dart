import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Clé de stockage sécurisé de l'identifiant d'appareil.
///
/// Il vit dans le **coffre**, à côté du jeton, et non dans la base locale : il
/// ne peut pas se re-télécharger (le serveur ne sait pas le rendre), et c'est la
/// règle du dépôt — « le coffre contient ce qu'on ne peut pas re-télécharger »
/// (`docs/auth-contract.md`, « Stockage local »).
const String kDeviceIdKey = 'device_id';

/// Longueur en dessous de laquelle un identifiant rangé n'est plus tenu pour
/// valable et se régénère.
///
/// Le serveur refuse un `deviceId` trop court en **422**. Le garde-fou est donc
/// local et **jamais déclenché par une réponse du serveur** : un 422 ne fait pas
/// naître un nouvel identifiant, sinon chaque refus créerait un appareil de plus
/// dans le compteur d'en face. Il ne couvre que le coffre abîmé (valeur vidée,
/// tronquée par une restauration).
const int kMinDeviceIdLength = 16;

/// L'identité de **l'appareil** — pas celle d'une session.
///
/// Un UUID généré à la première ouverture et conservé dans le coffre. Il
/// **survit à une déconnexion** : c'est ce qui permet de reprendre un jeton
/// d'appareil pour le *même* appareil, sans en créer un second côté serveur.
///
/// ⚠️ **Cet identifiant est falsifiable.** Il est fabriqué et rangé par le
/// téléphone : n'importe qui peut en présenter un autre, ou le même mille fois.
/// Il ne sert donc qu'à **compter** les appareils et à en **révoquer** un côté
/// serveur — jamais à autoriser quoi que ce soit. C'est le raisonnement du
/// serveur (ADR-0040), et il doit survivre de ce côté-ci aussi : le jour où une
/// permission se déciderait sur sa valeur, il suffirait de la recopier.
class DeviceIdentity {
  DeviceIdentity({FlutterSecureStorage? storage, String Function()? mintId})
      : _storage = storage ?? const FlutterSecureStorage(),
        _mint = mintId ?? _mintUuidV4;

  final FlutterSecureStorage _storage;

  /// Fabrique d'identifiant, paramétrable **pour les tests seulement**.
  final String Function() _mint;

  /// Résolution en vol : deux appels concurrents à la première ouverture ne
  /// doivent pas fabriquer deux identifiants dont un seul serait rangé.
  Future<String>? _pending;

  /// L'identifiant de cet appareil : lu du coffre, ou généré et rangé si c'est
  /// la première ouverture.
  Future<String> current() {
    final pending = _pending;
    if (pending != null) return pending;
    final started = _resolve();
    _pending = started;
    // Un succès se mémorise — l'identifiant ne change pas en cours
    // d'exécution —, un échec **jamais** : un coffre momentanément illisible ne
    // doit pas condamner l'appareil à n'avoir plus d'identité.
    return started.onError<Object>((error, stack) {
      if (identical(_pending, started)) _pending = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<String> _resolve() async {
    final stored = await _storage.read(key: kDeviceIdKey);
    if (stored != null && stored.trim().length >= kMinDeviceIdLength) {
      return stored;
    }
    // Première ouverture. **UUID v4**, et non v7 comme les identifiants de
    // progression : un v7 porte l'instant de sa fabrique, c'est-à-dire la date
    // d'installation, dans une valeur que le serveur conserve pour compter.
    final minted = _mint();
    await _storage.write(key: kDeviceIdKey, value: minted);
    return minted;
  }

  static String _mintUuidV4() => const Uuid().v4();
}
