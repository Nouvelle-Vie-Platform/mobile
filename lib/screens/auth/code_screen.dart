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

/// `/auth/code` : saisie du code à 6 chiffres.
///
/// Reçoit ses arguments via `state.extra` typé [CodeArgs] (voir app_router.dart).
/// Validation automatique dès la 6e case remplie ; renvoi du code avec cooldown ;
/// un message unique couvre « invalide ou expiré » (le serveur ne distingue pas
/// les deux cas). Succès → route selon `session.isNewUser` (nouveau →
/// complétion de profil, sinon → accueil).
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  /// Nombre de chiffres du code (`otpConfig.codeLength` côté serveur).
  static const int _codeLength = 6;

  /// Cooldown de renvoi par défaut, aligné sur le serveur (cf. contrat) :
  /// en deçà, `POST /auth/request-code` répond `429 E_OTP_RATE_LIMITED`.
  /// N'est utilisé que si le serveur n'a pas fourni de `Retry-After`.
  static const int _cooldownSeconds = 60;

  final OtpFieldController _otp = OtpFieldController();

  Timer? _cooldownTimer;
  int _secondsLeft = 0;

  /// Chiffres saisis, suivis pour n'activer « Valider » qu'à code complet :
  /// envoyer un code trop court ne rapporterait qu'un 422 inutile.
  String _code = '';
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

  /// (Re)démarre le décompte avant de pouvoir renvoyer un code.
  ///
  /// [seconds] : valeur du serveur (`Retry-After`) quand elle est disponible,
  /// sinon [_cooldownSeconds]. Le décompte en cours n'est **jamais raccourci** :
  /// aucun chemin ne peut ainsi rouvrir le bouton « Renvoyer » avant l'heure,
  /// ce qui garantit qu'un appui ne prend pas un 429.
  void _startCooldown([int? seconds]) {
    final target = seconds ?? _cooldownSeconds;
    _cooldownTimer?.cancel();
    setState(
        () => _secondsLeft = target > _secondsLeft ? target : _secondsLeft);
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
        // Un seul message pour « invalide » et « expiré » : le serveur fusionne
        // les deux cas dans un 422 générique pour ne pas renseigner un attaquant
        // sur l'état d'un code.
        _errorText = switch (error.code) {
          AuthErrorCode.tooManyAttempts => l.authCodeTooManyAttempts,
          _ => l.authCodeInvalid,
        };
      });
      // Le serveur peut avoir posé un délai (trop d'essais) : le décompte de
      // renvoi s'y aligne pour ne pas proposer une action qui échouerait.
      final retryAfter = error.retryAfter;
      if (retryAfter != null) _startCooldown(retryAfter.inSeconds);
      // Vide les cases et refocalise la première pour une nouvelle saisie.
      _otp.clear();
    }
  }

  Future<void> _resend(CodeArgs args) async {
    if (_secondsLeft > 0 || _loading) return;
    try {
      await ref.read(authProvider.notifier).requestCode(
            identifier: args.identifier,
            channel: args.channel,
          );
    } on AuthException catch (error) {
      if (!mounted) return;
      // Renvoi refusé (429) : on repart sur le délai annoncé par le serveur
      // plutôt que de reproposer immédiatement un bouton qui échouera.
      _startCooldown(error.retryAfter?.inSeconds);
      _showMessage(
        error.code == AuthErrorCode.tooManyAttempts
            ? context.l10n.authCodeTooManyAttempts
            : context.l10n.errorGeneric,
      );
      return;
    }
    if (!mounted) return;
    _startCooldown();
    _otp.clear();
    setState(() {
      _hasError = false;
      _errorText = null;
    });
    _showMessage(context.l10n.authCodeResent);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                length: _codeLength,
                controller: _otp,
                hasError: _hasError,
                enabled: !_loading,
                onChanged: (code) => setState(() => _code = code),
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
                onPressed: _loading || _code.length < _codeLength
                    ? null
                    : () => _verify(_code, args),
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
