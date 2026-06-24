import 'package:flutter/material.dart';
import '../widgets/brand_app_bar.dart';

import '../l10n/l10n_extension.dart';
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
  int _selectedType = 0;
  bool _anonymous = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final types = [
      l10n.requestTypeSuggestion,
      l10n.requestTypeComplaint,
      l10n.requestTypeReport,
      l10n.requestTypeOther,
    ];

    return Scaffold(
      appBar: BrandAppBar(title: l10n.newRequestAppBarTitle),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(l10n.newRequestTypeLabel, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < types.length; i++) ...[
                    RadioOptionTile(
                      label: types[i],
                      selected: i == _selectedType,
                      onTap: () => setState(() => _selectedType = i),
                    ),
                    if (i < types.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: l10n.newRequestDescribeLabel,
              hint: l10n.newRequestDescribeHint,
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xl),
            LabeledSwitch(
              label: l10n.anonymousLabel,
              subtitle: l10n.anonymousSubtitle,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.actionSend,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
