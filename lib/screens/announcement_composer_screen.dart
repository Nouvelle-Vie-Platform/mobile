import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/announcement_composer.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/announcement_draft.dart';
import '../state/announcement_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_alert.dart';
import '../widgets/app_button.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_text_field.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/content_absence.dart';
import '../widgets/segmented_tabs.dart';
import '../widgets/selectable_option.dart';

/// **Le composeur d'annonce** — création et modification.
///
/// Un seul écran pour les deux gestes, distingués par [announcementId] : les
/// champs, les règles de validité et le traitement des refus sont exactement les
/// mêmes, et deux écrans jumeaux auraient divergé au premier correctif.
///
/// **Il n'existe que pour une poignée de personnes.** L'affordance qui y mène
/// est montée sur `canComposeAnnouncementProvider` ; pour l'écrasante majorité
/// des fidèles, l'onglet Annonces reste une visionneuse sans aucune trace
/// d'écriture — pas de bouton grisé, pas de menu caché.
///
/// **Trois choses que cet écran ne fait pas, et c'est le cœur du ticket :**
///
/// 1. **Il n'écrit pas dans le magasin local.** Après un envoi réussi, il
///    déclenche un cycle de synchronisation et rend la main : c'est le flux
///    delta qui ramène l'annonce (ADR-0026 — le réseau ne peint jamais). Écrire
///    la ligne nous-mêmes demanderait d'inventer un identifiant, une branche
///    dérivée et un horodatage.
/// 2. **Il ne met rien en file d'attente.** L'écriture exige le réseau
///    (ADR-0031) : hors ligne, il le **dit** et garde la saisie à l'écran. Un
///    brouillon local rejouerait « publier maintenant » trois jours plus tard,
///    ce qui n'a aucune bonne interprétation.
/// 3. **Il ne s'appuie pas sur l'appartenance locale comme sur un droit.** Le
///    serveur revérifie à chaque écriture ; un membre retiré du bureau arrive
///    jusqu'ici et reçoit un 403, qui est traité comme un cas normal — message
///    lisible, saisie conservée.
class AnnouncementComposerScreen extends ConsumerStatefulWidget {
  const AnnouncementComposerScreen({super.key, this.announcementId});

  /// `null` = création. Sinon, l'annonce à modifier — désignée par son
  /// **identifiant**, jamais par un objet passé en `extra` : l'écran la résout
  /// dans le magasin à chaque `build`, et voit donc une rétractation arriver
  /// pendant qu'on la corrige.
  final String? announcementId;

  bool get isEditing => announcementId != null;

  @override
  ConsumerState<AnnouncementComposerScreen> createState() =>
      _AnnouncementComposerScreenState();
}

