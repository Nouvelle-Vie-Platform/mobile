/// **Le moteur de synchronisation** : manifeste → tirage → application.
///
/// Il ne rend rien. Il écrit dans le magasin local, qui peint les écrans
/// (ADR-0026, décision 2). Aucun écran ne lit une réponse HTTP de ce chemin.
///
/// Quatre disciplines, et ce sont elles qui font tout l'intérêt du fichier :
///
/// 1. **Référentiels avant contenu** — l'ordre de `syncedCollections()`.
/// 2. **`scope_version` retenue en mémoire, persistée en dernier** (ADR-0027) :
///    une seule valeur pour les treize collections, jamais une par collection,
///    et **rien** n'est persisté si le cycle est interrompu.
/// 3. **Un resync forcé se lit dans un `200`** — `full_resync` sur le tirage,
///    `full_resync_required` sur le manifeste —, et il **remplace** au lieu de
///    détruire puis reconstruire.
/// 4. **Un `404` de collection n'est pas fatal** : la collection est sautée, la
///    synchronisation se poursuit.
/// 5. **La préférence de branche est relue à chaque cycle, et ne part que sur
///    les quatre collections filtrées** (`branch_filter.dart`). Un **422** dit
///    que la branche n'existe pas : on l'oublie, et l'on rejoue le cycle sans
///    filtre — une seule fois. Le nettoyage qui suit un **changement** de
///    préférence n'est pas ici : il vit dans `BranchScopeStore`, parce qu'il doit
///    être fait au moment du geste et non au cycle suivant, et parce que rien
///    côté serveur ne le demandera jamais.
library;

import 'package:flutter/foundation.dart';

import '../local/sync_dao.dart';
import 'sync_api.dart';
import 'sync_protocol.dart';
import 'synced_collection.dart';

/// **Le serveur n'avance pas.** `has_more: true` sur une page qui rend le
/// curseur déjà présenté : la boucle de rattrapage tournerait indéfiniment.
///
/// Lever vaut mieux que boucler : un cycle qui échoue ne persiste rien et se
/// rejoue, un cycle qui tourne en rond vide la batterie sans que personne ne le
/// sache.
class SyncStalled implements Exception {
  const SyncStalled(this.collection, this.cursor);

  final String collection;
  final String? cursor;

  @override
  String toString() => 'SyncStalled: « $collection » redemande le curseur '
      '$cursor en annonçant `has_more`';
}

/// Ce qu'un cycle a fait, une fois terminé. Sert au diagnostic, aux tests, et à
/// l'écran qui affichera un jour « dernière synchronisation ».
@immutable
class SyncReport {
  const SyncReport({
    required this.pulled,
    required this.resynced,
    required this.skipped,
    required this.untouched,
    required this.pages,
    required this.scopeVersion,
  });

  /// Collections ayant appliqué au moins une page en régime delta.
  final List<String> pulled;

  /// Collections entièrement remplacées pendant ce cycle.
  final List<String> resynced;

  /// Collections **sautées** : le serveur a répondu `404`.
  final List<String> skipped;

  /// Collections sans rien à tirer (`has_changes: false`), ou absentes du
  /// manifeste — le registre serveur ne les connaît pas encore.
  final List<String> untouched;

  /// Nombre de pages appliquées, resync compris. C'est ce compteur qui prouve
  /// qu'une pagination a réellement eu lieu.
  final int pages;

  /// Version de périmètre **persistée** à la fin du cycle ; `null` si le
  /// manifeste n'en portait pas.
  final int? scopeVersion;
}

/// La boucle.
class SyncEngine {
  SyncEngine({
    required SyncApi api,
    required SyncDao dao,
    List<SyncedCollection<Object?>>? collections,
    int pageLimit = kSyncPageLimit,
    Future<int?> Function()? branchId,
    Future<void> Function(int branchId)? onUnknownBranch,
  })  : _api = api,
        _dao = dao,
        _collections = collections ?? syncedCollections(),
        _pageLimit = pageLimit,
        _branchId = branchId ?? _noBranchPreference,
        _onUnknownBranch = onUnknownBranch;

  static Future<int?> _noBranchPreference() async => null;

  final SyncApi _api;
  final SyncDao _dao;
  final List<SyncedCollection<Object?>> _collections;
  final int _pageLimit;

