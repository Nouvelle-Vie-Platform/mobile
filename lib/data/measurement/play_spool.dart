/// **La file des écoutes qui n'ont pas pu partir.**
///
/// Le serveur ne saura **jamais** qu'une écoute a eu lieu si l'application ne
/// peut pas le lui dire. Deux conduites étaient possibles, et celle-ci est un
/// choix, pas une évidence :
///
/// - **abandonner** l'événement. Coût : toute écoute hors ligne est invisible.
///   Ce n'est pas un cas marginal dans cette application — le téléchargement
///   existe (`lib/data/downloads/`), il est fait *pour* écouter sans réseau, et
///   la population qui télécharge est celle dont le réseau est le plus mauvais.
///   La mesure serait alors biaisée contre exactement les fidèles qu'elle est
///   censée décrire ;
/// - **classer** l'événement et le remettre au prochain passage. Coût : une
///   écoute classée est remontée **le jour où elle repart**, pas le jour où
///   elle a eu lieu. Le serveur déduplique « au plus une par porteur, par
///   contenu et par jour » et ne prend **aucun horodatage** du client : une
///   écoute de mardi remise en ligne jeudi compte pour jeudi.
///
/// C'est la seconde qui est retenue, parce que la question à laquelle cette
/// mesure sert à répondre est « **combien de fidèles ont écouté ce prêche** »
/// bien avant « quel jour ». La courbe journalière est donc légèrement fausse,
/// et elle l'est **toujours dans le même sens** : elle retarde, elle n'invente
/// rien.
///
/// Deux bornes tiennent le mensonge :
///
/// - [kPlaySpoolMaxAge] — passé ce délai, l'événement est **jeté** plutôt que
///   remonté. Au-delà d'une semaine, imputer une écoute au jour du renvoi
///   n'apprendrait plus rien à personne ;
/// - [kPlaySpoolCapacity] — la file ne grandit pas indéfiniment. Un appareil
///   hors ligne trois mois ne doit pas garder trois mois d'événements dans une
///   table de réglages.
///
/// **Où ça se range.** Dans `app_settings`, la table clé/valeur, sous une seule
/// clé. Pas dans une table Drift dédiée, et ce n'est pas de la paresse : une
/// table neuve coûte un `schemaVersion`, une migration et un
/// `drift_schemas/` — pour une liste d'au plus [kPlaySpoolCapacity]
/// identifiants qui n'est jamais interrogée autrement qu'en entier. La table
/// clé/valeur existe précisément pour ce genre d'état (CLAUDE.md, « aucune
/// migration : la table est clé/valeur, c'est pour cela qu'elle l'est »).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local/settings_dao.dart';
import 'play_reporter.dart';

/// Au-delà de cet âge, une écoute classée est **jetée** au lieu d'être remontée.
///
/// ⚠️ **Valeur à confirmer**, comme `kPlaybackCompletionSlack` : le produit n'a
/// pas encore dit combien de retard il accepte sur sa courbe journalière.
const Duration kPlaySpoolMaxAge = Duration(days: 7);

/// Nombre maximal d'écoutes en attente. Au-delà, **les plus anciennes
/// tombent** : entre perdre l'ancienne et perdre la nouvelle, la nouvelle est
/// celle dont la date de remontée sera la moins fausse.
const int kPlaySpoolCapacity = 50;

/// Une écoute qui attend son tour : le contenu, et **quand** elle a eu lieu.
///
/// La date ne part jamais au serveur — il ne l'accepte pas. Elle ne sert qu'à
/// [kPlaySpoolMaxAge], c'est-à-dire à décider de **ne pas** mentir trop
/// longtemps.
@immutable
class PendingPlay {
  const PendingPlay({required this.contentId, required this.at});

  final String contentId;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'id': contentId,
        'at': at.toUtc().toIso8601String(),
      };

  /// Lecture **tolérante** : une entrée illisible est ignorée, jamais une
  /// exception. Une file corrompue ne doit pas empêcher d'écouter un prêche.
  static PendingPlay? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final at = DateTime.tryParse('${raw['at']}');
    if (id is! String || id.isEmpty || at == null) return null;
    return PendingPlay(contentId: id, at: at);
  }
}

