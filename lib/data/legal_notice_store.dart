import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'local/app_database.dart';

/// **La mémoire de la mention légale du premier lancement**, derrière une
/// abstraction.
///
/// Même motif qu'`AppVersionReader` (`lib/data/app_version.dart`) et
/// `StatusImagePicker` : le widget ne connaît que ce contrat, et les tests
/// d'écran injectent un double qui ne touche ni la base ni le disque.
///
/// ## Pourquoi cette mémoire existe
///
/// Le bandeau n'est pas une décoration, et **ne doit pas être retiré par
/// quelqu'un qui le prendrait pour telle** : depuis le mode invité,
/// l'application attribue un **identifiant d'appareil** dès la première
/// ouverture (`lib/data/devices/`) et l'envoie au serveur. C'est une donnée
/// personnelle, posée avant tout compte — donc avant la barrière de
/// consentement des membres (`/legal/accept`, #56), qui est le seul endroit où
/// un accord explicite est recueilli et tracé. Un invité ne la voit jamais. Le
/// bandeau est ce qui annonce l'identifiant à ceux-là, et les liens qu'il porte
/// sont ce qui rend l'annonce vérifiable.
///
/// ## Pourquoi une seule fois, et localement
///
/// Une mention qui revient à chaque ouverture cesse d'être lue au troisième
/// lancement, et la fermer deviendrait un réflexe — ce qui vaut exactement zéro.
/// Et la mémoire est **locale** : elle décrit *cet appareil-ci*, qui est
/// justement ce dont le bandeau parle. Le serveur ne la sert pas, ne la reçoit
/// pas, et n'a rien à en savoir — la même raison que les réglages média
/// (`lib/data/local/tables/settings_tables.dart`).
abstract interface class LegalNoticeStore {
  /// Le bandeau a-t-il déjà été fermé sur cet appareil ?
  ///
  /// **Un échec de lecture rend `true`**, jamais une exception : la lecture est
  /// locale, et un magasin illisible ne doit pas empêcher l'accueil de
  /// s'afficher. Le prix de ce choix est un bandeau manqué ; celui de l'autre
  /// serait un écran mort au premier lancement.
  Future<bool> seen();

  /// Le bandeau vient d'être fermé : qu'il ne revienne plus.
  ///
  /// **Ne lève jamais.** Une écriture perdue ne coûte qu'un bandeau de trop au
  /// lancement suivant ; une exception remontée jusqu'au `onPressed` d'un
  /// bouton de fermeture coûterait un écran rouge.
  Future<void> markSeen();
}

/// Implémentation réelle : la table clé/valeur `app_settings` du magasin local.
///
/// **Pas de `shared_preferences`**, et pour la raison écrite dans l'en-tête de
/// `settings_tables.dart` : un second magasin ferait vivre ce drapeau **hors**
/// du fichier de base, que la suppression de compte vide — il faudrait alors se
/// souvenir d'un second effacement, et personne ne s'en souviendrait.
///
/// **Dette assumée** : sa place naturelle est une paire de méthodes dans
/// `SettingsDao`, comme les trois réglages d'apparence. Elle est écrite ici
/// parce que `lib/data/local/` appartient à une branche parallèle au moment où
/// ceci est livré ; la déplacer est un refactor mécanique, et la **clé** est ce
/// qui doit survivre au déplacement.
class SettingsLegalNoticeStore implements LegalNoticeStore {
  const SettingsLegalNoticeStore(this._db);

  final AppDatabase _db;

  /// La clé est **stable** : la renommer ramènerait le bandeau sur tous les
  /// appareils déjà installés, ce qui est exactement ce que ce drapeau existe
  /// pour éviter.
  static const String key = 'legal_notice_seen';

  @override
  Future<bool> seen() async {
    try {
      final row = await (_db.select(_db.appSettings)
            ..where((setting) => setting.key.equals(key)))
          .getSingleOrNull();
      // **Tolérante, comme toute lecture de cette table** : seule `'true'` vaut
      // « déjà vu ». Une valeur inconnue (base bricolée, version antérieure)
      // retombe sur « pas encore », c'est-à-dire du côté qui informe.
      return row?.value == 'true';
    } on Object catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await _db.into(_db.appSettings).insert(
            AppSettingsCompanion.insert(key: key, value: 'true'),
            mode: InsertMode.insertOrReplace,
          );
    } on Object catch (_) {
      // Rien à dire à personne : au pire le bandeau reparaît une fois.
    }
  }
}

/// Mémoire **en mémoire** : le double des tests, et rien d'autre.
///
/// Exposée en production plutôt que définie dans `test/`, pour la raison
/// d'`InertStatusImagePicker` et de `FixedAppVersionReader` : un double qui vit
/// à côté de son contrat se met à jour avec lui.
@visibleForTesting
class InMemoryLegalNoticeStore implements LegalNoticeStore {
  InMemoryLegalNoticeStore({bool seen = false}) : _seen = seen;

  bool _seen;

  /// Ce que le double a retenu — relu par les tests, pour prouver que la
  /// fermeture s'écrit et ne se contente pas de masquer le bandeau.
  bool get remembered => _seen;

  @override
  Future<bool> seen() async => _seen;

  @override
  Future<void> markSeen() async => _seen = true;
}
