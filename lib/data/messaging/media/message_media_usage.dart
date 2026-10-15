import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../models/message_media.dart';
import '../../local/group_dao.dart';

/// **Ce que les médias de la messagerie occupent sur cet appareil** (T4, #226).
///
/// ## La taille est celle du disque, jamais celle du serveur
///
/// `GroupMessages.mediaSize` est l'octetage **annoncé** par le serveur : il
/// existe pour tout message à média, descendu ou non. L'additionner donnerait
/// un écran qui réclame des mégaoctets que rien n'occupe, et c'est le genre
/// d'écart qui fait qu'on ne croit plus un chiffre. On pèse donc
/// `local_message_media` — les chemins réellement écrits — avec un `stat` par
/// fichier, et un fichier disparu (vidé par le système, purgé à la main) pèse
/// zéro au lieu de mentir.
///
/// ## Le coût, mesuré avant d'être contourné
///
/// Trois mille `statSync` sur cette machine : **98 à 230 ms** dans le fil
/// courant, **472 à 593 ms** en `stat()` asynchrone séquentiel (un aller-retour
/// de boucle d'événements par fichier), **94 à 103 ms** en `Isolate.run` +
/// `statSync`. Le troisième gagne sur les deux axes : le plus court en temps
/// d'horloge, et le seul des deux rapides qui ne bloque pas le fil de
/// l'interface. C'est le patron de `note_pdf_exporter.dart`, et il est repris
/// tel quel, garde `kIsWeb` comprise.
///
/// ponytail: aucun index des tailles en base. Plafond connu : la pesée est
/// **O(fichiers du magasin)** et recommence à chaque ouverture de l'écran. Un
/// téléphone d'entrée de gamme est de l'ordre de cinq fois plus lent que la
/// mesure ci-dessus, soit ~0,5 s pour 3 000 fichiers — derrière un
/// indicateur de chargement, hors du fil de l'interface. Si l'écran devient
/// lent, la suite est une colonne `bytes` écrite au moment du téléchargement,
/// pas un cache de la pesée : le disque peut maigrir dans le dos de l'appli.
class MessageMediaUsage {
  const MessageMediaUsage({required this.conversations, required this.byKind});

  /// Vide : rien n'est descendu sur cet appareil.
  static const empty = MessageMediaUsage(conversations: [], byKind: {});

  /// Une entrée par conversation qui occupe quelque chose, **du plus lourd au
  /// plus léger** — c'est l'ordre que l'écran montre, et le tri est fait ici
  /// pour qu'aucun affichage ne puisse le contredire.
  final List<ConversationMediaUsage> conversations;

  /// Le poids par forme de média, formes vides retirées.
  final Map<MessageMediaKind, int> byKind;

  int get totalBytes {
    var total = 0;
    for (final c in conversations) {
      total += c.bytes;
    }
    return total;
  }

  bool get isEmpty => conversations.isEmpty;
}

/// Ce qu'une conversation occupe, et de quoi la nommer.
class ConversationMediaUsage {
  const ConversationMediaUsage({
    required this.groupId,
    required this.groupName,
    required this.bytes,
    required this.fileCount,
  });

  final String groupId;

  /// Le nom **du groupe**. Pour un tête-à-tête ce n'est pas un nom lisible (le
  /// serveur nomme les DM pour lui-même) : l'écran préfère le titre de la liste
  /// des conversations quand il l'a, et ne retombe ici que pour un groupe qu'on
  /// a quitté — dont les fichiers restent bien sur l'appareil, et doivent donc
  /// rester purgeables.
  final String groupName;

  final int bytes;

  /// Le nombre de **fichiers** pesés, vignettes comprises.
  final int fileCount;
}

/// **Le peseur et le videur du magasin** (T4, #226).
///
/// Une classe et non trois fonctions libres parce que l'écran a besoin d'une
/// couture : la pesée part dans un isolat et la purge touche de vrais fichiers,
/// et **ni l'un ni l'autre n'aboutit dans le corps d'un `testWidgets`**, dont la
/// zone d'`async` est feinte. Le test d'écran remplace donc cet objet ; le test
/// de la pesée, lui, est un `test` nu, où l'entrée-sortie est réelle.
class MessageMediaStorage {
  const MessageMediaStorage(this._dao);

  final GroupDao _dao;

