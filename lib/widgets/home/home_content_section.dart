import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/downloads/download_resolver.dart';
import '../../data/players/content_player.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/content_view.dart';
import '../../state/downloads_providers.dart';
import '../../state/player_providers.dart';
import '../../theme/app_spacing.dart';
import '../app_error_state.dart';
import '../app_list_skeleton.dart';
import '../section_header.dart';
import 'home_content_cards.dart';
import 'home_section_layout.dart';

/// Lance ou met en pause un contenu depuis une carte de l'accueil.
Future<void> playHomeContent(
  BuildContext context,
  WidgetRef ref,
  ContentView content,
) async {
  final url = content.playlistUrl;
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.absenceNoMediaMessage)),
    );
    return;
  }

  final player = ref.read(contentPlayerProvider);
  if (player.value.contentId == content.id) {
    if (player.value.isPlaying || player.value.isBuffering) {
      player.pause();
    } else {
      player.play();
    }
    return;
  }

  final resolver = ref.read(downloadResolverProvider);
  await _loadHomeContent(context, player, resolver, content, url);
}

Future<void> _loadHomeContent(
  BuildContext context,
  ContentPlayer player,
  DownloadResolver resolver,
  ContentView content,
  String url,
) async {
  try {
    final resolution = await resolver.resolve(
      contentId: content.id,
      hlsUrl: url,
    );
    await player.load(
      contentId: content.id,
      url: url,
      localFilePath: resolution.localFilePath,
      title: content.title,
      author: content.authorName,
      artUrl: content.squareOrLandscape,
    );
    if (player.value.hasError) {
      _showHomePlaybackError(context);
      return;
    }
    player.play();
  } catch (_) {
    _showHomePlaybackError(context);
  }
}

void _showHomePlaybackError(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.stateErrorMessage)),
  );
}

/// **Une rubrique du référentiel, rendue à l'accueil** — le dessin, sans la
/// famille.
///
/// Tout ce qui la décrit vient du serveur et rien n'est décidé ici : son rang
/// (`position`, déjà appliqué par le magasin), son titre (`label`, déjà replié
/// dans la langue courante), sa teinte (`color`, déjà en bout de cascade) et sa
/// forme (`layout`, traduite en dessin par [HomeSectionLayout.of]). Un
/// administrateur crée une rubrique, la place, choisit sa mise en page — et
/// l'accueil suit, sans livraison.
///
/// Il ne connaît **aucune route** : les enveloppes qui le câblent
/// (`HomeTeachingSection`, `HomeGatheringSection`) choisissent la destination.
/// La lecture, elle, est commune aux deux familles : elle passe par le player
/// global et le résolveur offline-first.
///
/// **Une rubrique sans contenu ne se rend pas du tout**, en-tête compris. Le
/// magasin applique déjà la règle en amont (`itemCount` est toujours strictement
/// positif) et cet écran ne la contourne pas : c'est elle qui fait disparaître
/// d'elle-même une rubrique **supprimée côté serveur**. Les deux référentiels se
/// suppriment durement et sans tombstone — aucun message de retrait ne voyage
/// jamais — et sans cette règle l'accueil garderait une section fantôme
/// définitivement vide.
class HomeContentSection extends ConsumerWidget {
  const HomeContentSection({
    super.key,
    required this.title,
    required this.accent,
    required this.items,
    required this.onOpen,
    required this.onRetry,
    this.layout,
    this.onSeeAll,
  });

  /// **Le titre, déjà replié** dans la langue courante. Une rubrique sert son
  /// `label`, une entrée de menu sert le sien ; ce widget ne choisit ni l'un ni
  /// l'autre, et ne sait pas lequel il a reçu.
  ///
  /// Trois paramètres nus plutôt qu'un `SectionView` : depuis #82 l'accueil a
  /// **deux** sources de sections — le référentiel des rubriques et les entrées
  /// de menu —, et une entrée de menu n'est pas une rubrique (elle n'a ni slug ni
  /// couleur). Fabriquer un faux `SectionView` pour la faire passer ici aurait
  /// donné au dessin une donnée inventée, et à qui le lit l'illusion que les deux
  /// sont la même chose.
  final String title;

