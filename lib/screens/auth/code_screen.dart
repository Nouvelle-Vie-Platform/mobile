// TODO(#4): écran complet — vérification (cases séparées, renvoi/cooldown,
// erreurs incorrect/expiré).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_spacing.dart';

/// `/auth/code` : saisie du code à 4 chiffres.
///
/// Reçoit ses arguments via `state.extra` typé [CodeArgs] (voir app_router.dart).
/// Placeholder minimaliste : valide le code magique `0000` puis route selon
/// `isNewUser` (nouveau → complétion de profil, sinon → accueil).
class CodeScreen extends ConsumerWidget {
  const CodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final args = GoRouterState.of(context).extra as CodeArgs?;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.authCodeTitle),
                if (args != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(args.identifier),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => _verify(context, ref, args),
                  child: Text(l.actionValidate),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verify(
    BuildContext context,
    WidgetRef ref,
    CodeArgs? args,
  ) async {
    try {
      final session = await ref.read(authProvider.notifier).verifyCode(
            identifier: args?.identifier ?? '',
            code: '0000',
          );
      if (!context.mounted) return;
      // Nouveau → complétion de profil (skippable) ; sinon → accueil direct.
      context.goNamed(
        session.isNewUser ? AppRoute.profileEdit : AppRoute.home,
      );
    } on AuthException {
      // TODO(#4): afficher l'erreur (code incorrect / expiré).
    }
  }
}
