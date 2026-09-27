import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/legal_document_view.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../state/legal_notice_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// **La mention légale du premier lancement** — non bloquante, une seule fois.
///
/// ## Elle n'est pas une décoration. Ne pas la retirer.
///
/// Depuis le mode invité, l'application attribue un **identifiant d'appareil**
/// dès la première ouverture et l'envoie au serveur (`lib/data/devices/`). C'est
/// une donnée personnelle, posée **avant tout compte** — donc avant la barrière
/// de consentement des membres (`/legal/accept`, #56), qui est le seul endroit
/// du dépôt où un accord explicite est recueilli et horodaté. Un invité ne la
/// voit jamais. Ce bandeau est ce qui annonce l'identifiant à ceux-là, et les
/// deux liens sont ce qui rend l'annonce vérifiable.
///
/// ## Trois décisions, dans l'ordre où on les remet en cause
///
/// 1. **Non bloquante, et c'est la décision du client.** Pas de `PopScope`, pas
///    de barrière modale, rien qui capte les gestes hors de sa propre surface :
///    l'accueil reste utilisable derrière, y compris la barre d'onglets et le
///    bouton central. La barrière bloquante existe déjà, elle est réservée aux
///    membres, et elle ne bouge pas.
/// 2. **Aux invités seulement.** Un membre a donné un accord explicite, tracé,
///    et sur un texte qu'il a dû faire défiler ; lui superposer une mention
///    implicite dirait moins que ce qu'il a déjà signé, et contredirait la
///    contrainte du client — « quand la personne s'est déjà connectée, tout se
///    passe exactement comme présentement ». Corollaire assumé : quelqu'un qui
///    se connecte sans avoir fermé le bandeau le retrouvera s'il se déconnecte.
///    C'est le bon sens du drapeau — il retient une *lecture*, pas un passage.
/// 3. **« J'ai compris », jamais « J'accepte ».** Il n'y a ici ni case, ni envoi,
///    ni trace : l'accord d'un invité est implicite par l'usage. Un bouton qui
///    dirait « J'accepte » laisserait croire que ce consentement-là est
///    enregistré quelque part, alors que rien ne part.
///
/// La mémoire est locale et vaut pour l'installation — voir
/// [LegalNoticeStore] (`lib/data/legal_notice_store.dart`).
class LegalNoticeBanner extends ConsumerStatefulWidget {
  const LegalNoticeBanner({super.key});

  /// Le bandeau lui-même. Les tests prouvent surtout son **absence** : au
  /// deuxième lancement, et pour un membre.
  static const Key bannerKey = Key('legal_notice_banner');
  static const Key termsKey = Key('legal_notice_terms');
  static const Key privacyKey = Key('legal_notice_privacy');
  static const Key dismissKey = Key('legal_notice_dismiss');

  @override
  ConsumerState<LegalNoticeBanner> createState() => _LegalNoticeBannerState();
}

class _LegalNoticeBannerState extends ConsumerState<LegalNoticeBanner> {
  /// **La fermeture est immédiate à l'écran, l'écriture suit.**
  ///
  /// Attendre le magasin pour retirer le bandeau ferait un bouton qui met un
  /// battement à répondre, et un bouton qui met un battement à répondre se
  /// presse deux fois. L'écriture, elle, ne peut pas échouer vers l'écran (voir
  /// [LegalNoticeStore.markSeen]).
  bool _dismissed = false;

  void _dismiss() {
    setState(() => _dismissed = true);
    ref.read(legalNoticeStoreProvider).markSeen();
  }

  void _open(String kind) => context.pushNamed(
        AppRoute.legalDocument,
        pathParameters: {'kind': kind},
      );

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    // Un membre n'a rien à lire ici — voir la décision 2 de l'en-tête.
    if (!ref.watch(authProvider).isGuest) return const SizedBox.shrink();
    // `?? true` : sur un `AsyncValue`, `value` est nul en chargement **et** en
    // échec, et les deux valent ici « déjà vu », donc rien à l'écran. Voir
    // `legalNoticeSeenProvider` pour le pourquoi de ce côté-là du défaut.
    final seen = ref.watch(legalNoticeSeenProvider).value ?? true;
    if (seen) return const SizedBox.shrink();

    final l10n = context.l10n;
    final palette = context.palette;

    return Padding(
      key: LegalNoticeBanner.bannerKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Material(
        color: palette.surface,
        borderRadius: AppRadius.card,
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.legalNoticeBody,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Les deux liens et la sortie sur une seule ligne : le bandeau
              // recouvre l'accueil, il doit rester aussi bas que possible.
              Row(
                children: [
                  _NoticeLink(
                    key: LegalNoticeBanner.termsKey,
                    label: l10n.legalNoticeTerms,
                    onTap: () => _open(LegalDocumentKind.terms),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _NoticeLink(
                    key: LegalNoticeBanner.privacyKey,
                    label: l10n.legalNoticePrivacy,
                    onTap: () => _open(LegalDocumentKind.privacy),
                  ),
                  const Spacer(),
                  TextButton(
                    key: LegalNoticeBanner.dismissKey,
                    onPressed: _dismiss,
                    child: Text(l10n.legalNoticeDismiss),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un lien du bandeau — souligné, parce qu'une couleur seule ne dit pas qu'on
/// peut appuyer, et que ces deux-là sont la seule chose vérifiable du bandeau.
class _NoticeLink extends StatelessWidget {
  const _NoticeLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: context.palette.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: context.palette.primary,
          ),
        ),
      ),
    );
  }
}
