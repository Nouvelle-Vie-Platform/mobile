/// **Les providers du module Bible** (M1, #199) : le catalogue, la version
/// active, le texte d'un chapitre, et ma position de lecture.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/bible_dao.dart';
import '../../../state/auth_providers.dart';
import '../../../state/sync_providers.dart';
import '../personalize/bible_catalog.dart';
import '../personalize/reader_appearance.dart';
import 'bible_source.dart';
import 'versification.dart';

export '../../../data/local/bible_dao.dart' show BibleReadingSnapshot;

/// Le catalogue des versions : les deux factices fusionnées avec S5 (M4,
/// `personalize/bible_catalog.dart`) ; surcharger ici, et nulle part ailleurs.
final bibleCatalogProvider = Provider<BibleCatalog>(
  (ref) => ref.watch(mergedBibleCatalogProvider),
);

/// Toutes les versions connues du catalogue.
final bibleVersionsProvider = FutureProvider<List<BibleVersion>>(
  (ref) => ref.watch(bibleCatalogProvider).versions(),
);

final bibleDaoProvider = Provider<BibleDao>(
  (ref) => ref.watch(appDatabaseProvider).bibleDao,
);

/// `true` pour un membre connecté : lui seul lit les miroirs privés.
final bibleIsMemberProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((s) => s.isAuthenticated)),
);

/// Ma position et mes chapitres lus (ligne locale, sinon miroir du membre).
final bibleReadingStateProvider = StreamProvider<BibleReadingSnapshot?>(
  (ref) => ref
      .watch(bibleDaoProvider)
      .watchReadingState(member: ref.watch(bibleIsMemberProvider)),
);

/// **La version active** : celle de ma position de lecture si elle est
/// installée, sinon la version par défaut du catalogue. Le lecteur la change
/// par [ActiveBibleVersion.select] puis enregistre sa position, ce qui la
/// rend durable.
final activeBibleVersionProvider =
    NotifierProvider<ActiveBibleVersion, String>(ActiveBibleVersion.new);

class ActiveBibleVersion extends Notifier<String> {
  @override
  String build() {
    final catalog = ref.watch(bibleCatalogProvider);
    final saved = ref.watch(bibleReadingStateProvider).value?.versionCode;
    if (saved != null && catalog.sourceFor(saved) != null) return saved;
    return catalog.defaultVersionCode;
  }

  void select(String code) {
    if (ref.read(bibleCatalogProvider).sourceFor(code) != null) state = code;
  }
}

/// **La versification de la version ouverte** (C3, #240, décision 2 de
/// server-portal#605) : la grille, la validation d'une référence tapée et
/// l'index plein texte la suivent, au lieu du canon figé. Une version sans
/// relevé — la Bible factice, et toute version installée avant C4 — rend
/// `kCanonVersification`, donc rien ne bouge pour elle.
final bibleVersificationProvider = Provider<BibleVersification>((ref) {
  final code = ref.watch(activeBibleVersionProvider);
  return ref.watch(bibleCatalogProvider).versificationFor(code);
});

/// **La langue des noms de livres affichés** : celle de la version ouverte.
///
/// Demandé le 30/10/2026, et c'est la bonne règle : un fidèle qui n'a
/// téléchargé que l'éwé lit un texte en éwé, et « Jean 8:36 » au-dessus était un
/// mélange. **La dernière version choisie décide** — changer de version change
/// les titres, le lecteur comme l'accueil, la recherche comme les favoris.
///
/// Elle ne touche pas la langue de l'application, et **aucune clé ne la suit** :
/// les codes OSIS, l'index plein texte et l'analyse des références restent sur
/// le français, qui reste reconnu quelle que soit la langue de l'écran
/// (`canon.dart`).
final bibleBookLanguageProvider = Provider<String>((ref) {
  final code = ref.watch(activeBibleVersionProvider);
  return ref.watch(bibleCatalogProvider).languageFor(code);
});

/// **La famille de police des textes bibliques affichés.**
///
/// `Andika` quand la version ouverte s'écrit avec des lettres qu'aucune autre
/// police embarquée ne porte, la police de l'application sinon. Tout ce qui
/// montre du texte venu d'une Bible passe par là — le verset, mais aussi son
/// titre : « 1 Mɔse » en porte autant que le verset lui-même.
final bibleTextFontFamilyProvider = Provider<String>(
    (ref) => bibleTextFontFamily(ref.watch(bibleBookLanguageProvider)));

/// La clé d'un chapitre dans une version.
typedef BibleChapterKey = ({String version, String book, int chapter});

/// Le texte d'un chapitre. Vide si la version n'est pas installée.
final bibleChapterProvider =
    FutureProvider.family<List<BibleVerse>, BibleChapterKey>((ref, key) async {
  final source = ref.watch(bibleCatalogProvider).sourceFor(key.version);
  if (source == null) return const [];
  return source.chapter(key.book, key.chapter);
});
