import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// **L'espace disque libre**, derrière une abstraction — pour la même raison que
/// tout le reste : le pré-check d'espace (F9) doit se vérifier sur la VM Dart,
/// et les tests posent un [FixedDiskSpace].
///
/// Le contrat est délibérément lâche : [freeBytes] rend `null` quand la valeur
/// est **inconnue**. Le manager traite l'inconnu en **fail-open** — il laisse
/// passer plutôt que de bloquer un téléchargement sur une plateforme qu'on ne
/// sait pas mesurer. Un pré-check qui bloque à tort est pire qu'un pré-check
/// absent : le disque plein se rattrape en cours (échec disque → `failed` +
/// partiel conservé), une donnée manquante ne doit pas condamner la fonction.
///
/// ⚠️ `null` et `0` ne veulent **pas** dire la même chose : `0` est une mesure
/// — « le disque est plein », et le pré-check bloque ; `null` est l'absence de
/// mesure, et il laisse passer. Rendre `0` faute de savoir condamnerait toute
/// la fonction.
abstract interface class DiskSpace {
  /// Les octets libres à l'endroit où les téléchargements sont stockés, ou
  /// `null` si la plateforme ne le dit pas.
  Future<int?> freeBytes();
}

/// Le canal natif de la mesure.
///
/// Même motif que `playback_notifications.dart` — aucune dépendance ajoutée
/// pour si peu : `dart:io` n'expose pas la place libre, un canal de méthode
/// suffit, et il ne coûte rien aux plateformes qui ne le branchent pas.
const MethodChannel _channel = MethodChannel(
  'com.maisondumiracle.maison_du_miracle/disk_space',
);

/// L'implémentation réelle — best-effort, par canal natif.
///
/// Les deux côtés mesurent **le volume où l'application écrit**, et non « le
/// disque » : les enseignements descendent dans les documents applicatifs, les
/// médias de la messagerie dans le support applicatif, et les deux sont sur le
/// même système de fichiers (le bac à sable de l'application) — une seule
/// mesure les couvre donc tous les deux.
///
/// - **Android** : `StatFs(filesDir).availableBytes` ;
/// - **iOS** : `volumeAvailableCapacityForImportantUsageKey`. **Pas**
///   `systemFreeSize`, qui sur APFS annonce du « purgeable » que l'application
///   n'obtiendra jamais : un pré-check qui laisse passer en croyant mesurer est
///   pire que celui qui ne se prononce pas, parce qu'il a l'air de marcher.
///
/// **Toute plateforme sans gestionnaire rend `null`** sans qu'on ait à la
/// nommer : l'absence de canal lève `MissingPluginException`, rattrapée ici.
/// C'est le cas du web, du bureau et du harnais de test — et c'est aussi
/// pourquoi aucun `defaultTargetPlatform` n'est testé : le jour où une
/// plateforme branchera le canal, elle marchera sans qu'on touche à ce fichier.
class BestEffortDiskSpace implements DiskSpace {
  const BestEffortDiskSpace();

  @override
  Future<int?> freeBytes() async {
    try {
      final free = await _channel.invokeMethod<Object?>('freeBytes');
      // Ni un entier, ou négatif ⇒ le natif s'est trompé, pas le disque :
      // inconnu, surtout pas plein.
      if (free is! int || free < 0) return null;
      return free;
    } on MissingPluginException {
      return null; // pas de canal sur cette plateforme : inconnu.
    } on PlatformException catch (error) {
      debugPrint('Espace disque non mesurable: $error');
      return null;
    }
  }
}

/// Espace **figé**, pour les tests : le pré-check se prouve sans disque réel.
class FixedDiskSpace implements DiskSpace {
  const FixedDiskSpace(this.free);

  /// Octets libres à annoncer, ou `null` pour simuler l'inconnu.
  final int? free;

  @override
  Future<int?> freeBytes() async => free;
}