  /// **La préférence de branche**, relue à **chaque** cycle.
  ///
  /// Une fonction et non une valeur : la préférence change en cours de vie de
  /// l'application, et un moteur qui l'aurait capturée à la construction
  /// continuerait de filtrer sur l'ancienne — en ayant, lui, bien remis les
  /// curseurs à zéro. Le magasin serait alors reconstruit sur le mauvais
  /// périmètre, et le geste du fidèle resterait sans effet visible jusqu'au
  /// prochain redémarrage.
  final Future<int?> Function() _branchId;

  /// **Le repli du 422** : la branche préférée n'existe pas (ou plus).
  ///
  /// `null` par défaut — le socle ne dépend pas de la préférence de branche, et
  /// sans ce rappel un 422 remonte comme n'importe quelle autre panne.
  final Future<void> Function(int branchId)? _onUnknownBranch;

  /// **Un cycle complet.**
  ///
  /// Toute erreur autre qu'un `404` de collection remonte : un cycle interrompu
  /// ne persiste **rien** de plus que ce que les transactions de page ont déjà
  /// validé — ni la version de périmètre, ni un curseur sans ses lignes — et il
  /// se rejoue au tour suivant depuis le dernier curseur validé.
  Future<SyncReport> synchronize() async {
    final branchId = await _branchId();
    try {
      return await _cycle(branchId);
    } on UnknownSyncBranch catch (refusal) {
      // Le serveur ne connaît pas cette branche. S'obstiner ferait échouer
      // **tous** les cycles à venir, donc toutes les collections : on oublie la
      // préférence — ce qui remet au passage les quatre curseurs à zéro, la
      // branche change bien — puis on rejoue le cycle **sans filtre**.
      //
      // Un seul rattrapage, et la borne est structurelle : le second cycle part
      // avec `null`, et `SyncApi` ne lève `UnknownSyncBranch` que s'il a envoyé
      // un `branch_id`. Il n'y a donc pas de boucle possible.
      final recover = _onUnknownBranch;
      if (recover == null) rethrow;
      await recover(refusal.branchId);
      return _cycle(null);
    }
  }

  Future<SyncReport> _cycle(int? branchId) async {
    final manifest = await _api.manifest(
      cursors: await _dao.allCursors(),
      scopeVersion: await _dao.readScopeVersion(),
      branchId: branchId,
    );

    // **Retenue en mémoire**, et nulle part ailleurs, pendant tout le cycle
    // (ADR-0027). Une seule valeur pour les treize collections : la persister
    // après la première collection éteindrait un resync que les suivantes n'ont
    // pas encore fait, et le manifeste ne le redemanderait **jamais** — il
    // recevrait une version à jour.
    final retained = manifest.scopeVersion;

    final report = _ReportBuilder();
    for (final collection in _collections) {
      await _syncCollection(
        collection,
        manifest.entryFor(collection.key),
        report,
        // **Quatre collections, et seulement elles.** Le filtre suit le
        // descripteur, jamais une condition écrite ici : `events` et le mur de
        // prière ne sont pas des collections répliquées, et les huit autres du
        // registre ne relèvent d'aucune branche. Voir `branch_filter.dart`.
        collection.branchScoped ? branchId : null,
      );
    }

    // … et persistée **en dernier**, une fois que chaque collection marquée a
    // remplacé et re-tiré jusqu'à `has_more: false`.
    if (retained != null) {
      await _dao.writeScopeVersion(retained);
      report.scopeVersion = retained;
    }

    return report.build();
  }

  Future<void> _syncCollection(
    SyncedCollection<Object?> collection,
    ManifestEntry? entry,
    _ReportBuilder report,
    int? branchId,
  ) async {
    try {
      // Un jeton survivant dit qu'un remplacement a été interrompu : le cycle
      // recommence entièrement, que le manifeste le redemande ou non. Il le
      // redemandera de toute façon — la version de périmètre n'a pas été
      // persistée —, mais le magasin n'a pas à en dépendre.
      final interrupted = await _dao.resyncToken(collection.key) != null;

      if (entry?.fullResyncRequired == true || interrupted) {
        await _resync(collection, report, branchId);
        return;
      }

      // Rien à tirer : on ne touche à rien. En particulier **pas** au
      // `current_cursor` du manifeste, qui est la borne haute du périmètre et
      // non un accusé de réception — l'adopter ferait avancer un curseur sans
      // les lignes qu'il couvre, ce que l'invariant central interdit.
      if (entry == null || !entry.hasChanges) {
        report.untouched.add(collection.key);
        return;
      }

      await _delta(collection, report, branchId);
    } on UnknownSyncCollection {
      // Le serveur ne connaît pas cette clé : une collection sautée, pas une
      // synchronisation échouée.
      report.skipped.add(collection.key);
    }
  }

