/// **Le vocabulaire réglé, depuis le magasin jusqu'à l'arbre de widgets** (#81).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/vocabulary.dart';
import '../models/vocabulary.dart';
import 'sync_providers.dart';

/// Ce que le portail a surchargé, **observé** : un mot changé au portail
/// apparaît au cycle de synchronisation suivant, sans qu'on rouvre l'écran.
///
/// **Pas de réessai automatique** — même parti pris que les autres lectures du
/// magasin : il n'y a rien à retenter en boucle sur une base locale.
final vocabularyProvider = StreamProvider<VocabularyOverrides>(
  (ref) => ref.watch(vocabularyDaoProvider).watchOverrides(),
  retry: _noAutomaticRetry,
);

Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Pose le vocabulaire sur l'arbre**, et ne retient jamais le premier frame.
///
/// En chargement comme en erreur, l'enfant est rendu avec
/// [VocabularyOverrides.empty] : c'est le `.arb` compilé, c'est-à-dire l'état de
/// départ légitime. Attendre la base donnerait un écran blanc au démarrage pour
/// une poignée de mots que le binaire porte déjà.
///
/// ⚠️ Il doit vivre **sous** `MaterialApp` : `AppWords` lit la locale que le
/// framework a résolue, et `Localizations` n'existe pas au-dessus.
class VocabularyBoundary extends ConsumerWidget {
  const VocabularyBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VocabularyScope(
        overrides:
            ref.watch(vocabularyProvider).value ?? VocabularyOverrides.empty,
        child: child,
      );
}
