import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/my_requests_repository.dart';
import '../l10n/l10n_extension.dart';
import '../models/my_request_view.dart';
import '../state/requests_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/community/my_requests_tab.dart';
import '../widgets/menu_tile.dart';
import '../widgets/selectable_option.dart';

/// Écran « Nouvelle requête » : demande de prière, suggestion ou réclamation.
///
/// **Il envoie pour de vrai depuis #148** (`POST /interactions`). Il n'était
/// jusque-là qu'une maquette : quatre genres dont deux inconnus du serveur
/// (« Signalement », « Autre »), aucun objet alors que le serveur en exige un,
/// et un bouton « Envoyer » qui fermait l'écran sans rien envoyer.
///
/// Après un envoi réussi, l'écran **déclenche un cycle de synchronisation**
/// sans l'attendre, puis se ferme : c'est ce cycle qui ramène la requête dans
/// l'onglet Requêtes (ADR-0026 — le réseau ne peint jamais). Le patron est
/// celui du composeur d'annonces.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  /// Le bouton « Envoyer » — exposé pour les tests.
  static const sendButtonKey = ValueKey('new-request-send');

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  static const _kinds = [
    RequestKind.prayer,
    RequestKind.suggestion,
    RequestKind.complaint,
  ];

  /// Longueur minimale de l'objet — celle du validateur serveur
  /// (`submit_interaction_controller.ts`).
  static const _minTitleLength = 3;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  RequestKind _kind = RequestKind.prayer;
  bool _anonymous = true;

  /// Prière seulement — ADR-0014 : `community` par défaut, l'auteur d'une
  /// prière sensible la réserve explicitement à l'équipe pastorale.
  bool _shareWithCommunity = true;

  bool _sending = false;
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String? get _titleError =>
      _submitted && _titleController.text.trim().length < _minTitleLength
          ? context.l10n.newRequestTitleTooShort
          : null;

  String? get _contentError =>
      _submitted && _contentController.text.trim().isEmpty
          ? context.l10n.newRequestContentEmpty
          : null;

  Future<void> _send() async {
    setState(() => _submitted = true);
    if (_titleError != null || _contentError != null) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(requestSubmitterProvider).submit(
            RequestDraft(
              kind: _kind,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              isAnonymous: _anonymous,
              shareWithCommunity: _shareWithCommunity,
            ),
          );
    } on RequestSubmitException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == RequestSubmitErrorCode.network
                ? l10n.newRequestErrorNetwork
                : l10n.newRequestErrorGeneric,
          ),
        ),
      );
      return;
    }

    // Le cycle ramène la requête dans l'onglet ; on ne le fait pas attendre.
    unawaited(ref.read(pullToRefreshProvider)());
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.newRequestSent)));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: BrandAppBar(title: l10n.newRequestAppBarTitle),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(l10n.newRequestTypeLabel, style: AppTypography.h5),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < _kinds.length; i++) ...[
                    RadioOptionTile(
                      label: requestKindLabel(_kinds[i], l10n)!,
                      selected: _kinds[i] == _kind,
                      onTap: () => setState(() => _kind = _kinds[i]),
                    ),
                    if (i < _kinds.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: l10n.newRequestTitleLabel,
              hint: l10n.newRequestTitleHint,
              controller: _titleController,
              errorText: _titleError,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l10n.newRequestDescribeLabel,
              hint: l10n.newRequestDescribeHint,
              controller: _contentController,
              errorText: _contentError,
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xl),
            LabeledSwitch(
              label: l10n.anonymousLabel,
              subtitle: l10n.anonymousSubtitle,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            if (_kind == RequestKind.prayer) ...[
              const SizedBox(height: AppSpacing.md),
              LabeledSwitch(
                label: l10n.newRequestShareLabel,
                subtitle: l10n.newRequestShareSubtitle,
                value: _shareWithCommunity,
                onChanged: (v) => setState(() => _shareWithCommunity = v),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              key: NewRequestScreen.sendButtonKey,
              label: l10n.actionSend,
              loading: _sending,
              onPressed: _sending ? null : _send,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
