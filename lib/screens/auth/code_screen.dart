import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/brand_app_bar.dart';
import '../../widgets/auth/otp_field.dart';
import '../../widgets/profile_setup_sheet.dart';

/// `/auth/code` : saisie du code à 4 chiffres.
///
/// Reçoit ses arguments via `state.extra` typé [CodeArgs] (voir app_router.dart).
/// Validation automatique dès la 4e case remplie ; renvoi du code avec cooldown ;
/// erreurs (incorrect / expiré) affichées sous les cases. Succès → route selon
/// `session.isNewUser` (nouveau → complétion de profil, sinon → accueil).
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  /// Durée du cooldown avant de pouvoir renvoyer le code (~45 s, cf. contrat).
  static const int _cooldownSeconds = 45;

  final OtpFieldController _otp = OtpFieldController();

  Timer? _cooldownTimer;
  int _secondsLeft = 0;
  bool _loading = false;
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Le code vient d'être envoyé par l'écran identifiant : démarrer le cooldown.
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify(String code, CodeArgs args) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _hasError = false;
      _errorText = null;
    });
    try {
      final session = await ref.read(authProvider.notifier).verifyCode(
            identifier: args.identifier,
            code: code,
          );
      if (!mounted) return;
      // On atterrit toujours sur l'accueil. Pour un nouvel utilisateur, la
      // feuille de mise en route du profil s'y ouvre par-dessus (fermable).
      if (session.isNewUser) {
        ref.read(profileSetupPendingProvider.notifier).request();
      }
      context.goNamed(AppRoute.home);
    } on AuthException catch (error) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _loading = false;
        _hasError = true;
        _errorText = switch (error.code) {
          AuthErrorCode.expiredCode => l.authCodeExpired,
          AuthErrorCode.tooManyAttempts => l.authCodeTooManyAttempts,
          _ => l.authCodeInvalid,
        };
      });
      // Vide les cases et refocalise la première pour une nouvelle saisie.
      _otp.clear();
    }
  }

  Future<void> _resend(CodeArgs args) async {
    if (_secondsLeft > 0) return;
    try {
      await ref.read(authProvider.notifier).requestCode(
            identifier: args.identifier,
            channel: args.channel,
          );
    } on AuthException {
      // Mock : requestCode n'échoue pas ; en phase B on pourrait afficher un
      // message réseau. On relance quand même le cooldown pour éviter le spam.
    }
    if (!mounted) return;
    _startCooldown();
    _otp.clear();
    setState(() {
      _hasError = false;
      _errorText = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.authCodeResent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = GoRouterState.of(context).extra as CodeArgs?;

    // Accès direct sans arguments : repli gracieux vers l'écran identifiant.
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.goNamed(AppRoute.authIdentifier);
      });
      return const Scaffold(backgroundColor: Colors.transparent);
    }

    final palette = context.palette;
    final canResend = _secondsLeft <= 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.authCodeTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text(
                l.authCodeSubtitle(args.identifier),
                textAlign: TextAlign.center,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              OtpField(
                controller: _otp,
                hasError: _hasError,
                enabled: !_loading,
                onCompleted: (code) => _verify(code, args),
              ),
              const SizedBox(height: AppSpacing.md),
              // Message d'erreur (rouge) sous les cases, en plus de la bordure.
              SizedBox(
                height: 20,
                child: _errorText == null
                    ? null
                    : Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.danger),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l.actionValidate,
                loading: _loading,
                onPressed: _loading ? null : () => _verify(_otp.value, args),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: canResend
                    ? TextButton(
                        onPressed: _loading ? null : () => _resend(args),
                        child: Text(
                          l.authResend,
                          style: AppTypography.bodyStrong
                              .copyWith(color: palette.primary),
                        ),
                      )
                    : Text(
                        l.authResendIn(_secondsLeft),
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
