import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/legal_acceptance_recorder.dart';
import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../state/auth_providers.dart';
import '../state/legal_providers.dart';
import '../state/sync_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/legal_document_body.dart';

/// **La barrière de consentement** — `/legal/accept`, l'écran le plus
/// contraignant de l'application.
///
/// On y arrive par le `redirect` du routeur, **jamais** par une navigation
/// explicite ; on en sort de la même façon, quand la garde se réévalue. L'écran
/// ne pousse ni ne dépile aucune route : c'est le motif déjà suivi par la
/// déconnexion, à l'envers.
///
/// ## Aucune sortie, et c'est le point
///
/// `PopScope(canPop: false)` coupe le retour Android et le geste iOS ; il n'y a
/// ni app bar, ni croix, ni « Plus tard ». Un consentement qu'on peut sauter
/// n'en est pas un (ADR-0036), et les trois emplacements « évidents » — écran
/// du code, formulaire de profil, bandeau d'accueil — ont tous été écartés
/// pour cette raison ou pour leur incapacité à traiter la **re-acceptation**.
///
/// ## Une case par document exigé
///
/// La liste vient de [pendingLegalAcceptancesProvider], pas de la liste des
/// genres : si seule la politique a changé, il y a **une** case et **un**
/// document. Les cases ne sont jamais précochées — une case précochée n'est
/// pas un consentement —, et le bouton reste inactif tant que tout n'est pas
/// coché.
///
/// ## Hors ligne : lisible, mais bloquant
///
/// Le texte vient du magasin, il se lit en avion — c'est précisément ce que la
/// collection synchronisée achète. L'accord, lui, exige le réseau : pas de file
/// d'envoi, pas d'état « accepté, non confirmé » (ADR-0036, décision 2).
/// L'échec se dit en clair, **les cases restent cochées**, et l'application
/// reste inaccessible tant que le `POST` n'a pas abouti.
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  /// La colonne de contenu, pour que les tests la désignent sans deviner.
  static const Key contentKey = Key('legal_acceptance_content');

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  /// Les genres cochés. **État purement local** (CLAUDE.md, « Riverpod = état
  /// partagé ») : personne d'autre que cet écran n'a à savoir où en est la
  /// main du fidèle.
  final Set<String> _checked = {};

  /// Envoi en cours — le bouton tourne, les cases ne bougent plus.
  bool _sending = false;

  /// Le dernier refus, s'il y en a eu un. **Un code, jamais un message
  /// serveur** : les quatre cas ont chacun leur phrase, et aucun refus ne sort
  /// en brut sur l'écran dont on ne peut pas sortir.
  LegalAcceptanceErrorCode? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final pending = ref.watch(pendingLegalAcceptancesProvider);
    final user = ref.watch(authProvider).user;

    // Le titre se déduit de la présence d'une acceptation **antérieure**, pas
    // du nombre de documents exigés : dire « nos conditions ont changé » à
    // quelqu'un qui n'en a jamais lu aucune lui ferait chercher ce qu'il a
    // manqué.
    final firstTime = user?.acceptedLegal.isEmpty ?? true;

    // Les documents à faire accepter, résolus depuis le magasin. `null` = pas
    // encore reçu ; la garde ne peut normalement pas nous amener ici dans ce
    // cas (sans document, pas de plancher, donc pas de barrière), mais un
    // document qui s'effacerait sous nos pieds doit désarmer le bouton plutôt
    // que faire signer un texte absent.
    final documents = <String, LegalDocumentView?>{
      for (final kind in pending)
        kind: ref.watch(legalDocumentProvider(kind)).value,
    };
    final ready = documents.values.every((document) => document != null);
    final allChecked = pending.every(_checked.contains);

    return PopScope(
      // **Aucune sortie.** Retour Android, geste iOS, `context.pop()` : tous
      // inertes. C'est le seul écran de l'application dans ce cas.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            key: LegalAcceptanceScreen.contentKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            children: [
              Text(
                firstTime
                    ? l10n.legalGateTitleFirst
                    : l10n.legalGateTitleUpdated,
                style: AppTypography.h2.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.legalGateSubtitle,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              for (final kind in pending)
                if (documents[kind] case final document?)
                  LegalDocumentBody(document: document),
              const SizedBox(height: AppSpacing.md),
              for (final kind in pending)
                _AcceptanceCheckbox(
                  kind: kind,
                  label: _acceptLabel(context, kind),
                  value: _checked.contains(kind),
                  // Pendant l'envoi, les cases se figent : décocher au milieu
                  // d'un aller-retour ne dirait rien au serveur et laisserait
                  // un écran qui se contredit.
                  onChanged:
                      _sending ? null : (checked) => _toggle(kind, checked),
                ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                _RefusalNotice(
                  error: error,
                  onRetry: _sending ? null : () => _submit(documents),
                  onReload: _sending ? null : _reload,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.actionContinue,
                loading: _sending,
                onPressed:
                    allChecked && ready && pending.isNotEmpty && !_sending
                        ? () => _submit(documents)
                        : null,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  /// Le libellé de la case d'un genre. Deux genres, deux phrases — jamais une
  /// phrase à trous : « J'ai lu et j'accepte {document} » ne se traduit pas.
  String _acceptLabel(BuildContext context, String kind) =>
      kind == LegalDocumentKind.privacy
          ? context.l10n.legalGateAcceptPrivacy
          : context.l10n.legalGateAcceptTerms;

  void _toggle(String kind, bool checked) {
    setState(() {
      if (checked) {
        _checked.add(kind);
      } else {
        _checked.remove(kind);
      }
    });
  }

  /// L'envoi — **un seul appel pour tous les documents cochés**, parce que le
  /// serveur écrit dans une transaction (voir `LegalAcceptanceRecorder`).
  ///
  /// La **version envoyée est celle du document affiché**, jamais son plancher :
  /// c'est le texte lu qui s'accepte, et le serveur refuse tout ce qui n'est
  /// pas la dernière édition publiée.
  ///
  /// Au succès, **aucune navigation** : `applyAcceptedLegal` republie la
  /// session avec le résumé que porte la réponse, la garde se réévalue, et
  /// l'écran se retire de lui-même.
  Future<void> _submit(Map<String, LegalDocumentView?> documents) async {
    final accepts = <LegalAcceptance>[
      for (final entry in documents.entries)
        if (entry.value case final document?)
          LegalAcceptance(kind: entry.key, version: document.version),
    ];
    if (accepts.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final accepted =
          await ref.read(legalAcceptanceRecorderProvider).accept(accepts);
      await ref.read(authProvider.notifier).applyAcceptedLegal(accepted);
      // L'écran est très probablement déjà démonté ici — c'est le résultat
      // attendu, pas un accident.
      if (!mounted) return;
      setState(() => _sending = false);
    } on LegalAcceptanceException catch (failure) {
      if (!mounted) return;
      // **Les cases restent cochées**, dans les quatre cas : la saisie reste à
      // l'écran, comme au composeur d'annonces.
      setState(() {
        _sending = false;
        _error = failure.code;
      });
    }
  }

  /// L'issue du refus 422 : redemander le document au serveur.
  ///
  /// Un cycle de synchronisation, et **surtout pas** un `ref.invalidate` du
  /// document : invalider ferait repasser le flux par un état sans valeur, donc
  /// sans plancher, donc sans barrière — la garde ouvrirait l'application le
  /// temps d'un battement, exactement ce que cet écran existe pour empêcher.
  /// Le magasin réécrit sous nos pieds tout seul, c'est ce qu'achète le
  /// `Stream`.
  void _reload() {
    setState(() => _error = null);
    unawaited(ref.read(pullToRefreshProvider)());
  }
}

/// Une case, et le texte qu'elle engage.
///
/// Toute la ligne est cliquable (`CheckboxListTile`) : viser une case de 18
/// points au pouce, sur un écran dont on ne peut pas sortir, serait une
/// mauvaise plaisanterie.
class _AcceptanceCheckbox extends StatelessWidget {
  const _AcceptanceCheckbox({
    required this.kind,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String kind;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CheckboxListTile(
      key: Key('legal_accept_$kind'),
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTypography.body.copyWith(color: palette.textPrimary),
      ),
    );
  }
}

/// Le refus, en une phrase et au plus une issue.
///
/// **Quatre cas, quatre phrases**, et aucune ne laisse passer un code HTTP ni
/// un message du serveur :
///
/// | cas | phrase | issue |
/// | --- | --- | --- |
/// | réseau absent | « Connexion requise… » | Réessayer |
/// | 401 | session expirée | *aucune* — la garde renvoie à `/auth` |
/// | 422 | « Ces conditions ont été mises à jour. » | Recharger |
/// | 5xx | « Le serveur n'a pas pu… » | Réessayer |
class _RefusalNotice extends StatelessWidget {
  const _RefusalNotice({
    required this.error,
    required this.onRetry,
    required this.onReload,
  });

  final LegalAcceptanceErrorCode error;
  final VoidCallback? onRetry;
  final VoidCallback? onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final message = switch (error) {
      LegalAcceptanceErrorCode.network => l10n.legalGateErrorNetwork,
      LegalAcceptanceErrorCode.unauthorized => l10n.legalGateErrorUnauthorized,
      LegalAcceptanceErrorCode.outdated => l10n.legalGateErrorOutdated,
      LegalAcceptanceErrorCode.server => l10n.legalGateErrorServer,
    };

    // Le 401 n'a pas d'issue à proposer : le token est déjà purgé, et la garde
    // de route ramène à `/auth` d'elle-même. Un « Réessayer » y promettrait ce
    // qui ne peut pas marcher.
    final action = switch (error) {
      LegalAcceptanceErrorCode.unauthorized => null,
      LegalAcceptanceErrorCode.outdated => (l10n.legalGateReload, onReload),
      _ => (l10n.stateRetry, onRetry),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          // La même teinte d'alerte que l'écran du code : c'est un refus, pas
          // une note de bas de page.
          style: AppTypography.body.copyWith(color: AppColors.danger),
        ),
        if (action case (final label, final onPressed)) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: label,
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: onPressed,
          ),
        ],
      ],
    );
  }
}
