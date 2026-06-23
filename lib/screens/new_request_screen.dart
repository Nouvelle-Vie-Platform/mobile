import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/menu_tile.dart';
import '../widgets/selectable_option.dart';

/// Écran « Boîte à requêtes » : formulaire de nouvelle requête.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  static const _types = ['Suggestion', 'Plainte', 'Signalement', 'Autre'];

  int _selectedType = 0;
  bool _anonymous = true;

  @override
  Widget build(BuildContext context) {
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
              child: Column(
                children: [
                  for (var i = 0; i < _types.length; i++) ...[
                    RadioOptionTile(
                      label: _types[i],
                      selected: i == _selectedType,
                      onTap: () => setState(() => _selectedType = i),
                    ),
                    if (i < _types.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppTextField(
              label: 'Décrivez votre requête',
              hint: 'Écrivez votre message ici...',
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xl),
            LabeledSwitch(
              label: 'Anonyme',
              subtitle: 'Votre identité restera confidentielle.',
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
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
