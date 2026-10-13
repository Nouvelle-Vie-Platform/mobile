/// **Les providers du module Bible** (M1, #199) : le catalogue, la version
/// active, le texte d'un chapitre, et ma position de lecture.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/bible_dao.dart';
import '../../../state/auth_providers.dart';
import '../../../state/sync_providers.dart';
import 'bible_source.dart';
import 'placeholder_bible.dart';

export '../../../data/local/bible_dao.dart' show BibleReadingSnapshot;

/// Le catalogue des versions. Factice tant que S5 et le chantier du contenu ne
/// servent rien ; surcharger ici, et nulle part ailleurs.
final bibleCatalogProvider = Provider<BibleCatalog>(
  (ref) => const PlaceholderBibleCatalog(),
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

/// La clé d'un chapitre dans une version.
typedef BibleChapterKey = ({String version, String book, int chapter});

/// Le texte d'un chapitre. Vide si la version n'est pas installée.
final bibleChapterProvider =
    FutureProvider.family<List<BibleVerse>, BibleChapterKey>((ref, key) async {
  final source = ref.watch(bibleCatalogProvider).sourceFor(key.version);
  if (source == null) return const [];
  return source.chapter(key.book, key.chapter);
});
