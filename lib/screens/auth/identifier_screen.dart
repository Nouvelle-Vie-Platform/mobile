import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/auth_channels.dart';
import '../../models/models.dart';
import '../../router/app_router.dart';
import '../../state/auth_channels_providers.dart';
import '../../state/auth_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dial_codes.dart';
import '../../utils/i18n_text.dart';

/// `/auth/identifier` : saisie de l'identifiant, envoi du code.
///
/// ## Le sélecteur n'est pas une préférence, c'est une **offre** (#83)
///
/// Les canaux ouverts sont ceux que le portail déclare (collection
/// `auth_channels`, servie **sans compte**). Deux canaux ouverts ⇒ le sélecteur
/// **Téléphone / Email**, e-mail présélectionné comme avant. Un seul ⇒ **pas de
/// sélecteur du tout** : on ne grise pas une option, on ne la propose pas — et
/// l'annonce du portail prend la place du sous-titre pour dire par où le code
/// arrivera. Le sous-titre du dépôt (« votre numéro ou votre email ») nommerait
/// sinon un canal que l'écran ne propose pas, c'est-à-dire la promesse même que
/// cette tranche existe pour retirer.
///
/// **Avant le premier cycle de synchronisation, l'offre est l'e-mail seul**
/// (`AuthChannelOffer.emailOnly`) — jamais « tous les canaux ». Voir
/// `state/auth_channels_providers.dart`.
///
/// ⚠️ Le canal retenu est **dérivé à chaque `build`** et non lu dans l'état :
/// une synchronisation peut fermer, sous les yeux du fidèle, le canal qu'il
/// venait de sélectionner, et un drapeau figé lui laisserait un champ qui
/// n'enverra rien.
///
/// En mode téléphone, un sélecteur d'indicatif (déduit du locale, repli +228)
/// précède le champ et l'identifiant est normalisé en **E.164** ; en mode email,
/// l'adresse est mise en minuscules. Cette normalisation est un confort
/// d'ergonomie : le serveur re-normalise de son côté et ne s'y fie pas.
/// « Continuer » demande un code puis pousse [CodeScreen].
///
/// **Aucun bouton social, et le séparateur « Ou continuer avec » reste
/// endormi** : hors périmètre par décision écrite (`docs/auth-contract.md`).
/// N'offrir que l'e-mail ne déclenche pas la règle App Store 4.8 — c'est
/// *ajouter* Google qui *crée* l'obligation d'offrir « Sign in with Apple ».
class IdentifierScreen extends ConsumerStatefulWidget {
  const IdentifierScreen({super.key});

  @override
  ConsumerState<IdentifierScreen> createState() => _IdentifierScreenState();
}

class _IdentifierScreenState extends ConsumerState<IdentifierScreen> {
  final _controller = TextEditingController();

  /// Onglet **choisi par le fidèle**, quand il y a quelque chose à choisir.
  ///
  /// **Email par défaut**, comme avant #83 : c'est le canal qui envoie
  /// réellement un code. Cette valeur ne fait foi que si les deux canaux sont
  /// ouverts — sinon c'est l'offre qui décide, et [_channelOf] est le seul
  /// endroit qui tranche.
  bool _isPhone = false;

  /// Indicatif sélectionné (initialisé depuis le locale appareil).
  late DialCountry _dialCountry;

  /// Envoi du code en cours : désactive les actions, spinner sur « Continuer ».
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final offer = ref.watch(authChannelOfferProvider);
    final isPhone = _channelOf(offer) == IdentifierChannel.phone;

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
                // Un seul canal : le sous-titre du dépôt nommerait « votre
                // numéro ou votre email », donc un canal que l'écran ne propose
                // pas. C'est l'annonce qui parle à sa place.
                offer.offersChoice
                    ? l.authIdentifierSubtitle
                    : _notice(context, offer, isPhone: isPhone),
                style: AppTypography.bodyLarge.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // **Rien à choisir ⇒ rien à proposer.** Pas de sélecteur grisé :
              // une option désactivée reste une option offerte, et c'est encore
              // une promesse que personne ne tiendra.
              if (offer.offersChoice) ...[
                _buildToggle(l),
                const SizedBox(height: AppSpacing.lg),
              ],
              isPhone ? _buildPhoneField(l) : _buildEmailField(l),
              const SizedBox(height: AppSpacing.xl),
              _buildContinueButton(l),
            ],
          ),
        ),
      ),
    );
  }

  /// **Le canal retenu**, et le seul endroit qui le décide.
  ///
  /// Les deux canaux ouverts : c'est le fidèle qui choisit ([_isPhone], e-mail
  /// par défaut). Un seul : c'est l'offre, quoi qu'ait pu sélectionner le
  /// fidèle avant qu'un cycle de synchronisation ne ferme la porte.
  IdentifierChannel _channelOf(AuthChannelOffer offer) {
    if (!offer.offersChoice) return offer.soleChannel!;
    return _isPhone ? IdentifierChannel.phone : IdentifierChannel.email;
  }

  /// L'annonce affichée quand il n'y a rien à choisir : **celle du portail**,
  /// et à défaut le libellé du dépôt.
  ///
  /// Le repli de langue est `pick` (`utils/i18n_text.dart`), avec la locale
  /// **d'interface** : c'est une phrase de l'application, pas un contenu. `pick`
  /// traite déjà une valeur blanche comme absente et rend `''` quand rien n'est
  /// exploitable — un message vide retombe donc sur le `.arb`, comme une absence
  /// de message. Un bandeau blanc ne ressemble pas à un bug, il ressemble à une
  /// donnée perdue.
  String _notice(
    BuildContext context,
    AuthChannelOffer offer, {
    required bool isPhone,
  }) {
    final notice = offer.notice;
    if (notice != null) {
      final text = pick(notice, Localizations.localeOf(context).languageCode);
      if (text.trim().isNotEmpty) return text;
    }
    final l = context.l10n;
    return isPhone ? l.authNoticePhoneOnly : l.authNoticeEmailOnly;
  }

  Widget _buildToggle(AppLocalizations l) {
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

  Widget _buildPhoneField(AppLocalizations l) {
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
      child: _busy
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

    // Le canal se relit sur l'**offre**, jamais sur le seul drapeau d'état :
    // un cycle de synchronisation a pu fermer, entre le montage et le tap, le
    // canal que le fidèle avait sélectionné.
    final channel = _channelOf(ref.read(authChannelOfferProvider));
    final identifier = channel == IdentifierChannel.phone
        ? toE164(_dialCountry.dialCode, raw)
        : raw.toLowerCase();

    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.errorGeneric)),
    );
  }
}

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
              Text(country.dialCode, style: AppTypography.bodyStrong),
              Icon(Icons.arrow_drop_down, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
