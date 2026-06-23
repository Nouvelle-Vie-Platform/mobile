import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/cards/prayer_request_card.dart';
import '../widgets/segmented_tabs.dart';

/// Écran « Espace de prière » : onglets Mes requêtes / Communauté.
class PrayerRequestsScreen extends ConsumerStatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  ConsumerState<PrayerRequestsScreen> createState() =>
      _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends ConsumerState<PrayerRequestsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final prayers = ref.watch(prayersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.prayersAppBarTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  SegmentedTabs(
                    tabs: [
                      context.l10n.prayersTabMine,
                      context.l10n.prayersTabCommunity,
                    ],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  for (final p in prayers) ...[
                    PrayerRequestCard(request: p),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: context.l10n.prayersNewRequest,
                    icon: Icons.add,
                    onPressed: () => context.pushNamed(AppRoute.newRequest),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
