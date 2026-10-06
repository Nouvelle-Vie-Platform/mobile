import 'dart:convert';

import 'package:drift/drift.dart';

/// Une **liste d'identifiants** dans une colonne texte, en tableau JSON — la
/// sélection `manual_ids` et le classement `ranked_ids` d'une section de
/// médiathèque (M4, #167).
///
/// Lecture **tolérante**, comme `WaveformConverter` : un JSON corrompu se lit
/// « liste vide », jamais une exception qui ferait échouer la requête qui peint
/// toute la médiathèque.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      return decode(jsonDecode(fromDb)) ?? const [];
    } on FormatException {
      return const [];
    }
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);

  /// Partagée avec `sync_rows.dart` : `null` quand la valeur n'est pas une
  /// liste (« pas de sélection », « jamais classé »), sinon ses identifiants.
  /// Un nombre est rendu en chaîne — le serveur sert des UUID, mais un `jsonb`
  /// ne promet pas la forme de ce qu'on y a rangé à la main.
  static List<String>? decode(Object? raw) {
    if (raw is! List) return null;
    return List<String>.unmodifiable([
      for (final entry in raw)
        if (entry is String) entry else if (entry is num) entry.toString(),
    ]);
  }
}