  /// **Régime delta** : rejouer le curseur persisté, page après page, tant que
  /// `has_more` est vrai.
  Future<void> _delta(
    SyncedCollection<Object?> collection,
    _ReportBuilder report,
    int? branchId,
  ) async {
    var cursor = await _dao.cursorFor(collection.key);
    var pulled = false;

    while (true) {
      final page = await _api.pull(
        collection.key,
        since: cursor,
        limit: _pageLimit,
        branchId: branchId,
      );

      // Le resync forcé arrive **dans un 200**, avec `items` vide et
      // `has_more` faux : il ressemble trait pour trait à « rien de neuf ».
      // Lire `items` seul, c'est garder pour toujours un cache dont on a raté
      // des suppressions.
      if (page.fullResync) {
        await _resync(collection, report, branchId);
        return;
      }

      await collection.applyPage(_dao, page);
      report.pages++;
      pulled = true;

      if (!page.hasMore) break;
      if (page.nextCursor == cursor) {
        throw SyncStalled(collection.key, cursor);
      }
      cursor = page.nextCursor;
    }

    if (pulled) report.pulled.add(collection.key);
  }

  /// **Remplacement complet — jamais une destruction suivie d'une
  /// reconstruction.**
  ///
  /// Vider est une transaction, re-tirer en est N. Entre les deux, le magasin
  /// — qui peint les écrans — serait partiellement vide : une coupure après la
  /// purge laisserait un fidèle **sans son catalogue et sans rien reçu**, alors
  /// qu'il était hors ligne avec ses enseignements trente secondes plus tôt.
  ///
  /// D'où les trois temps d'ADR-0026 : poser un jeton, re-tirer depuis zéro
  /// sans rien effacer, puis balayer en une transaction finale ce que le cycle
  /// n'a pas revu. Le résultat observable est celui d'une purge ; le chemin,
  /// non.
  Future<void> _resync(
    SyncedCollection<Object?> collection,
    _ReportBuilder report,
    int? branchId,
  ) async {
    // **Depuis zéro** : le curseur persisté n'est pas rejoué. Il n'est pas
    // effacé non plus — c'est la transaction finale qui le remplace, et une
    // coupure d'ici là doit laisser le magasin exactement où il était.
    String? cursor;
    var page = await _api.pull(
      collection.key,
      limit: _pageLimit,
      branchId: branchId,
    );

    // Le jeton n'est posé qu'**après** la première réponse, et avant la
    // première écriture : un `404` ne doit pas laisser derrière lui un cycle
    // ouvert que plus rien ne refermerait, et une ligne écrite avant le jeton
    // porterait un cachet antérieur — le balayage final la supprimerait.
    await _dao.beginResync(collection.key);

    while (true) {
      // `full_resync` est ignoré ici : on est déjà en train d'en faire un. Le
      // relire ferait recommencer le cycle à chaque page — indéfiniment.
      await collection.applyResyncPage(_dao, page);
      report.pages++;

      if (!page.hasMore) {
        cursor = page.nextCursor;
        break;
      }
      if (page.nextCursor == cursor) {
        throw SyncStalled(collection.key, cursor);
      }
      cursor = page.nextCursor;
      page = await _api.pull(
        collection.key,
        since: cursor,
        limit: _pageLimit,
        branchId: branchId,
      );
    }

    await collection.finishResync(_dao, cursor: cursor);
    report.resynced.add(collection.key);
  }
}

class _ReportBuilder {
  final List<String> pulled = [];
  final List<String> resynced = [];
  final List<String> skipped = [];
  final List<String> untouched = [];
  int pages = 0;
  int? scopeVersion;

  SyncReport build() => SyncReport(
        pulled: List.unmodifiable(pulled),
        resynced: List.unmodifiable(resynced),
        skipped: List.unmodifiable(skipped),
        untouched: List.unmodifiable(untouched),
        pages: pages,
        scopeVersion: scopeVersion,
      );
}