  /// Pèse le magasin et range la réponse : un `stat` par chemin, deux parcours
  /// de la liste, et rien d'autre.
  Future<MessageMediaUsage> weigh() async {
    final rows = await _dao.localMediaFiles();
    if (rows.isEmpty) return MessageMediaUsage.empty;

    final paths = <String>[
      for (final row in rows) ...[
        if (row.path != null) row.path!,
        if (row.thumbPath != null) row.thumbPath!,
      ],
    ];
    final sizes = await _sizesOf(paths);

    final bytesByGroup = <String, int>{};
    final namesByGroup = <String, String>{};
    final filesByGroup = <String, int>{};
    final byKind = <MessageMediaKind, int>{};

    for (final row in rows) {
      namesByGroup[row.groupId] = row.groupName;
      final kind = _kindOf(row);
      for (final path in [row.path, row.thumbPath]) {
        final size = path == null ? null : sizes[path];
        // Un chemin noté mais absent du disque ne pèse rien **et ne compte pas
        // comme un fichier** : la ligne de la conversation dirait sinon
        // « 3 fichiers, 0 o ».
        if (size == null) continue;
        bytesByGroup[row.groupId] = (bytesByGroup[row.groupId] ?? 0) + size;
        filesByGroup[row.groupId] = (filesByGroup[row.groupId] ?? 0) + 1;
        byKind[kind] = (byKind[kind] ?? 0) + size;
      }
    }

    final conversations = [
      for (final entry in bytesByGroup.entries)
        ConversationMediaUsage(
          groupId: entry.key,
          groupName: namesByGroup[entry.key] ?? '',
          bytes: entry.value,
          fileCount: filesByGroup[entry.key] ?? 0,
        ),
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));

    return MessageMediaUsage(conversations: conversations, byKind: byKind);
  }

  /// **Vide les médias d'une conversation** : les fichiers, puis les lignes.
  ///
  /// Dans cet ordre, et il compte. Une ligne sans fichier fait une bulle qui
  /// tente un `File` inexistant ; un fichier sans ligne n'est qu'un octet perdu
  /// que la pesée suivante ne compte même plus. Si l'effacement d'un fichier
  /// échoue (droits, course), la ligne part quand même : la bulle repasse par le
  /// réseau, ce qui est la vérité pour le lecteur.
  Future<void> purgeConversation(String groupId) async {
    await _purge(await _dao.localMediaFiles(groupId: groupId));
  }

  /// **Vide une forme de média**, dans toutes les conversations à la fois : le
  /// geste « je garde les photos, je jette les vidéos ».
  Future<void> purgeKind(MessageMediaKind kind) async {
    final rows = await _dao.localMediaFiles();
    await _purge(rows.where((row) => _kindOf(row) == kind).toList());
  }

  Future<void> _purge(List<LocalMediaFileRow> rows) async {
    for (final row in rows) {
      for (final path in [row.path, row.thumbPath]) {
        if (path == null) continue;
        try {
          await File(path).delete();
        } on FileSystemException {
          // Déjà parti, ou illisible : la ligne part tout de même.
        }
      }
    }
    await _dao.forgetLocalMedia([for (final row in rows) row.messageId]);
  }
}

/// Les tailles des chemins qui existent — **hors du fil de l'interface**.
/// `statSync` est l'appel rapide ; l'isolat est ce qui l'empêche de se voir.
Future<Map<String, int>> _sizesOf(List<String> paths) {
  return kIsWeb
      ? Future.value(_statAll(paths))
      : Isolate.run(() => _statAll(paths));
}

Map<String, int> _statAll(List<String> paths) {
  final sizes = <String, int>{};
  for (final path in paths) {
    final stat = File(path).statSync();
    if (stat.type == FileSystemEntityType.notFound) continue;
    sizes[path] = stat.size;
  }
  return sizes;
}

/// La forme du média, lue **par le modèle** : `MessageMedia.fromColumns` est le
/// seul endroit qui sache qu'un `audio` est un vocal sauf si `meta.voice` dit le
/// contraire, et l'écran doit compter les vocaux à part des pièces audio.
MessageMediaKind _kindOf(LocalMediaFileRow row) =>
    MessageMedia.fromColumns(kind: row.mediaKind, metaJson: row.mediaMeta)
        ?.kind ??
    MessageMediaKind.unknown;
