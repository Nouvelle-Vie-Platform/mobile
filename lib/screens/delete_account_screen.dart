import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../l10n/l10n_extension.dart';
import '../state/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/brand_app_bar.dart';

/// **Suppression de compte** (`/profile/delete`).
///
/// Exigence d'entrée à l'App Store (règle 5.1.1(v), équivalent Google Play) :
/// une application qui permet de créer un compte doit permettre de le supprimer
/// **depuis l'application**, pas par courrier au support.
///
/// **Un écran, pas un dialogue**, et c'est la décision qui gouverne le reste.
/// La déconnexion se confirme deux lignes plus haut dans la même liste, par un
/// dialogue à deux boutons ; donner la même apparence à une action qui efface
/// pour toujours ferait de la ressemblance un piège — le pouce qui vise
/// « Se déconnecter » et glisse d'un cran ne doit pas pouvoir tout perdre.
///
/// Trois choses s'y jouent, dans cet ordre :
///
/// 1. **« Définitif » se dit avant toute liste.** C'est la seule chose à
///    retenir de celui qui ne lira pas la suite.
/// 2. **Ce qui part et ce qui reste sont deux colonnes distinctes.** Le serveur
///    efface l'identité et les données personnelles, mais **détache** le
///    contenu communautaire au lieu de le supprimer (ADR-0032) : un fil de
///    groupe reste lisible, une prière que d'autres ont portée ne disparaît pas
///    du mur. Taire cette moitié ferait renoncer des gens pour une raison
///    fausse — « je ne veux pas effacer ce que j'ai écrit aux autres ».
/// 3. **L'email redevient libre, mais ne ramène rien.** Le serveur autorise une
///    réinscription immédiate sur la même adresse ; elle crée un compte
///    *entièrement neuf*. Sans cette phrase, on croit pouvoir revenir.
///
/// **L'ordre serveur-puis-local n'est pas négociable** — il vit dans
/// `AuthController.deleteAccount`. Une panne réseau laisse le compte vivant et
/// l'écran garde la main : vider le téléphone d'abord laisserait quelqu'un
/// convaincu d'avoir disparu alors qu'il est toujours inscrit.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  /// Clés de test : la case et le bouton, les deux seuls points d'entrée.
  static const Key confirmKey = Key('delete_account_confirm');
  static const Key submitKey = Key('delete_account_submit');

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _understood = false;
  bool _working = false;
  String? _error;

  /// Le succès **ne navigue pas**. L'état passe à « déconnecté » et la garde
  /// `redirect` du routeur retire l'écran d'elle-même — le motif que suit déjà
  /// la déconnexion, et la seule façon de ne pas se retrouver à dépiler une
  /// route dont la session n'existe plus.
  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e.code == AuthErrorCode.network
            ? l.deleteAccountErrorNetwork
            : l.deleteAccountErrorServer;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = l.deleteAccountErrorServer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.deleteAccountTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            l.deleteAccountLead,
            style: AppTypography.bodyLarge.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Block(
            icon: Icons.delete_outline,
            tint: AppColors.danger,
            title: l.deleteAccountErasedTitle,
            lines: [
              l.deleteAccountErasedIdentity,
              l.deleteAccountErasedNotes,
              l.deleteAccountErasedProgress,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Block(
            icon: Icons.people_outline,
            tint: AppColors.secondary,
            title: l.deleteAccountKeptTitle,
            lines: [
              l.deleteAccountKeptMessages,
              l.deleteAccountKeptPrayers,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.deleteAccountReuse,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          // La case porte le libellé : un `CheckboxListTile` rendrait toute la
          // ligne cliquable, ce qui est ici une surface de déclenchement de
          // trop pour l'unique garde-fou de l'écran.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: DeleteAccountScreen.confirmKey,
                value: _understood,
                activeColor: AppColors.danger,
                onChanged: _working
                    ? null
                    : (v) => setState(() => _understood = v ?? false),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l.deleteAccountConfirmCheckbox,
                    style:
                        AppTypography.body.copyWith(color: palette.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.body.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: DeleteAccountScreen.submitKey,
            label: l.deleteAccountAction,
            variant: AppButtonVariant.danger,
            loading: _working,
            onPressed: _understood && !_working ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Un bloc « ce qui part » / « ce qui reste » : un titre teinté, puis des
/// lignes à puce.
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.tint,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(width: AppSpacing.sm),
            // `Expanded` et non un `Text` nu : ces titres sont traduits, et
            // l'anglais comme l'éwé peuvent être plus longs que le français.
            // Un titre libre déborderait sur un écran étroit ou en grande
            // police — sans que personne ne s'en aperçoive avant l'appareil.
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyStrong.copyWith(color: tint),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xl,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ',
                    style: AppTypography.body
                        .copyWith(color: palette.textSecondary)),
                Expanded(
                  child: Text(
                    line,
                    style: AppTypography.body
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
