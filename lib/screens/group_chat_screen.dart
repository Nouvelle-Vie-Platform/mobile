import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/messaging/group_history.dart';
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
import '../widgets/home_tab.dart';

/// Écran de discussion d'un groupe — ou d'un tête-à-tête, que le serveur traite
/// comme un groupe `isDirect`.
///
/// **Il reçoit un identifiant, pas un objet** (#96). Un objet passé par `extra`
/// est une copie figée hors du magasin, et **un réveil push et un lien profond
/// n'ont qu'une chaîne à transmettre**.
///
/// ## Le seul endroit qui choisit bandeau ou bulle
///
/// Sur `message.origin.isBubble`, et **jamais** sur un auteur absent : `(null,
/// false)` est un **auteur retiré** (ADR-0032), et c'est une bulle.
///
/// ## Un fil comme WhatsApp (#140)
///
/// - **Il s'ouvre en bas**, sur le dernier message — la liste est **inversée** :
///   sa position zéro est le bas, et c'est elle qui tient le dernier message à
///   l'écran quand le clavier monte (le `Scaffold` rétrécit le corps, la liste
///   garde son bas). Il n'y a rien à recalculer à chaque frappe.
/// - **S'il y a des non-lus**, il s'ouvre sur le premier, sous un séparateur
///   « N messages non lus » **figé à l'ouverture** : il ne bouge pas quand la
///   lecture avance, ni quand un message arrive.
/// - **L'historique se charge par pages** en remontant : la fenêtre du magasin
///   s'élargit d'abord, puis, quand le magasin est épuisé,
///   `GET /groups/:id/messages?before=` va chercher la suite — rangée dans le
///   magasin, affichée par lui.
/// - **La lecture avance** quand le fil montre le message le plus récent : au
///   plus une fois par ouverture et une fois par message reçu fil ouvert, par
///   l'outbox de la lecture (rejouable).
/// - **Un message qui n'est pas parti** se touche : Réessayer / Supprimer. Il
///   repart aussi tout seul (voir `messagingOutboxProvider`).
///
/// ## Le temps réel n'a plus de prise ici
///
/// Le canal `users/{id}` est ouvert par l'application entière, pas par cet écran
/// (`messagingLinkProvider`) : il range les lignes dans le magasin, et ce fil se
/// redessine parce que `groupThreadProvider` observe le magasin. L'écran est donc
/// **exactement le même** avec ou sans temps réel. Le canal par groupe
/// (`groups/{id}`, #101) n'est plus ouvert.
///
/// ## Le retour ne mène jamais nulle part
///
/// Ouvert depuis une notification, le fil est arrivé par `goNamed` : il n'y a
/// rien dessous. Le retour (flèche ou geste système) mène alors à la liste des
/// Échanges (`/home?tab=community`) — jamais hors de l'application, jamais sur
/// un écran vide.
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  /// État **éphémère local** : le champ de saisie. Jamais un provider global —
  /// Riverpod est l'état *partagé*.
  final TextEditingController _controller = TextEditingController();

  final ScrollController _scroll = ScrollController();

  /// Le séparateur « N messages non lus », pour s'y rendre à l'ouverture.
  final GlobalKey _separatorKey = GlobalKey();

  /// **La fenêtre** : les N messages les plus récents que le fil montre. Elle
  /// part assez large pour contenir le premier non-lu, et s'élargit en
  /// remontant.
  int _limit = kThreadWindow;

  /// La fenêtre de départ est fixée (le compte des non-lus est lu).
  bool _ready = false;

  /// Le séparateur, **figé à l'ouverture** : le premier non-lu et leur nombre.
  /// `null` = rien de non lu.
  ({String id, int count})? _separator;
  bool _separatorFrozen = false;

  /// Le dernier fil reçu : affiché pendant que la fenêtre s'élargit (le
  /// provider d'une nouvelle fenêtre repart de « chargement »).
  List<GroupMessageView>? _lastMessages;

  bool _loadingHistory = false;
  bool _historyExhausted = false;

  /// Le dernier message jusqu'où cet écran a fait avancer la lecture.
  String? _readUpTo;

  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    unawaited(_resolveWindow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Revenir sur un fil ouvert, c'est le lire.
    if (_foreground) _maybeAdvanceRead();
  }

  /// **La fenêtre de départ** : assez large pour contenir le premier non-lu, sur
  /// lequel le fil s'ouvre. Une lecture du magasin, une seule fois.
  Future<void> _resolveWindow() async {
    var unread = 0;
    try {
      unread = await ref
          .read(echangesRepositoryProvider(ref.read(echangesActorProvider)))
          .unreadCount(widget.groupId);
    } catch (_) {
      // Le compte n'est qu'un confort d'ouverture : sans lui, le fil s'ouvre
      // sur sa fenêtre par défaut.
    }
    if (!mounted) return;
    setState(() {
      _limit = math.max(kThreadWindow, unread + 10);
      _ready = true;
    });
  }

  Future<void> _send(String text) async {
    // Le fil revient en bas : le message qu'on vient d'écrire doit se voir.
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
    // L'écho est posé par le composeur avant tout appel réseau : le message
    // paraît dans le fil, marqué « en cours d'envoi », et le champ se vide.
    await ref
        .read(groupMessageComposerProvider)
        .send(groupId: widget.groupId, body: text);
  }

  /// **Y a-t-il une pile sous ce fil ?** Lu sur la `GoRouter` quand il y en a
  /// une — c'est sa pile qui compte —, sur le `Navigator` sinon (un écran monté
  /// seul, dans un test).
  bool get _canPop {
    final router = GoRouter.maybeOf(context);
    return router?.canPop() ?? Navigator.of(context).canPop();
  }

  /// **Le retour** : dépiler s'il y a une pile, sinon la liste des Échanges.
  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (_canPop) {
      router != null ? router.pop() : Navigator.of(context).pop();
      return;
    }
    if (router == null) return;
    router.goNamed(
      AppRoute.home,
      queryParameters: {'tab': HomeTab.community.name},
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Défilement : l'historique et la lecture
  // ───────────────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // La liste est inversée : le haut du fil est la fin de l'étendue.
    if (position.pixels >= position.maxScrollExtent - 200) _loadOlder();
    if (position.pixels <= 80) _maybeAdvanceRead();
  }

  /// **Remonter** : élargir la fenêtre tant que le magasin a plus, puis demander
  /// au serveur ce qui précède le plus ancien message local.
  void _loadOlder() {
    final messages = _lastMessages;
    if (!_ready || messages == null || messages.isEmpty) return;

    if (messages.length >= _limit) {
      setState(() => _limit += kThreadWindow);
      return;
    }
    if (_historyExhausted || _loadingHistory) return;

    final oldest = messages.firstWhere(
      (m) => m.isConfirmed,
      orElse: () => messages.first,
    );
    if (!oldest.isConfirmed) return;

    _loadingHistory = true;
    unawaited(
      ref
          .read(groupHistoryProvider)
          .loadBefore(groupId: widget.groupId, beforeId: oldest.id)
          .then((outcome) {
        _loadingHistory = false;
        if (!mounted) return;
        if (outcome == HistoryOutcome.exhausted) _historyExhausted = true;
        // Une page pleine a pu remplir la fenêtre : on l'élargit d'autant.
        if (outcome == HistoryOutcome.more) {
          setState(() => _limit += kThreadWindow);
        }
      }).catchError((Object _) {
        _loadingHistory = false;
      }),
    );
  }

  /// **La lecture avance** quand le fil montre son message le plus récent, s'il
  /// reste du non-lu — au plus une fois par message.
  void _maybeAdvanceRead() {
    final messages = _lastMessages;
    if (!mounted || !_foreground || messages == null || messages.isEmpty) {
      return;
    }
    if (_scroll.hasClients && _scroll.offset > 80) return;
    if (!messages.any((m) => m.unread)) return;

    final confirmed =
        messages.where((m) => m.isConfirmed && m.createdAt != null);
    if (confirmed.isEmpty) return;
    final newest = confirmed.last;
    if (newest.id == _readUpTo) return;
    _readUpTo = newest.id;

    unawaited(
      ref
          .read(groupReadAdvancerProvider)
          .advance(
            groupId: widget.groupId,
            messageId: newest.id,
            messageCreatedAt: newest.createdAt!,
          )
          .catchError((Object _) {}),
    );
  }

  /// **Fige le séparateur** au premier fil reçu, puis s'y rend.
  void _onThread(List<GroupMessageView> messages) {
    _lastMessages = messages;
    if (_separatorFrozen || !_ready) return;
    _separatorFrozen = true;

    final unread = messages.where((m) => m.unread).toList();
    if (unread.isNotEmpty) {
      _separator = (id: unread.first.id, count: unread.length);
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSeparator());
    }
  }

  /// **Ouvre le fil sur le premier non-lu.** La liste est paresseuse : tant que
  /// le séparateur n'est pas construit, on remonte d'un écran ; puis on le place
  /// vers le haut de la vue — les non-lus en dessous.
  ///
  /// ⚠️ À vérifier sur appareil : l'alignement d'`ensureVisible` dans une liste
  /// **inversée** (0 = le bas de la vue, 1 = le haut).
  void _revealSeparator([int attempt = 0]) {
    if (!mounted) return;
    final target = _separatorKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, alignment: 0.9);
      return;
    }
    if (!_scroll.hasClients || attempt > 30) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent) return;
    _scroll.jumpTo(
      math.min(
        position.pixels + position.viewportDimension,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _revealSeparator(attempt + 1));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Un message qui n'est pas parti
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _onFailedTap(GroupMessageView message) async {
    final l = context.l10n;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l.chatRetry),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheet).colorScheme.error,
              ),
              title: Text(l.chatDiscard),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final composer = ref.read(groupMessageComposerProvider);
    // L'identifiant d'un écho **est** sa clé d'idempotence : le renvoi part
    // sous la même, jamais de doublon.
    if (choice) {
      await composer.retry(message.id);
    } else {
      await composer.discard(message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // L'acteur est lu ici et passé en clé : voir l'en-tête
    // d'`echanges_providers.dart`.
    final me = ref.watch(echangesActorProvider);
    final detail =
        ref.watch(groupDetailProvider((actor: me, id: widget.groupId)));
    final group = detail.value;

    // **Le magasin ne connaît pas cet identifiant.** C'est une absence, pas une
    // erreur : la conversation a pu être quittée depuis un autre appareil, ou le
    // lien venir d'un réveil push arrivé avant le cycle qui ramène le groupe.
    if (detail.hasValue && group == null) {
      return _absence(l.communityTitle, ContentAbsence.notSynced);
    }

    // **Je ne suis plus membre** (#140) : mon appartenance est partie
    // (`membership.changed` tombstoné, ou le tirage), le roster est là et je n'y
    // suis plus. Le groupe reste en magasin — `groups` n'a pas de tombstone —,
    // mais son fil ne s'affiche plus.
    if (group != null &&
        group.members.isNotEmpty &&
        !group.members.any((m) => m.userId == me)) {
      return _absence(group.title, ContentAbsence.retracted);
    }

    final thread = _ready
        ? ref.watch(
            groupThreadProvider(
              (actor: me, id: widget.groupId, limit: _limit),
            ),
          )
        : const AsyncValue<List<GroupMessageView>>.loading();
    final messages = thread.value;
    if (messages != null) {
      _onThread(messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAdvanceRead());
    }

    final isGroup = group != null && !group.isDirect;

    return PopScope(
      // Pas de pile dessous (ouvert par une notification) : le geste système
      // mène à la liste des Échanges au lieu de quitter l'application.
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        // Le défaut, écrit : c'est lui qui fait que **le fil suit le clavier**.
        // Le corps rétrécit, la liste inversée garde son bas — le dernier
        // message reste au-dessus du champ.
        resizeToAvoidBottomInset: true,
        appBar: ChatAppBar(
          title: group?.title ?? '',
          // **L'effectif servi par le serveur** (`groups.memberCount`, membres
          // actifs), jamais un compte des lignes `group_members` locales : le
          // roster garde la ligne d'un compte effacé (contrat M1a §4).
          subtitle: isGroup ? l.groupMembers(group.memberCount) : null,
          onBack: _leave,
          onTitleTap:
              group == null ? null : () => _openTitleTarget(context, group),
          actions: const [],
        ),
        body: Column(
          children: [
            Expanded(
              child: _Thread(
                thread: thread,
                // Pendant qu'une fenêtre plus large se charge, l'ancienne reste.
                fallback: _lastMessages,
                isGroup: isGroup,
                separator: _separator,
                separatorKey: _separatorKey,
                scroll: _scroll,
                onFailedTap: _onFailedTap,
              ),
            ),
            // **La barre de saisie n'existe que si l'on peut écrire.** Le
            // serveur revérifie à chaque envoi ; on le lit ici pour ne pas
            // offrir un champ dont chaque appui prendrait un 403.
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
      ),
    );
  }

  Widget _absence(String title, ContentAbsence absence) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: ChatAppBar(title: title, onBack: _leave),
        body: ContentAbsenceView(absence: absence),
      ),
    );
  }

  /// Où mène le titre : la fiche du groupe, ou — pour un tête-à-tête — la fiche de
  /// l'autre, résolue depuis le roster.
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
class _Thread extends StatelessWidget {
  const _Thread({
    required this.thread,
    required this.fallback,
    required this.isGroup,
    required this.separator,
    required this.separatorKey,
    required this.scroll,
    required this.onFailedTap,
  });

