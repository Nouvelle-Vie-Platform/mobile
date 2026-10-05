import 'dart:convert';

import 'package:drift/drift.dart';

/// Stocke la **forme d'onde servie** d'un statut audio
/// (`announcements.media_waveform`) dans une colonne texte, en tableau JSON.
///
/// Le serveur la tire de la passe de normalisation du transcodeur : **trente-six
/// hauteurs de 0 à 100** (décision 10 du plan « Sparks »). On stocke ce qu'il
/// envoie, sans ré-échantillonner : le nombre de barres dessinées est une
/// décision d'affichage (`StatusWaveform`), pas de stockage.
///
/// La lecture est **tolérante** : un JSON corrompu, une forme inattendue ou une
/// valeur hors bornes ne lèvent pas. Une forme d'onde illisible se lit « pas de
/// forme d'onde », et l'écran retombe alors sur le repli déterministe dérivé de
/// l'identifiant — une exception ferait échouer la requête qui peint tout le
/// mur de statuts.
class WaveformConverter extends TypeConverter<List<int>, String> {
  const WaveformConverter();

  @override
  List<int> fromSql(String fromDb) {
    Object? decoded;
    try {
      decoded = jsonDecode(fromDb);
    } on FormatException {
      return const [];
    }
    return decode(decoded) ?? const [];
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);

  /// Lit une forme d'onde **déjà désérialisée** — venue de la synchronisation
  /// ou de SQLite.
  ///
  /// Partagée entre ce convertisseur et le parseur de synchronisation
  /// (`sync_rows.dart`), pour qu'une seule lecture du contrat existe :
  ///
  /// - `null` quand la valeur n'est pas une liste (absente, ou d'une autre
  ///   forme) — « le serveur n'a rien dit » ;
  /// - sinon les hauteurs, **bornées à 0..100** et arrondies : le serveur sert
  ///   des entiers, mais un `jsonb` peut rendre `42.0`, et une barre à 140 %
  ///   déborderait du cadre de la forme d'onde. Une entrée qui n'est pas un
  ///   nombre est **sautée**, pas remplacée : inventer une hauteur serait
  ///   dessiner un son qui n'existe pas.
  static List<int>? decode(Object? raw) {
    if (raw is! List) return null;
    return List<int>.unmodifiable([
      for (final entry in raw)
        if (entry is num) entry.round().clamp(0, 100),
    ]);
  }
}