/// **La file d'attente**, derrière une abstraction : les tests la doublent sans
/// base de données, et `PlayTracker` ne sait pas où elle vit.
abstract interface class PlaySpool {
  /// Classe une écoute qui n'a pas pu partir. Ne lève **jamais**.
  Future<void> add(String contentId, {DateTime? at});

  /// Tente de remonter tout ce qui attend. Rend le nombre d'écoutes
  /// effectivement parties. Ne lève **jamais**.
  Future<int> drain(PlayReporter reporter, {DateTime? now});

  /// Ce qui attend, pour le diagnostic et les tests.
  Future<List<PendingPlay>> pending();
}

/// File d'attente rangée dans `app_settings`.
class SettingsPlaySpool implements PlaySpool {
  SettingsPlaySpool(this._settings, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SettingsDao _settings;

  /// L'horloge, **injectable** : sans elle, [kPlaySpoolMaxAge] serait
  /// intestable autrement qu'en attendant une semaine.
  final DateTime Function() _clock;

  @override
  Future<void> add(String contentId, {DateTime? at}) async {
    try {
      final now = at ?? _clock();
      final kept = [
        // Une écoute déjà en attente pour ce contenu ne s'ajoute pas deux
        // fois : le serveur la dédupliquerait de toute façon, mais deux entrées
        // c'est deux requêtes au drainage, donc deux réveils de radio.
        ...(await _read(now)).where((play) => play.contentId != contentId),
        PendingPlay(contentId: contentId, at: now),
      ];
      await _write(kept);
    } catch (error) {
      // La télémétrie n'a le droit de casser rien, y compris quand c'est sa
      // propre file qui refuse d'être écrite.
      debugPrint('[mesure] écoute non classée pour $contentId : $error');
    }
  }

  @override
  Future<int> drain(PlayReporter reporter, {DateTime? now}) async {
    try {
      final at = now ?? _clock();
      final waiting = await _read(at);
      if (waiting.isEmpty) return 0;

      var delivered = 0;
      while (delivered < waiting.length) {
        if (!await reporter.report(waiting[delivered].contentId)) {
          // **Premier échec : on s'arrête.** On ne s'acharne pas sur les
          // suivantes — si la radio ne répond pas pour une écoute, elle ne
          // répondra pas mieux pour la dixième, et cinquante requêtes perdues
          // coûtent une batterie. Ce qui reste garde sa place dans la file.
          break;
        }
        delivered++;
      }
      await _write(waiting.sublist(delivered));
      return delivered;
    } catch (error) {
      debugPrint('[mesure] drainage abandonné : $error');
      return 0;
    }
  }

  @override
  Future<List<PendingPlay>> pending() async {
    try {
      return await _read(_clock());
    } catch (_) {
      return const [];
    }
  }

  /// Lit la file, **déjà purgée de ce qui est trop vieux**. La purge se fait à
  /// la lecture et non par un balayage périodique : il n'y a aucun `Timer` dans
  /// cette couche, pour la même raison qu'il n'y en a aucun dans
  /// `lib/data/sync/`.
  Future<List<PendingPlay>> _read(DateTime now) async {
    final raw = await _settings.pendingPlays();
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final horizon = now.subtract(kPlaySpoolMaxAge);
    final kept = <PendingPlay>[];
    for (final entry in decoded) {
      final play = PendingPlay.fromJson(entry);
      if (play == null) continue;
      if (!play.at.isAfter(horizon)) continue;
      kept.add(play);
    }
    return kept;
  }

  Future<void> _write(List<PendingPlay> plays) {
    // Le plafond coupe **par la tête** : ce qui tombe est le plus ancien, donc
    // celui dont la date de remontée serait déjà la plus fausse.
    final kept = plays.length <= kPlaySpoolCapacity
        ? plays
        : plays.sublist(plays.length - kPlaySpoolCapacity);
    return _settings.setPendingPlays(
      jsonEncode([for (final play in kept) play.toJson()]),
    );
  }
}