  final AsyncValue<List<GroupMessageView>> thread;
  final List<GroupMessageView>? fallback;
  final bool isGroup;
  final ({String id, int count})? separator;
  final GlobalKey separatorKey;
  final ScrollController scroll;
  final void Function(GroupMessageView message) onFailedTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final messages = thread.value ?? fallback;

    if (messages == null) {
      if (thread.hasError) {
        return Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Text(l.echangesLoadError, textAlign: TextAlign.center),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

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

    // **Le plus récent d'abord** : la liste est inversée, sa position zéro est
    // le bas de l'écran. Le séparateur se glisse **après** le premier non-lu
    // dans cet ordre — c'est-à-dire, à l'écran, juste au-dessus de lui.
    final newestFirst = messages.reversed.toList(growable: false);
    final separatorAt = separator == null
        ? -1
        : newestFirst.indexWhere((m) => m.id == separator!.id);
    final count = newestFirst.length + (separatorAt >= 0 ? 1 : 0);

    return ListView.builder(
      controller: scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (separatorAt >= 0 && i == separatorAt + 1) {
          return _UnreadSeparator(
            key: separatorKey,
            label: l.chatUnreadSeparator(separator!.count),
          );
        }
        final index = separatorAt >= 0 && i > separatorAt + 1 ? i - 1 : i;
        final m = newestFirst[index];

        // ⚠️ **La ligne qui porte tout le contrat.** `origin.isBubble` et non
        // `authorId == null` : un auteur retiré (ADR-0032) est une **bulle**.
        if (!m.origin.isBubble) {
          return ChatInfoBanner(text: m.body ?? l.chatMediaUnsupported);
        }

        return ChatBubble(
          key: ValueKey(m.id),
          message: m,
          // Répondre en privé à un membre qui intervient : tap sur son
          // nom/avatar → sa fiche. Seulement dans un groupe, seulement sur un
          // message reçu, et **jamais** sur un auteur retiré.
          onAuthorTap: isGroup &&
                  !m.mine &&
                  m.origin == MessageOrigin.member &&
                  m.authorId != null
              ? () => context.pushNamed(
                    AppRoute.memberProfile,
                    pathParameters: {'id': m.authorId!},
                  )
              : null,
          onFailedTap: m.mine && m.delivery == MessageDelivery.failed
              ? () => onFailedTap(m)
              : null,
        );
      },
    );
  }
}

/// « N messages non lus » — posé à l'ouverture, au-dessus du premier non-lu.
class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('chat_unread_separator'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Ce qui remplace la barre de saisie quand on ne peut pas écrire — groupe en
/// diffusion, sous verrou, ou désactivé.
///
/// Une phrase, et pas un champ grisé : une option désactivée reste une option
/// offerte, donc une promesse que personne ne tiendra.
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
