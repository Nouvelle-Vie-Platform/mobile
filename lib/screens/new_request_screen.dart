import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/menu_tile.dart';
import '../widgets/selectable_option.dart';

/// Écran « Boîte à requêtes » : formulaire de nouvelle requête.
class NewRequestScreen extends StatelessWidget {
  const NewRequestScreen({super.key});

  static const _types = ['Suggestion', 'Plainte', 'Signalement', 'Autre'];

  @override
  Widget build(BuildContext context) {
    final selectedType = ValueNotifier<int>(0);
    final anonymous = ValueNotifier<bool>(true);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle requête')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('Type de requête', style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ValueListenableBuilder<int>(
                valueListenable: selectedType,
                builder: (context, selected, _) => Column(
                  children: [
                    for (var i = 0; i < _types.length; i++) ...[
                      RadioOptionTile(
                        label: _types[i],
                        selected: i == selected,
                        onTap: () => selectedType.value = i,
                      ),
                      if (i < _types.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppTextField(
              label: 'Décrivez votre requête',
              hint: 'Écrivez votre message ici...',
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xl),
            ValueListenableBuilder<bool>(
              valueListenable: anonymous,
              builder: (context, value, _) => LabeledSwitch(
                label: 'Anonyme',
                subtitle: 'Votre identité restera confidentielle.',
                value: value,
                onChanged: (v) => anonymous.value = v,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Envoyer',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
