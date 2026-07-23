// TODO(#2): écran complet — bienvenue (verset + visuels, « Déjà membre ? »).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../theme/app_spacing.dart';

/// Première page de `/auth` : accueil / point d'entrée du parcours unifié.
///
/// Placeholder minimaliste : un titre + un bouton menant à la saisie de
/// l'identifiant. Le fond (dégradé « glass ») est peint par la route.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bienvenue'),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => context.goNamed(AppRoute.authIdentifier),
                  child: Text(l.authStart),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.goNamed(AppRoute.authIdentifier),
                  child: Text(l.authAlreadyMember),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