class _AnnouncementComposerScreenState
    extends ConsumerState<AnnouncementComposerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  int? _accountId;
  int? _backgroundId;
  PublicationTiming _timing = PublicationTiming.now;
  DateTime? _publishedAt;
  DateTime? _expiresAt;
  StatusImageUpload? _image;
  bool _hasBackgroundImage = false;

  /// L'annonce rouverte porte un audio ou une vidéo : il compte comme contenu
  /// (voir [AnnouncementDraft.hasMedia]).
  bool _hasMedia = false;

  /// Envoi en cours : le bouton tourne et le formulaire ne part pas deux fois.
  bool _sending = false;

  /// Ce que la dernière tentative a reproché au brouillon. Vide tant qu'on n'a
  /// pas essayé d'envoyer : signaler « rien à publier » sur un formulaire qu'on
  /// vient d'ouvrir serait un reproche avant l'acte.
  Set<DraftIssue> _issues = const {};

  /// Le dernier refus du serveur, gardé **à l'écran avec la saisie**.
  AnnouncementWriteException? _failure;

  /// Le préremplissage n'a lieu qu'une fois.
  ///
  /// Le magasin réémet à chaque cycle de synchronisation ; sans ce garde-fou,
  /// une synchronisation survenue pendant la frappe écraserait le texte en cours
  /// par celui du serveur, au milieu d'une phrase.
  bool _prefilled = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  // ── Construction du brouillon ────────────────────────────────────────────

  /// Le brouillon tel qu'il partirait maintenant.
  ///
  /// Le `trim` et le repli sur `null` sont faits par [AnnouncementDraft] : ils
  /// sont écrits **une fois**, du côté du modèle, et pas recopiés dans chaque
  /// écran qui saisit du texte.
  AnnouncementDraft? _draft() {
    final accountId = _accountId;
    if (accountId == null) return null;
    return AnnouncementDraft(
      accountId: accountId,
      title: _titleController.text,
      body: _bodyController.text,
      backgroundId: _backgroundId,
      timing: _timing,
      publishedAt: _publishedAt,
      expiresAt: _expiresAt,
      image: _image,
      hasBackgroundImage: _hasBackgroundImage,
      hasMedia: _hasMedia,
    );
  }

  Future<void> _submit() async {
    final draft = _draft();
    if (draft == null || _sending) return;

    final issues = draft.issuesAt(DateTime.now().toUtc());
    if (issues.isNotEmpty) {
      setState(() {
        _issues = issues;
        _failure = null;
      });
      return;
    }

    setState(() {
      _issues = const {};
      _failure = null;
      _sending = true;
    });

    final composer = ref.read(announcementComposerProvider);
    final id = widget.announcementId;
    // Le libellé de confirmation se lit **avant** l'envoi : `context.l10n` après
    // un `await` traverse un point où l'écran a pu être démonté.
    final confirmation = id == null
        ? context.l10n.composerPublished
        : context.l10n.composerUpdated;
    try {
      if (id == null) {
        await composer.create(draft);
      } else {
        await composer.update(id: id, draft: draft);
      }
      _afterWrite(confirmation);
    } on AnnouncementWriteException catch (e) {
      if (!mounted) return;
      // La saisie reste intacte : elle est dans les contrôleurs, et rien ici ne
      // les touche. C'est tout l'intérêt de porter l'échec dans l'état plutôt
      // que de fermer l'écran sur un message.
      setState(() {
        _failure = e;
        _sending = false;
      });
    }
  }

  Future<void> _delete() async {
    final id = widget.announcementId;
    if (id == null || _sending) return;
    final confirmation = context.l10n.composerDeleted;
    if (!await _confirmDelete()) return;
    if (!mounted) return;

    setState(() {
      _failure = null;
      _sending = true;
    });
    try {
      await ref.read(announcementComposerProvider).remove(id);
      _afterWrite(confirmation);
    } on AnnouncementWriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _sending = false;
      });
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.composerDeleteConfirmTitle),
        content: Text(l10n.composerDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.composerDeleteConfirmAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// **Après une écriture réussie** : on tire, puis on rend la main.
  ///
  /// Le cycle de synchronisation est ce qui ramène l'annonce dans le magasin,
  /// donc à l'écran. On ne l'attend pas pour fermer le composeur — un membre du
  /// bureau n'a pas à regarder tourner une roue pendant que le delta descend —
  /// mais on le déclenche tout de suite, sans quoi le mur ne montrerait rien
  /// avant le prochain retour au premier plan.
  void _afterWrite(String message) {
    final refresh = ref.read(pullToRefreshProvider);
    unawaited(refresh());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).maybePop();
  }

  // ── Rendu ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = ref.watch(composerOptionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(
        title:
            widget.isEditing ? l10n.composerEditTitle : l10n.composerNewTitle,
      ),
      body: options.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _centered(
          AppErrorState(onRetry: () => ref.invalidate(composerOptionsProvider)),
        ),
        data: (options) => widget.isEditing
            ? _editing(options)
            : _form(options, showDelete: false),
      ),
    );
  }

  /// En modification, le formulaire attend d'abord la ligne du magasin.
  Widget _editing(ComposerOptions options) {
    return ref.watch(announcementDraftProvider(widget.announcementId!)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _centered(
            AppErrorState(
              onRetry: () => ref.invalidate(
                announcementDraftProvider(widget.announcementId!),
              ),
            ),
          ),
          data: (draft) {
            if (draft == null) {
              // Une annonce retirée pendant qu'on l'ouvrait : une **absence**,
              // pas une panne. On n'éjecte pas, on explique, on laisse la porte.
              return ContentAbsenceView(
                absence: ContentAbsence.retracted,
                title: context.l10n.composerMissingTitle,
                message: context.l10n.composerMissingBody,
              );
            }
            _prefillOnce(draft);
            return _form(options, showDelete: true);
          },
        );
  }

  void _prefillOnce(AnnouncementDraft draft) {
    if (_prefilled) return;
    _prefilled = true;
    _titleController.text = draft.title ?? '';
    _bodyController.text = draft.body ?? '';
    _accountId = draft.accountId;
    _backgroundId = draft.backgroundId;
    _timing = draft.timing;
    _publishedAt = draft.publishedAt?.toLocal();
    _expiresAt = draft.expiresAt?.toLocal();
    _hasBackgroundImage = draft.hasBackgroundImage;
    _hasMedia = draft.hasMedia;
  }

  Widget _form(ComposerOptions options, {required bool showDelete}) {
    final l10n = context.l10n;

    if (options.accounts.isEmpty) {
      // L'affordance est montée sur les **appartenances**, la liste sur les
      // **comptes** : les deux collections se synchronisent séparément, et une
      // appartenance dont le compte n'est pas encore arrivé ne peut pas être
      // nommée. Une fenêtre de synchronisation, jamais une erreur.
      return ContentAbsenceView(
        absence: ContentAbsence.notSynced,
        title: l10n.composerNoAccountTitle,
        message: l10n.composerNoAccountBody,
      );
    }

    // Premier compte par défaut, et son fond par défaut avec lui : le cas
    // dominant est un membre d'un seul compte, qui n'a alors rien à choisir.
    if (_accountId == null ||
        !options.accounts.any((account) => account.id == _accountId)) {
      final first = options.accounts.first;
      _accountId = first.id;
      _backgroundId ??= first.backgroundId;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        if (_failure != null) ...[
          _FailureBanner(failure: _failure!),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_issues.isNotEmpty) ...[
          _IssuesBanner(issues: _issues),
          const SizedBox(height: AppSpacing.lg),
        ],
        _AccountPicker(
          accounts: options.accounts,
          selected: _accountId,
          onSelect: (account) => setState(() {
            _accountId = account.id;
            _backgroundId ??= account.backgroundId;
          }),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          key: composerTitleKey,
          label: l10n.composerTitleLabel,
          hint: l10n.composerTitleHint,
          controller: _titleController,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          key: composerBodyKey,
          label: l10n.composerBodyLabel,
          hint: l10n.composerBodyHint,
          controller: _bodyController,
          maxLines: 5,
        ),
        const SizedBox(height: AppSpacing.lg),
        _BackgroundPicker(
          backgrounds: options.backgrounds,
          selected: _backgroundId,
          onSelect: (id) => setState(() => _backgroundId = id),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ImageField(
          image: _image,
          hasBackgroundImage: _hasBackgroundImage,
          onPick: _pickImage,
          onClear: () => setState(() => _image = null),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TimingField(
          timing: _timing,
          publishedAt: _publishedAt,
          onTiming: (timing) => setState(() => _timing = timing),
          onPick: () => _pickInstant(
            current: _publishedAt,
            onPicked: (value) => setState(() {
              _publishedAt = value;
              _timing = PublicationTiming.scheduled;
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ExpiryField(
          expiresAt: _expiresAt,
          onPick: () => _pickInstant(
            current: _expiresAt,
            onPicked: (value) => setState(() => _expiresAt = value),
          ),
          onClear: () => setState(() => _expiresAt = null),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          key: composerSubmitKey,
          label: widget.isEditing ? l10n.composerSave : l10n.composerPublish,
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _submit,
        ),
        if (showDelete) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            key: composerDeleteKey,
            label: l10n.composerDelete,
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.outline,
            onPressed: _sending ? null : _delete,
          ),
        ],
      ],
    );
  }

  Future<void> _pickImage() async {
    final picked = await ref.read(statusImagePickerProvider).pick();
    if (!mounted || picked == null) return;
    setState(() => _image = picked);
  }

  /// Une date **et** une heure : un statut programmé à « demain » sans heure
  /// paraîtrait à minuit, quand personne ne regarde.
  Future<void> _pickInstant({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final start = current ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: start.isBefore(now) ? now : start,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (!mounted || time == null) return;
    onPicked(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  Widget _centered(Widget child) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      );
}

/// Clés de test des trois commandes du formulaire.
///
/// Ciblées par clé et non par libellé : un test qui cherche « Publier »
/// trouverait aussi le titre de l'écran le jour où il change.
@visibleForTesting
const Key composerTitleKey = Key('composer-title');
@visibleForTesting
const Key composerBodyKey = Key('composer-body');
@visibleForTesting
const Key composerSubmitKey = Key('composer-submit');
@visibleForTesting
const Key composerDeleteKey = Key('composer-delete');

/// Le refus du serveur, **en langage humain**.
///
/// Jamais un code HTTP, jamais un `toString()` d'exception. Le message du
/// serveur n'est repris que pour le 422, où il dit précisément quel champ ne va
/// pas ; partout ailleurs, l'application a son propre texte, écrit pour un
/// non-technicien.
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final AnnouncementWriteException failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, fallback) = switch (failure.code) {
      AnnouncementWriteErrorCode.network => (
          l10n.composerErrorNetworkTitle,
          l10n.composerErrorNetworkBody,
        ),
      AnnouncementWriteErrorCode.unauthorized => (
          l10n.composerErrorUnauthorizedTitle,
          l10n.composerErrorUnauthorizedBody,
        ),
      AnnouncementWriteErrorCode.forbidden => (
          l10n.composerErrorForbiddenTitle,
          l10n.composerErrorForbiddenBody,
        ),
      AnnouncementWriteErrorCode.rejected => (
          l10n.composerErrorRejectedTitle,
          l10n.composerErrorRejectedBody,
        ),
      AnnouncementWriteErrorCode.gone => (
          l10n.composerErrorGoneTitle,
          l10n.composerErrorGoneBody,
        ),
      AnnouncementWriteErrorCode.server ||
      AnnouncementWriteErrorCode.unknown =>
        (l10n.composerErrorServerTitle, l10n.composerErrorServerBody),
    };

    // Seul le 422 mérite le message du serveur : c'est le seul cas où il parle
    // du contenu saisi plutôt que de l'infrastructure.
    final message = failure.code == AnnouncementWriteErrorCode.rejected
        ? (failure.message ?? fallback)
        : fallback;

    return AppAlert(
      type: AppAlertType.danger,
      title: title,
      message: message,
    );
  }
}

/// Ce qui manque au brouillon, dit avant tout appel réseau.
class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner({required this.issues});

  final Set<DraftIssue> issues;

  static String _label(AppLocalizations l10n, DraftIssue issue) =>
      switch (issue) {
        DraftIssue.nothingToPublish => l10n.composerIssueNothing,
        DraftIssue.missingSchedule => l10n.composerIssueSchedule,
        DraftIssue.expiryBeforePublication => l10n.composerIssueExpiry,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlert(
      type: AppAlertType.warning,
      title: l10n.composerNewTitle,
      message: issues.map((issue) => _label(l10n, issue)).join('\n'),
    );
  }
}

