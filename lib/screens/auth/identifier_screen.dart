import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dial_codes.dart';
import '../../widgets/social_button.dart';

/// `/auth/identifier` : saisie du téléphone ou de l'email, envoi du code.
///
/// Toggle **Téléphone / Email** (téléphone en premier). En mode téléphone, un
/// sélecteur d'indicatif (déduit du locale, repli +228) précède le champ et
/// l'identifiant est normalisé en **E.164** ; en mode email, l'adresse est mise
/// en minuscules. « Continuer » demande un code puis pousse [CodeScreen] ;
/// Google/Apple sautent l'étape code et routent selon `isNewUser`.
class IdentifierScreen extends ConsumerStatefulWidget {
  const IdentifierScreen({super.key});

  @override
  ConsumerState<IdentifierScreen> createState() => _IdentifierScreenState();
}

class _IdentifierScreenState extends ConsumerState<IdentifierScreen> {
  final _controller = TextEditingController();

  /// Onglet courant : téléphone (défaut) ou email.
  bool _isPhone = true;

  /// Indicatif sélectionné (initialisé depuis le locale appareil).
  late DialCountry _dialCountry;

  /// Envoi du code en cours (spinner sur « Continuer »).
  bool _submitting = false;

  /// Connexion sociale en cours (désactive les actions).
  bool _socialBusy = false;

  @override
  void initState() {
    super.initState();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    _dialCountry = dialCountryForCode(locale.countryCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _busy => _submitting || _socialBusy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: palette.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding.copyWith(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.authIdentifierTitle, style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.authIdentifierSubtitle,
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildToggle(l, palette),
              const SizedBox(height: AppSpacing.lg),
              _isPhone ? _buildPhoneField(l, palette) : _buildEmailField(l),
              const SizedBox(height: AppSpacing.xl),
              _buildContinueButton(l),
              const SizedBox(height: AppSpacing.xl),
              _buildSeparator(l, palette),
              const SizedBox(height: AppSpacing.lg),
              // Libellés de marque (proper nouns) — non traduits.
              SocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata,
                onPressed: _busy ? null : () => _social(_SocialProvider.google),
              ),
              const SizedBox(height: AppSpacing.md),
              SocialButton(
                label: 'Apple',
                icon: Icons.apple,
                onPressed: _busy ? null : () => _social(_SocialProvider.apple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(AppLocalizations l, AppPalette palette) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: true,
          label: Text(l.authPhone),
          icon: const Icon(Icons.phone_outlined),
        ),
        ButtonSegment(
          value: false,
          label: Text(l.authEmail),
          icon: const Icon(Icons.mail_outline),
        ),
      ],
      selected: {_isPhone},
      showSelectedIcon: false,
      onSelectionChanged: _busy
          ? null
          : (selection) {
              setState(() {
                _isPhone = selection.first;
                _controller.clear();
              });
            },
    );
  }

  Widget _buildPhoneField(AppLocalizations l, AppPalette palette) {
    // `IntrinsicHeight` borne la hauteur de la Row : sans elle, le `stretch`
    // (indicatif à la hauteur du champ) échoue dans un contexte de hauteur
    // infinie (`SingleChildScrollView`).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialCodeButton(
            country: _dialCountry,
            onTap: _busy ? null : _pickDialCode,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              ],
              decoration: _fieldDecoration(context, hint: l.authPhoneHint),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(AppLocalizations l) {
    return TextField(
      controller: _controller,
      enabled: !_busy,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: _fieldDecoration(context, hint: l.authEmailHint),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _buildContinueButton(AppLocalizations l) {
    return FilledButton(
      onPressed: _busy ? null : _submit,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: _submitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(l.authContinue),
    );
  }

  Widget _buildSeparator(AppLocalizations l, AppPalette palette) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            l.authOrContinueWith,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: palette.divider)),
      ],
    );
  }

  InputDecoration _fieldDecoration(BuildContext context,
      {required String hint}) {
    final palette = context.palette;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.field,
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.field,
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.field,
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
    );
  }

  Future<void> _pickDialCode() async {
    FocusScope.of(context).unfocus();
    final palette = context.palette;
    final selected = await showModalBottomSheet<DialCountry>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  sheetContext.l10n.authDialCode,
                  style: AppTypography.h5,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kDialCountries.length,
                  itemBuilder: (_, index) {
                    final country = kDialCountries[index];
                    final isSelected =
                        country.countryCode == _dialCountry.countryCode;
                    return ListTile(
                      leading: SizedBox(
                        width: 36,
                        child: Text(
                          country.countryCode,
                          style: AppTypography.bodyStrong.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      title: Text(country.name, style: AppTypography.body),
                      trailing: Text(
                        country.dialCode,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () => Navigator.of(sheetContext).pop(country),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _dialCountry = selected);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final String identifier;
    final IdentifierChannel channel;
    if (_isPhone) {
      identifier = toE164(_dialCountry.dialCode, raw);
      channel = IdentifierChannel.sms;
    } else {
      identifier = raw.toLowerCase();
      channel = IdentifierChannel.email;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(authProvider.notifier)
          .requestCode(identifier: identifier, channel: channel);
      if (!mounted) return;
      context.goNamed(
        AppRoute.authCode,
        extra: CodeArgs(identifier: identifier, channel: channel),
      );
    } catch (_) {
      if (!mounted) return;
      _showError();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _social(_SocialProvider provider) async {
    if (_busy) return;
    setState(() => _socialBusy = true);
    try {
      final notifier = ref.read(authProvider.notifier);
      final session = switch (provider) {
        _SocialProvider.google => await notifier.signInWithGoogle(),
        _SocialProvider.apple => await notifier.signInWithApple(),
      };
      if (!mounted) return;
      context.goNamed(
        session.isNewUser ? AppRoute.profileEdit : AppRoute.home,
      );
    } catch (_) {
      if (!mounted) return;
      _showError();
    } finally {
      if (mounted) setState(() => _socialBusy = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.errorGeneric)),
    );
  }
}

/// Fournisseurs de connexion sociale gérés par l'écran.
enum _SocialProvider { google, apple }

/// Bouton compact affichant l'indicatif sélectionné, ouvre le sélecteur de pays.
class _DialCodeButton extends StatelessWidget {
  const _DialCodeButton({required this.country, required this.onTap});

  final DialCountry country;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: AppRadius.field,
      child: InkWell(
        borderRadius: AppRadius.field,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.field,
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                country.countryCode,
                style: AppTypography.bodyStrong.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(country.dialCode, style: AppTypography.bodyStrong),
              Icon(Icons.arrow_drop_down, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
