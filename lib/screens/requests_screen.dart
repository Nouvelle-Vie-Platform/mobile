import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/brand_app_bar.dart';

/// Écran **« Requêtes »**, ouvert par le bouton en haut à droite du hub
/// « Échanges » (décision D11).
///
/// C'est une **liste avec état vide** au départ : il n'y a **pas** de nouveau
/// modèle de donnée (décision D12), rien n'est stocké. Le bouton d'ajout ouvre
/// le formulaire existant (`new_request_screen`).
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: BrandAppBar(title: l.requestsTitle),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            AppEmptyState(
              icon: Icons.assignment_outlined,
              title: l.requestsEmptyTitle,
              message: l.requestsEmpty,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l.requestsAdd,
              icon: Icons.add,
              onPressed: () => context.pushNamed(AppRoute.newRequest),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
