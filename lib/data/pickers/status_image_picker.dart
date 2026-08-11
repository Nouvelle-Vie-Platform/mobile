import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/announcement_draft.dart';

/// **Choisir l'image de fond d'une annonce**, derrière une abstraction.
///
/// Même motif que `StatusPlayer` : l'écran ne connaît que ce contrat, et les
/// tests injectent une implémentation inerte. Sans lui, monter le composeur en
/// test ouvrirait la photothèque de la machine — ou, plus probablement, lèverait
/// une `MissingPluginException` que personne ne saurait relier au formulaire.
///
/// Rend `null` quand l'auteur annule. Ce n'est pas une erreur : refermer le
/// sélecteur sans rien choisir est le geste le plus fréquent, et il ne doit rien
/// changer à l'état du formulaire.
abstract interface class StatusImagePicker {
  Future<StatusImageUpload?> pick();
}

/// Implémentation réelle : la **photothèque** de l'appareil.
///
/// Pas d'appareil photo. Une annonce d'église est une affiche préparée — un
/// visuel fait au portail, reçu par messagerie, enregistré dans la pellicule —
/// jamais une photo prise dans l'instant. Offrir les deux entrées demanderait un
/// choix de plus à chaque dépôt, pour un chemin que personne n'emprunterait, et
/// une permission caméra à justifier sur deux magasins d'applications.
///
/// Les octets sont lus **tout de suite** plutôt que le chemin conservé : le web
/// n'expose pas de système de fichiers, et l'écriture exige de toute façon le
/// réseau (ADR-0031) — cette image ne survit jamais à l'écran qui l'a choisie.
///
/// [_maxWidth] borne la plus grande dimension : un statut s'affiche en plein
/// écran sur un téléphone, et déposer 12 mégapixels depuis une connexion
/// togolaise ferait échouer l'envoi bien avant d'améliorer quoi que ce soit.
class GalleryStatusImagePicker implements StatusImagePicker {
  GalleryStatusImagePicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxWidth = 1440;

  @override
  Future<StatusImageUpload?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxWidth,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return StatusImageUpload(
      bytes: bytes,
      // Le serveur dérive le type du contenu, mais le nom porte l'extension
      // qu'attend son validateur (`vine.file({ extnames })`). Un nom vide
      // ferait refuser une image parfaitement valide.
      filename: file.name.isEmpty ? 'annonce.jpg' : file.name,
    );
  }
}

/// Sélecteur **inerte** : n'ouvre rien et rend toujours `null`.
///
/// C'est le double des tests d'écran, et le seul moyen de monter le composeur
/// sans plugin. Exposé en production (plutôt que défini dans `test/`) pour la
/// même raison qu'`InertStatusPlayer` : un double qui vit à côté de son contrat
/// se met à jour avec lui.
@visibleForTesting
class InertStatusImagePicker implements StatusImagePicker {
  const InertStatusImagePicker();

  @override
  Future<StatusImageUpload?> pick() async => null;
}
