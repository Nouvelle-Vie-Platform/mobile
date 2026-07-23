// TODO(#3): écran complet — saisie identifiant (toggle téléphone/email,
// indicatif, boutons Google/Apple).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_spacing.dart';

/// `/auth/identifier` : saisie du téléphone ou de l'email, envoi du code.
///
/// Placeholder minimaliste : envoie un code sur un identifiant factice puis
/// pousse l'écran de vérification avec les [CodeArgs] correspondants.
class IdentifierScreen extends ConsumerWidget {
  const IdentifierScreen({super.key});

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
                Text(l.authIdentifierTitle),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () => _submit(context, ref),
                  child: Text(l.authContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    // Identifiant factice tant que le formulaire n'est pas construit.
    const identifier = '+22890000000';
    const channel = IdentifierChannel.sms;
    await ref
        .read(authProvider.notifier)
        .requestCode(identifier: identifier, channel: channel);
    if (!context.mounted) return;
    context.goNamed(
      AppRoute.authCode,
      extra: const CodeArgs(identifier: identifier, channel: channel),
    );
  }
}
