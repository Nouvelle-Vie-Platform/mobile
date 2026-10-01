import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../router/app_router.dart';
import '../state/echanges_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_info_banner.dart';
import '../widgets/chat/message_input_bar.dart';
import '../widgets/content_absence.dart';

/// Écran de discussion d'un groupe — ou d'un tête-à-tête, que le serveur traite
/// comme un groupe `isDirect`.
///
/// **Il reçoit un identifiant, pas un objet** (#96). L'ancienne convention
/// (`extra: Conversation`) est tombée avec le fictif, et pour les raisons de
/// « Navigation : l'identifiant, jamais l'objet » : un objet passé par `extra` est
/// une copie figée hors du magasin, qui continuerait d'afficher un fil que la
/// modération a retiré ; et surtout, **un réveil push et un lien profond n'ont
/// qu'une chaîne à transmettre** — c'est la tranche 2 qui en vivra.
///
/// ## Le seul endroit qui choisit bandeau ou bulle
///
/// Sur `message.origin.isBubble`, et **jamais** sur un auteur absent : `(null,
/// false)` est un **auteur retiré** (ADR-0032), et c'est une bulle. Tester le nul
/// seul afficherait les messages d'un membre parti comme des annonces du serveur —
/// centrés, en gris, mêlés aux « X a rejoint le groupe ».
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  /// État **éphémère local** : le champ de saisie. Jamais un provider global —
  /// Riverpod est l'état *partagé*.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    // L'écho est posé par le composeur avant tout appel réseau : le message
    // paraît dans le fil, marqué « en cours d'envoi », et le champ se vide.
    await ref
        .read(groupMessageComposerProvider)
        .send(groupId: widget.groupId, body: text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // L'acteur est lu ici et passé en clé : voir l'en-tête
    // d'`echanges_providers.dart`.
    final me = ref.watch(echangesActorProvider);
    final key = (actor: me, id: widget.groupId);
    final detail = ref.watch(groupDetailProvider(key));
    final thread = ref.watch(groupThreadProvider(key));

    final group = detail.value;

    // **Le magasin ne connaît pas cet identifiant.** C'est une absence, pas une
    // erreur : la conversation a pu être quittée depuis un autre appareil, ou le
    // lien venir d'un réveil push arrivé avant le cycle qui ramène le groupe. On
    // **n'éjecte pas** le fidèle de l'écran qu'il a ouvert, et on ne fige pas une
    // dernière copie connue — il n'y en a pas.
    if (detail.hasValue && group == null) {
      return Scaffold(
        appBar: ChatAppBar(title: l.communityTitle),
        body: const ContentAbsenceView(absence: ContentAbsence.notSynced),
      );
    }

    final isGroup = group != null && !group.isDirect;

    return Scaffold(
      appBar: ChatAppBar(
        title: group?.title ?? '',
        // Le titre est **toujours** cliquable → une page détail :
        //  - groupe : fiche du groupe (effectif en sous-titre) ;
        //  - tête-à-tête : fiche de l'autre, qu'on résout depuis le roster.
        subtitle: isGroup ? l.groupMembers(group.memberCount) : null,
        onTitleTap:
            group == null ? null : () => _openTitleTarget(context, group),
        actions: const [],
      ),
      body: Column(
        children: [
          Expanded(child: _Thread(thread: thread, isGroup: isGroup)),
          // **La barre de saisie n'existe que si l'on peut écrire.** Le serveur
          // revérifie à chaque envoi (diffusion, verrou, groupe désactivé) ; on le
          // lit ici pour ne pas offrir un champ dont chaque appui prendrait un
          // 403. Un refus qu'on pouvait prévoir n'a pas à être découvert après
          // avoir écrit.
          if (group != null && group.canWrite)
            MessageInputBar(
              hintText: l.chatMessageHint,
              controller: _controller,
              onSend: _send,
            )
          else if (group != null)
            _ReadOnlyNotice(label: l.chatReadOnly),
        ],
      ),
    );
  }

  /// Où mène le titre : la fiche du groupe, ou — pour un tête-à-tête — la fiche de
  /// l'autre, résolue depuis le roster.
  ///
  /// Le roster d'un DM porte **deux** lignes, dont la mienne : on prend l'autre. S'il
  /// n'y en a pas encore (`group_members` pas arrivée), on ouvre la fiche du
  /// groupe — qui dira au moins quelque chose, là où une navigation sans
  /// destination ne dirait rien.
  void _openTitleTarget(BuildContext context, GroupDetailView group) {
    if (group.isDirect) {
      final others = group.members
          .where((m) => m.userId != ref.read(echangesActorProvider));
      if (others.isNotEmpty) {
        context.pushNamed(
          AppRoute.memberProfile,
          pathParameters: {'id': others.first.userId},
        );
        return;
      }
    }
    context.pushNamed(
      AppRoute.groupInfo,
      pathParameters: {'id': group.groupId},
    );
  }
}

/// Le fil lui-même, et **le seul point où l'origine d'un message décide du
/// rendu**.
class _Thread extends ConsumerWidget {
  const _Thread({required this.thread, required this.isGroup});

  final AsyncValue<List<GroupMessageView>> thread;
  final bool isGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return thread.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(l.echangesLoadError, textAlign: TextAlign.center),
        ),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Text(
                l.chatEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.body
                    .copyWith(color: context.palette.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];

            // ⚠️ **La ligne qui porte tout le contrat.** `origin.isBubble` et non
            // `authorId == null` : un auteur retiré (ADR-0032) est une **bulle**.
            if (!m.origin.isBubble) return ChatInfoBanner(text: m.body);

            return ChatBubble(
              message: m,
              // Répondre en privé à un membre qui intervient : tap sur son
              // nom/avatar → sa fiche. Seulement dans un groupe, seulement sur un
              // message reçu, et **jamais** sur un auteur retiré : il n'y a plus
              // de profil à ouvrir, et une zone qui ne répond pas se lit comme un
              // bug.
              onAuthorTap: isGroup &&
                      !m.mine &&
                      m.origin == MessageOrigin.member &&
                      m.authorId != null
                  ? () => context.pushNamed(
                        AppRoute.memberProfile,
                        pathParameters: {'id': m.authorId!},
                      )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Ce qui remplace la barre de saisie quand on ne peut pas écrire — groupe en
/// diffusion, sous verrou, ou désactivé.
///
/// Une phrase, et pas un champ grisé : une option désactivée reste une option
/// offerte, donc une promesse que personne ne tiendra. C'est la règle du sélecteur
/// de canaux de connexion (#83), appliquée ici.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 16, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