  /// La teinte de la pastille du titre, **déjà en bout de cascade**.
  final Color accent;

  /// Le gabarit **brut** (`hero` · `carousel` · `list`), traduit en dessin par
  /// [HomeSectionLayout.of] — une forme inconnue se replie, elle ne fait pas
  /// disparaître la section.
  final String? layout;

  /// Les contenus de la rubrique, dans l'état où le flux les a laissés.
  ///
  /// Déclaré sur [ContentView] et non sur la famille : `AsyncValue` est
  /// covariant, un `AsyncValue<List<TeachingView>>` se passe donc ici tel quel.
  final AsyncValue<List<ContentView>> items;

  /// Ouvre un contenu. C'est l'enveloppe qui sait vers quelle route — la route
  /// porte l'identifiant, jamais l'objet.
  final void Function(ContentView content) onOpen;

  /// Relance la lecture après un échec.
  final VoidCallback onRetry;

  /// « Voir tout », quand la famille a un écran qui les montre tous.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return items.when(
      // La rubrique est **connue non vide** (le magasin ne l'aurait pas rendue
      // sinon) : annoncer son titre pendant la lecture ne promet rien de faux.
      loading: () => _framed(
        context,
        const AppListSkeleton(
          itemCount: 1,
          padding: AppSpacing.screenPadding,
        ),
      ),
      error: (_, __) => _framed(
        context,
        Padding(
          padding: AppSpacing.screenPadding,
          child: AppErrorState(
            message: context.l10n.stateErrorMessage,
            onRetry: onRetry,
          ),
        ),
      ),
      data: (contents) {
        // Le compte du magasin et la liste se lisent dans deux flux : entre les
        // deux, une rétractation a pu vider la rubrique. Elle disparaît alors
        // entièrement, comme si elle n'avait jamais été rendue.
        if (contents.isEmpty) return const SizedBox.shrink();
        return _framed(context, _body(context, ref, contents));
      },
    );
  }

  /// En-tête de la rubrique + corps, avec les respirations de l'accueil.
  Widget _framed(BuildContext context, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: AppSpacing.screenPadding,
          child: SectionHeader(
            title: title,
            // La teinte du référentiel, portée par une **pastille pleine** et
            // non par le texte du titre : une couleur administrable est sûre en
            // aplat (la forme la porte) et ne l'est pas en texte, où le fond
            // adaptatif clair/sombre en avalerait la moitié.
            accent: accent,
            actionLabel: onSeeAll == null ? null : context.l10n.actionSeeAll,
            onAction: onSeeAll,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<ContentView> contents,
  ) {
    switch (HomeSectionLayout.of(layout)) {
      case HomeSectionLayout.hero:
        return _Shelf(
          height: kHeroCoverSize.height,
          itemCount: contents.length,
          itemBuilder: (_, i) => HomeHeroCard(
            content: contents[i],
            onTap: () => onOpen(contents[i]),
          ),
        );
      case HomeSectionLayout.carousel:
        return _Shelf(
          height: kCarouselCoverSize.height,
          itemCount: contents.length,
          itemBuilder: (_, i) => HomeCarouselCard(
            content: contents[i],
            onTap: () => onOpen(contents[i]),
            onPlay: () => playHomeContent(context, ref, contents[i]),
          ),
        );
      case HomeSectionLayout.list:
        // Plafonnée : l'accueil est une vitrine, et une liste verticale non
        // bornée chasserait les sections suivantes hors de portée du pouce.
        final shown = contents.length > kHomeSectionListLimit
            ? contents.sublist(0, kHomeSectionListLimit)
            : contents;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final content in shown)
              HomeListRow(
                content: content,
                onTap: () => onOpen(content),
                onPlay: () => playHomeContent(context, ref, content),
              ),
          ],
        );
    }
  }
}

/// Étagère horizontale à hauteur fixe — la forme commune de `hero` et
/// `carousel`, qui ne diffèrent que par la carte et sa taille.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenPadding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
