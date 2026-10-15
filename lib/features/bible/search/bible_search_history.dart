/// **L'historique de recherche** (M3, #201) : les 10 dernières saisies, sur
/// cet appareil seulement (`app_settings`, clé `bible_search_history`, une
/// liste JSON) — il part avec la base à la suppression du compte.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../state/sync_providers.dart';

class BibleSearchHistory {
  BibleSearchHistory(this._db);

  final AppDatabase _db;
  static const String key = 'bible_search_history';
  static const int max = 10;

  Future<List<String>> read() async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    try {
      return [for (final e in jsonDecode(row?.value ?? '[]') as List) '$e'];
    } on Object {
      return const []; // Valeur bricolée : on repart de zéro.
    }
  }

  /// Met [query] en tête (sans doublon, sans casse), garde les [max] premières.
  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return read();
    final list = [
      q,
      for (final e in await read())
        if (e.toLowerCase() != q.toLowerCase()) e,
    ].take(max).toList();
    await _write(list);
    return list;
  }

  Future<void> clear() => _write(const []);

  Future<void> _write(List<String> list) =>
      _db.into(_db.appSettings).insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: key, value: jsonEncode(list)),
          );
}

final bibleSearchHistoryProvider = Provider<BibleSearchHistory>(
  (ref) => BibleSearchHistory(ref.watch(appDatabaseProvider)),
);