/// **Publier au nom de** — le sélecteur de compte officiel.
///
/// Il n'y a **pas** de sélecteur de branche à côté : choisir le compte *est*
/// choisir la portée, et le serveur la dérive. Un membre qui pourrait désigner
/// une branche signerait une annonce nationale du nom de son comité local.
///
/// Avec un seul compte — le cas dominant — la ligne s'affiche sans radio : ce
/// n'est plus un choix, c'est une information.
class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selected,
    required this.onSelect,
  });

  final List<ComposerAccount> accounts;
  final int? selected;
  final ValueChanged<ComposerAccount> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.composerAccountLabel, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        if (accounts.length == 1)
          Text(accounts.single.name, style: AppTypography.bodyLarge)
        else
          for (final account in accounts)
            RadioOptionTile(
              label: account.name,
              selected: account.id == selected,
              onTap: () => onSelect(account),
            ),
        if (accounts.length > 1)
          Divider(color: palette.divider, height: AppSpacing.lg),
      ],
    );
  }
}

/// **Le sélecteur de fond** : les lignes actives de `status_backgrounds`, dans
/// l'ordre du portail.
///
/// Chaque pastille peint les **trois arrêts servis** — le serveur les a dérivés
/// à l'écriture (ADR-0030), le client ne calcule aucune couleur. Les fonds
/// désactivés n'y figurent pas, mais restent peints sur les annonces qui les
/// portent : c'est le magasin qui les garde, pas ce sélecteur.
class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.backgrounds,
    required this.selected,
    required this.onSelect,
  });

  final List<StatusBackgroundOption> backgrounds;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.composerBackgroundLabel, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Swatch(
              label: l10n.composerBackgroundNone,
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            for (final background in backgrounds)
              _Swatch(
                label: background.label,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(background.backdrop.topColor),
                    Color(background.backdrop.bottomColor),
                  ],
                ),
                selected: background.id == selected,
                onTap: () => onSelect(background.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.gradient,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
                color: gradient == null ? palette.surfaceAlt : null,
                border: Border.all(color: palette.border),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

/// **L'image de fond.**
///
/// Une **affiche** — image seule, sans titre ni corps — est une annonce
/// parfaitement valide, et c'est le cas le plus courant en pratique : le champ
/// n'est donc pas un ornement de fin de formulaire.
///
/// L'aperçu se peint depuis les octets déjà lus (`Image.memory`), jamais depuis
/// le réseau : l'image n'a pas encore d'URL, et n'en aura qu'après l'envoi.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.image,
    required this.hasBackgroundImage,
    required this.onPick,
    required this.onClear,
  });

  final StatusImageUpload? image;
  final bool hasBackgroundImage;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chosen = image;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.composerImageLabel, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        if (chosen != null) ...[
          ClipRRect(
            borderRadius: AppRadius.card,
            child: Image.memory(
              chosen.bytes,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              // Une image illisible (fichier corrompu, format exotique) ne doit
              // pas casser le formulaire : on retombe sur l'absence d'aperçu, et
              // le serveur tranchera à l'envoi.
              errorBuilder: (context, _, __) => const SizedBox(height: 160),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ] else if (hasBackgroundImage) ...[
          Text(
            l10n.composerImageKept,
            style: AppTypography.caption
                .copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: composerPickImageKey,
                label: chosen == null
                    ? l10n.composerImageAdd
                    : l10n.composerImageReplace,
                icon: Icons.image_outlined,
                variant: AppButtonVariant.outline,
                onPressed: onPick,
              ),
            ),
            if (chosen != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: l10n.composerImageRemove,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

@visibleForTesting
const Key composerPickImageKey = Key('composer-pick-image');

/// **Les trois modes de publication**, sur un seul champ.
class _TimingField extends StatelessWidget {
  const _TimingField({
    required this.timing,
    required this.publishedAt,
    required this.onTiming,
    required this.onPick,
  });

  final PublicationTiming timing;
  final DateTime? publishedAt;
  final ValueChanged<PublicationTiming> onTiming;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.composerTimingLabel, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        SegmentedTabs(
          tabs: [
            l10n.composerTimingNow,
            l10n.composerTimingScheduled,
            l10n.composerTimingDraft,
          ],
          selected: PublicationTiming.values.indexOf(timing),
          onSelect: (index) => onTiming(PublicationTiming.values[index]),
        ),
        if (timing == PublicationTiming.scheduled) ...[
          const SizedBox(height: AppSpacing.sm),
          _InstantRow(
            label: l10n.composerScheduleLabel,
            value: publishedAt,
            action: l10n.composerSchedulePick,
            onPick: onPick,
          ),
        ],
      ],
    );
  }
}

