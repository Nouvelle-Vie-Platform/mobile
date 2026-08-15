import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/teaching_download.dart';

/// Stocke le **contrat de téléchargement brut** d'un enseignement
/// (`teachings.download`) dans une colonne texte, tel que le serveur l'envoie :
/// `{ version, duration, renditions: { low:{url,bytes}, mid:…, high:… } }`
/// (ADR-0038).
///
/// **On stocke ce que le serveur envoie** (ADR-0026, décision 3) : l'objet
/// entier, la carte `renditions` complète, jamais la seule qualité choisie — le
/// réglage « Téléchargement » se change, et figer une qualité à l'écriture
/// rendrait un changement de réglage sans effet sur le catalogue déjà reçu.
///
/// La lecture est **tolérante** : un JSON corrompu ou une forme inattendue rend
/// un objet vide (version vide, durée nulle, aucune rendition) plutôt qu'une
/// exception. Un `download` illisible se lit alors « pas téléchargeable », ce qui
/// est le bon défaut sûr ; une exception ferait échouer la requête qui rendait
/// tout un écran. Le tri « téléchargeable ou non » se fait sur la présence de
/// renditions, jamais sur une exception.
class TeachingDownloadConverter
    extends TypeConverter<TeachingDownload, String> {
  const TeachingDownloadConverter();

  @override
  TeachingDownload fromSql(String fromDb) {
    Object? decoded;
    try {
      decoded = jsonDecode(fromDb);
    } on FormatException {
      return const TeachingDownload(
        version: '',
        durationSeconds: 0,
        renditions: {},
      );
    }
    return decodeMap(decoded);
  }

  @override
  String toSql(TeachingDownload value) => jsonEncode({
        'version': value.version,
        'duration': value.durationSeconds,
        'renditions': {
          for (final entry in value.renditions.entries)
            entry.key: {'url': entry.value.url, 'bytes': entry.value.bytes},
        },
      });

  /// Lit un objet `download` **déjà désérialisé** (venu de la sync ou de SQLite).
  ///
  /// Partagé entre ce convertisseur et le parseur de sync (`sync_rows.dart`)
  /// pour qu'une seule lecture du contrat existe. Tolérant partout : un objet
  /// mal formé rend un [TeachingDownload] vide, une rendition sans `url`/`bytes`
  /// exploitables est **sautée**.
  static TeachingDownload decodeMap(Object? raw) {
    if (raw is! Map) {
      return const TeachingDownload(
        version: '',
        durationSeconds: 0,
        renditions: {},
      );
    }
    final version = raw['version'];
    final duration = raw['duration'];
    return TeachingDownload(
      version: version is String ? version : '',
      durationSeconds:
          duration is int ? duration : (duration is num ? duration.round() : 0),
      renditions: _renditions(raw['renditions']),
    );
  }

  static Map<String, DownloadRendition> _renditions(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, DownloadRendition>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final url = value['url'];
      final bytes = value['bytes'];
      if (url is! String) continue;
      if (bytes is! num) continue;
      result[entry.key.toString()] =
          DownloadRendition(url: url, bytes: bytes.round());
    }
    return Map<String, DownloadRendition>.unmodifiable(result);
  }
}
