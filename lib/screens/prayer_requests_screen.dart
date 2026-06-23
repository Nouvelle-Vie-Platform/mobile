import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../routes.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/cards/prayer_request_card.dart';
import '../widgets/segmented_tabs.dart';

/// Écran « Espace de prière » : onglets Mes requêtes / Communauté.
class PrayerRequestsScreen extends StatelessWidget {
  const PrayerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = ValueNotifier<int>(0);

    return Scaffold(
      appBar: AppBar(title: const Text('Espace de prière')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  ValueListenableBuilder<int>(
                    valueListenable: tab,
                    builder: (context, value, _) => SegmentedTabs(
                      tabs: const ['Mes requêtes', 'Communauté'],
                      selected: value,
                      onSelect: (i) => tab.value = i,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  for (final p in SampleData.prayers) ...[
                    PrayerRequestCard(request: p),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Nouvelle requête',
                    icon: Icons.add,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.newRequest),
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