/// La fin de publication, **facultative** : `null` = n'expire jamais, le défaut.
class _ExpiryField extends StatelessWidget {
  const _ExpiryField({
    required this.expiresAt,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? expiresAt;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.composerExpiryLabel, style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        _InstantRow(
          label: expiresAt == null ? l10n.composerExpiryNever : '',
          value: expiresAt,
          action: expiresAt == null
              ? l10n.composerExpiryPick
              : l10n.composerExpiryClear,
          onPick: expiresAt == null ? onPick : onClear,
        ),
      ],
    );
  }
}

/// Une ligne « valeur choisie + action », partagée par la programmation et
/// l'expiration.
///
/// L'instant se rend par [MaterialLocalizations] : la date et l'heure sont des
/// **données**, et leur format appartient à la locale du lecteur — jamais à une
/// chaîne écrite ici.
class _InstantRow extends StatelessWidget {
  const _InstantRow({
    required this.label,
    required this.value,
    required this.action,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final String action;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final shown = value == null
        ? label
        : '${material.formatMediumDate(value!)} · '
            '${material.formatTimeOfDay(TimeOfDay.fromDateTime(value!))}';

    return Row(
      children: [
        Expanded(child: Text(shown, style: AppTypography.body)),
        TextButton(onPressed: onPick, child: Text(action)),
      ],
    );
  }
}
