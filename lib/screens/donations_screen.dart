import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/icon_text.dart';
import '../widgets/selectable_option.dart';

/// Écran « Dons & Contributions » : choix du montant et du moyen de paiement.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  static const _amounts = ['1 000 CFA', '5 000 CFA', '10 000 CFA', 'Autre'];

  int _amount = 1;
  int _method = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.donationsAppBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(context.l10n.donationsTitle, style: AppTypography.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(context.l10n.donationsSubtitle,
                style: AppTypography.bodyLarge
                    .copyWith(color: context.palette.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            Text(context.l10n.donationsAmountLabel, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.6,
              children: [
                for (var i = 0; i < _amounts.length; i++)
                  AmountOption(
                    label: _amounts[i],
                    selected: i == _amount,
                    onTap: () => setState(() => _amount = i),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(context.l10n.donationsPaymentMethodLabel,
                style: AppTypography.h5),
            const SizedBox(height: AppSpacing.md),
            Column(
              children: [
                PaymentOption(
                  label: 'Moov Money',
                  icon: Icons.account_balance_wallet,
                  iconColor: AppColors.warning,
                  selected: _method == 0,
                  onTap: () => setState(() => _method = 0),
                ),
                const SizedBox(height: AppSpacing.md),
                PaymentOption(
                  label: 'TMoney',
                  icon: Icons.phone_android,
                  iconColor: AppColors.danger,
                  selected: _method == 1,
                  onTap: () => setState(() => _method = 1),
                ),
                const SizedBox(height: AppSpacing.md),
                PaymentOption(
                  label: context.l10n.paymentCard,
                  icon: Icons.credit_card,
                  iconColor: AppColors.primary,
                  selected: _method == 2,
                  onTap: () => setState(() => _method = 2),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: context.l10n.actionContinue, onPressed: () {}),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: IconText(
                icon: Icons.lock_outline,
                label: context.l10n.donationsSecure,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
