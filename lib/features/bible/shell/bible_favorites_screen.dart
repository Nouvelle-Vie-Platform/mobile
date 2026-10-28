/// **Favoris** (#265) : une puce par filtre enregistré (M2), la liste du
/// filtre choisi dessous — l'ancien onglet Favori, devenu un écran poussé
/// pour laisser la barre à quatre onglets.
///
/// Deux portes : la carte « Favoris » de l'accueil et la première ligne de
/// Mon espace ; `/bible?tab=favorites` (les anciens liens) le pousse sur
/// l'onglet Bible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/app_empty_state.dart';
import '../../../widgets/brand_app_bar.dart';
import 'bible_route.dart';
import 'bible_slots.dart';

class BibleFavoritesScreen extends ConsumerStatefulWidget {
  const BibleFavoritesScreen({super.key});

  /// Pousse l'écran, par le navigateur du routeur (jamais le `BuildContext`).
  static Future<void> open(WidgetRef ref) => ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentState!
      .push<void>(bibleRoute<void>(const BibleFavoritesScreen()));

  @override
  ConsumerState<BibleFavoritesScreen> createState() =>
      _BibleFavoritesScreenState();
}

class _BibleFavoritesScreenState extends ConsumerState<BibleFavoritesScreen> {
  String? _filterId;

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(bibleSlotsProvider).favoriteFilters;
    return Scaffold(
      appBar: BrandAppBar(title: context.l10n.bibleTabFavorites),
      body: filters.isEmpty
          ? ListView(
              padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.xxl),
              children: [
                AppEmptyState(
                  title: context.l10n.bibleSoonTitle,
                  message: context.l10n.bibleFavoritesSoon,
                  icon: Icons.star_outline,
                ),
              ],
            )
          : _list(filters),
    );
  }

  Widget _list(List<BibleFavoriteFilter> filters) {
    final current = filters.firstWhere(
      (f) => f.id == _filterId,
      orElse: () => filters.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.screenPadding.copyWith(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(f.label(context)),
                    selected: f.id == current.id,
                    onSelected: (_) => setState(() => _filterId = f.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: current.builder(context)),
      ],
    );
  }
}
