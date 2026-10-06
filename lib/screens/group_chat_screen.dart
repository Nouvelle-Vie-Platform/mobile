import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/messaging/group_history.dart';
import '../data/messaging/message_gestures.dart';
import '../data/messaging/messaging_ephemeral.dart';
import '../l10n/l10n_extension.dart';
import '../models/echanges_view.dart';
import '../models/message_gesture_rules.dart';
import '../models/receipt_view.dart';
import '../router/app_router.dart';
import '../state/chat_organization_providers.dart';
import '../state/echanges_providers.dart';
import '../state/receipts_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/presence_labels.dart';
import '../widgets/chat/chat_app_bar.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_info_banner.dart';
import '../widgets/chat/chat_mute_menu.dart';
import '../widgets/chat/media/chat_composer.dart';
import '../widgets/chat/forward_sheet.dart';
import '../widgets/chat/message_actions_sheet.dart';
import '../widgets/chat/message_focus_highlight.dart';
import '../widgets/chat/message_info_sheet.dart';
import '../widgets/chat/message_quote.dart';
import '../widgets/chat/message_reactions.dart';
import '../widgets/chat/receipt_mark.dart';
import '../widgets/chat/swipe_to_reply.dart';
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
/// ## Les gestes sur un message (M2, #141)
///
/// - **Répondre** : glisser la bulle vers la droite, ou appui long → Répondre ;
///   la citation paraît au-dessus du champ (annulable) puis dans la bulle.
///   **Toucher une citation défile jusqu'au message d'origine** et le met en
///   évidence — en chargeant l'historique s'il le faut.
/// - **Appui long** : le jeu rapide de réactions et les gestes que mes droits
///   permettent (`availableMessageActions`) — copier, transférer, modifier,
///   supprimer pour moi / pour tous.
/// - **Toucher l'agrégat** sous une bulle montre qui a réagi.
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
  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.focusMessageId,
  });

  final String groupId;

  /// **Le message sur lequel ouvrir** (#146, M8) — un résultat de recherche. Le
  /// fil remonte l'historique jusqu'à lui s'il le faut, le montre et le met en
  /// évidence ; le séparateur des non-lus n'est alors pas posé. `null` : le fil
  /// s'ouvre comme d'habitude.
  final String? focusMessageId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with WidgetsBindingObserver {
  /// État **éphémère local** : le champ de saisie. Jamais un provider global —
  /// Riverpod est l'état *partagé*.
  final TextEditingController _controller = TextEditingController();

  /// Le focus du champ de saisie (M2) : répondre ou modifier l'ouvre.
  final FocusNode _composerFocus = FocusNode();

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

  /// M8 (#146) : porte la bulle du message trouvé, pour s'y rendre.
  final GlobalKey _focusKey = GlobalKey();

  /// M8 (#146) : le message trouvé est en évidence. Allumé une fois, à
  /// l'arrivée sur lui, et éteint par [_focusTimer] — jamais rallumé, même si
  /// la liste recrée sa bulle.
  bool _focusLit = false;
  Timer? _focusTimer;
  // ── #142 (M3) : « écrit… » envoyé, présence de l'autre lue à l'ouverture ──

  /// « J'écris », à intervalle borné pendant la frappe.
  late final TypingSignaler _typing = TypingSignaler(
    send: () =>
        ref.read(messagingSignalsApiProvider).signalTyping(widget.groupId),
  );

  /// La présence de l'autre (tête-à-tête) a été demandée pour cette ouverture.
  bool _presenceRequested = false;

  // ── Tranche M2 (#141) ──

  /// Le message auquel on est en train de répondre — sa citation est
  /// au-dessus du champ.
  GroupMessageView? _replyTo;

  /// Le message qu'on est en train de modifier — son texte est dans le champ.
  GroupMessageView? _editing;

  /// Le message mis en évidence après un saut depuis une citation.
  String? _highlightId;
  Timer? _highlightTimer;

  /// Le message vers lequel le fil défile, et la clé posée sur sa ligne.
  String? _jumpTargetId;
  final GlobalKey _jumpTargetKey = GlobalKey();

  /// Moi, et mes droits ici — relus à chaque construction.
  String? _me;

  /// Le groupe affiché — pour « Infos du message » (M3, #142) depuis le menu.
  GroupDetailView? _group;
  bool _isAdmin = false;
  bool _canWrite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _controller.addListener(_onTextChanged);
    unawaited(_resolveWindow());
  }

  void _onTextChanged() => _typing.onTextChanged(_controller.text);

  /// **La présence de l'autre, à l'ouverture d'un tête-à-tête** (#142) — puis
  /// tenue à jour par `presence.changed`. Un groupe n'en a pas.
  Future<void> _loadPresence() async {
    final presence =
        await ref.read(messagingSignalsApiProvider).presenceIn(widget.groupId);
    if (!mounted || presence == null) return;
    ref.read(messagingEphemeralStoreProvider).presenceChanged(presence);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _highlightTimer?.cancel();
    _scroll.dispose();
    _controller.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Revenir sur un fil ouvert, c'est le lire.
    if (_foreground) _maybeAdvanceRead();
    // Et relire la présence : celle qu'on tenait date d'avant l'arrière-plan.
    if (_foreground && _presenceRequested) unawaited(_loadPresence());
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
    // M8 (#146) : ouvert sur un message trouvé — la fenêtre doit le contenir,
    // quitte à remonter l'historique jusqu'à lui.
    var focusWindow = 0;
    final focus = widget.focusMessageId;
    if (focus != null) {
      try {
        focusWindow = await ref
                .read(threadMessageLocatorProvider)
                .windowFor(widget.groupId, focus) ??
            0;
      } catch (_) {
        // Introuvable ou réseau absent : le fil s'ouvre comme d'habitude.
      }
    }
    if (!mounted) return;
    setState(() {
      _limit = math.max(kThreadWindow, math.max(unread, focusWindow) + 10);
      _ready = true;
    });
  }

  Future<void> _send(String text) async {
    _typing.reset();
    // **Modifier** (M2) : le texte du champ remplace celui du message.
    final editing = _editing;
    if (editing != null) {
      setState(() => _editing = null);
      if (text.trim() == editing.body) return;
      _report(
        await ref.read(messageGesturesProvider).edit(
              groupId: widget.groupId,
              messageId: editing.id,
              body: text,
            ),
      );
      return;
    }

    // Le fil revient en bas : le message qu'on vient d'écrire doit se voir.
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
    final reply = _replyTo;
    if (reply != null) setState(() => _replyTo = null);
    // L'écho est posé par le composeur avant tout appel réseau : le message
    // paraît dans le fil, marqué « en cours d'envoi », et le champ se vide.
    await ref.read(groupMessageComposerProvider).send(
          groupId: widget.groupId,
          body: text,
          replyToMessageId: reply?.id,
        );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Les gestes sur un message (M2, #141)
  // ───────────────────────────────────────────────────────────────────────────

  /// **Répondre** : la citation monte au-dessus du champ.
  void _startReply(GroupMessageView message) {
    setState(() {
      if (_editing != null) _controller.clear();
      _editing = null;
      _replyTo = message;
    });
    // Comme WhatsApp : on répond en écrivant — le clavier s'ouvre.
    _composerFocus.requestFocus();
  }

  /// **Modifier** : le texte du message entre dans le champ.
  void _startEdit(GroupMessageView message) {
    setState(() {
      _replyTo = null;
      _editing = message;
    });
    final body = message.body ?? '';
    _controller.value = TextEditingValue(
      text: body,
      selection: TextSelection.collapsed(offset: body.length),
    );
    _composerFocus.requestFocus();
  }

  void _cancelComposerContext() {
    setState(() {
      if (_editing != null) _controller.clear();
      _editing = null;
      _replyTo = null;
    });
  }

  /// La citation d'un message qu'on s'apprête à citer — pour l'aperçu.
  MessageQuoteView _quoteOf(GroupMessageView message) => MessageQuoteView(
        messageId: message.id,
        authorId: message.authorId,
        authorName: message.authorName,
        excerpt: message.body,
        mine: message.mine,
      );

  /// **L'appui long** : le jeu rapide de réactions, puis les gestes permis.
  Future<void> _onLongPress(GroupMessageView message) async {
    final actions = availableMessageActions(
      message,
      isAdmin: _isAdmin,
      canWrite: _canWrite,
      now: DateTime.now(),
    );
    final canReact = canReactTo(message);
    if (actions.isEmpty && !canReact) return;

    HapticFeedback.selectionClick();
    final choice = await showMessageActionsSheet(
      context,
      actions: actions,
      canReact: canReact,
      myReaction: message.myReaction,
    );
    if (choice == null || !mounted) return;

    final gestures = ref.read(messageGesturesProvider);
    switch (choice) {
      case ReactionChoice(:final emoji):
        _report(
          await gestures.toggleReaction(
            groupId: widget.groupId,
            messageId: message.id,
            emoji: emoji,
            current: message.myReaction,
          ),
        );
      case ActionChoice(action: MessageAction.reply):
        _startReply(message);
      case ActionChoice(action: MessageAction.copy):
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
        if (!mounted) return;
        _snack(context.l10n.chatCopied);
      case ActionChoice(action: MessageAction.forward):
        final targets = await showForwardSheet(context, actor: _me);
        if (targets == null || targets.isEmpty || !mounted) return;
        final outcome = await gestures.forward(
          groupId: widget.groupId,
          messageId: message.id,
          targetGroupIds: targets,
        );
        if (!mounted) return;
        if (outcome == GestureOutcome.done) {
          _snack(context.l10n.chatForwardDone);
        } else {
          _report(outcome);
        }
      case ActionChoice(action: MessageAction.edit):
        _startEdit(message);
      case ActionChoice(action: MessageAction.info):
        // M3 (#142) : qui a reçu, qui a lu — la feuille de M3, ouverte d'ici.
        final group = _group;
        if (group == null) return;
        await showMessageInfo(context, message: message, group: group);
      case ActionChoice(action: MessageAction.deleteForMe):
        if (_replyTo?.id == message.id) setState(() => _replyTo = null);
        _report(
          await gestures.hideForMe(
            groupId: widget.groupId,
            messageId: message.id,
          ),
        );
      case ActionChoice(action: MessageAction.deleteForEveryone):
        if (!await _confirmDeleteForEveryone() || !mounted) return;
        _report(
          await gestures.deleteForEveryone(
            groupId: widget.groupId,
            messageId: message.id,
          ),
        );
    }
  }

  Future<bool> _confirmDeleteForEveryone() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l.chatDeleteForEveryoneConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          TextButton(
            key: const Key('confirm_delete_for_everyone'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l.chatActionDeleteForEveryone),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// **Toucher l'agrégat** : qui a réagi ; toucher ma ligne retire la mienne.
  void _onReactionsTap(GroupMessageView message) {
    showReactorsSheet(
      context,
      actor: _me,
      messageId: message.id,
      onRemove: () async {
        final mine = message.myReaction;
        if (mine == null) return;
        _report(
          await ref.read(messageGesturesProvider).toggleReaction(
                groupId: widget.groupId,
                messageId: message.id,
                emoji: mine,
                current: mine,
              ),
        );
      },
    );
  }

  /// Dit ce qu'a donné un geste — rien quand il a abouti.
  void _report(GestureOutcome outcome) {
    if (!mounted) return;
    final l = context.l10n;
    switch (outcome) {
      case GestureOutcome.done:
        return;
      case GestureOutcome.windowClosed:
        _snack(l.chatGestureWindowClosed);
      case GestureOutcome.refused:
        _snack(l.chatGestureRefused);
      case GestureOutcome.unreachable:
        _snack(l.chatGestureUnreachable);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// **Toucher une citation** : défiler jusqu'au message d'origine et le
  /// mettre en évidence. S'il n'est pas dans le magasin, l'historique se charge
  /// page après page jusqu'à lui (ou jusqu'au début du fil).
  Future<void> _jumpTo(String messageId) async {
    final repository = ref.read(echangesRepositoryProvider(_me));
    var newer = await repository.newerThan(widget.groupId, messageId);

    var pages = 0;
    while (newer == null && !_historyExhausted && pages < 20) {
      final oldest = await repository.oldestMessageId(widget.groupId);
      if (oldest == null) break;
      final outcome = await ref
          .read(groupHistoryProvider)
          .loadBefore(groupId: widget.groupId, beforeId: oldest);
      if (outcome == HistoryOutcome.exhausted) _historyExhausted = true;
      if (outcome == HistoryOutcome.unreachable) break;
      newer = await repository.newerThan(widget.groupId, messageId);
      pages++;
    }
    if (!mounted) return;
    if (newer == null) {
      _snack(context.l10n.chatQuoteNotFound);
      return;
    }

    final needed = newer + kThreadWindow;
    _highlightTimer?.cancel();
    setState(() {
      // La fenêtre doit contenir le message (les échos en attente comptent
      // aussi dans le fil : la marge les absorbe).
      if (_limit < needed) _limit = needed;
      _jumpTargetId = messageId;
      _highlightId = messageId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealJumpTarget());
  }

  /// La mise en évidence s'éteint 1,6 s **après** que le message est à l'écran
  /// — pas après le toucher : remonter un long fil prend plusieurs images.
  void _dimHighlightLater() {
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  /// Amène la ligne du message visé à l'écran. La liste est paresseuse et
  /// inversée : on repart du bas, puis on remonte d'un écran tant que la ligne
  /// n'est pas construite — le motif de [_revealSeparator].
  void _revealJumpTarget([int attempt = 0]) {
    if (!mounted) return;
    final target = _jumpTargetKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
      );
      _dimHighlightLater();
      return;
    }
    if (!_scroll.hasClients || attempt > 40) {
      _dimHighlightLater();
      return;
    }
    final position = _scroll.position;
    if (attempt == 0) {
      _scroll.jumpTo(0);
    } else {
      if (position.pixels >= position.maxScrollExtent) {
        // Le haut est atteint sans la ligne : la fenêtre s'élargit peut-être
        // encore ; on laisse une image de plus avant d'abandonner.
        if (attempt > 35) {
          _dimHighlightLater();
          return;
        }
      }
      _scroll.jumpTo(
        math.min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
      );
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _revealJumpTarget(attempt + 1));
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

    // M8 (#146) : ouvert sur un message trouvé — c'est lui qu'on montre.
    final focus = widget.focusMessageId;
    if (focus != null && messages.any((m) => m.id == focus)) {
      _focusLit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        revealKeyedItem(
          target: _focusKey,
          scroll: _scroll,
          mounted: () => mounted,
        );
        _focusTimer = Timer(kMessageFocusDuration, () {
          if (mounted) setState(() => _focusLit = false);
        });
      });
      return;
    }

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

    // ── #142 (M3) : coches, « écrit… », « en ligne / vu à » ──
    if (group != null && group.isDirect && !_presenceRequested) {
      _presenceRequested = true;
      unawaited(_loadPresence());
    }
    final receipts = ref
            .watch(messageReceiptsProvider((actor: me, id: widget.groupId)))
            .value ??
        const <String, ReceiptStatus>{};
    final typers = ref.watch(typingInProvider((actor: me, id: widget.groupId)));
    final other = group == null || !group.isDirect
        ? null
        : group.members.where((m) => m.userId != me).firstOrNull;
    final presence =
        other == null ? null : ref.watch(presenceOfProvider(other.userId));
    final names = {
      for (final member in group?.members ?? const <GroupMemberView>[])
        member.userId: member.displayName,
    };
    final liveSubtitle = typingLabel(
          l,
          typers: typers,
          isDirect: group?.isDirect ?? false,
          nameOf: (userId) => names[userId],
        ) ??
        (group != null && group.isDirect ? presenceLabel(l, presence) : null);

    // Mes droits ici (M2, #141) : l'administrateur supprime pour tous sans
    // délai ; répondre et modifier exigent la barre de saisie.
    _me = me;
    _group = group;
    _canWrite = group != null && group.canWrite;
    _isAdmin = group != null &&
        group.members.any(
          (m) =>
              m.userId == me && (m.role == 'leader' || m.role == 'moderator'),
        );

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
          // « écrit… » d'abord ; sinon l'effectif d'un groupe, ou la présence
          // de l'autre dans un tête-à-tête (#142).
          subtitle: liveSubtitle ??
              (isGroup ? l.groupMembers(group.memberCount) : null),
          onBack: _leave,
          onTitleTap:
              group == null ? null : () => _openTitleTarget(context, group),
          // Le menu « ⋮ » : la sourdine (M5).
          actions: [ChatMuteMenu(groupId: widget.groupId)],
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
                focusMessageId: widget.focusMessageId,
                focusKey: _focusKey,
                focusLit: _focusLit,
                receipts: receipts,
                canWrite: _canWrite,
                onLongPress: _onLongPress,
                onSwipeReply: _startReply,
                onQuoteTap: _jumpTo,
                onReactionsTap: _onReactionsTap,
                highlightId: _highlightId,
                jumpTargetId: _jumpTargetId,
                jumpTargetKey: _jumpTargetKey,
              ),
            ),
            // **La barre de saisie n'existe que si l'on peut écrire.** Le
            // serveur revérifie à chaque envoi ; on le lit ici pour ne pas
            // offrir un champ dont chaque appui prendrait un 403.
            // Au-dessus du champ (M2) : la réponse ou la modification en cours.
            if (group != null && group.canWrite && _editing != null)
              ComposerContextBar.edit(onCancel: _cancelComposerContext)
            else if (group != null && group.canWrite && _replyTo != null)
              ComposerContextBar.reply(
                quote: _quoteOf(_replyTo!),
                onCancel: _cancelComposerContext,
              ),
            if (group != null && group.canWrite)
              // M4 (#143) : la barre de saisie et ses médias — trombone,
              // appareil photo, micro.
              ChatComposer(
                groupId: widget.groupId,
                hintText: l.chatMessageHint,
                controller: _controller,
                focusNode: _composerFocus,
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
    this.focusMessageId,
    this.focusKey,
    this.focusLit = false,
    this.receipts = const {},
    this.canWrite = false,
    this.onLongPress,
    this.onSwipeReply,
    this.onQuoteTap,
    this.onReactionsTap,
    this.highlightId,
    this.jumpTargetId,
    this.jumpTargetKey,
  });

  final AsyncValue<List<GroupMessageView>> thread;
  final List<GroupMessageView>? fallback;
  final bool isGroup;
  final ({String id, int count})? separator;
  final GlobalKey separatorKey;
  final ScrollController scroll;
  final void Function(GroupMessageView message) onFailedTap;

  /// M8 (#146) : le message trouvé, mis en évidence et porteur de [focusKey].
  final String? focusMessageId;
  final GlobalKey? focusKey;

  /// M8 (#146) : le fond du message trouvé est encore allumé.
  final bool focusLit;

  /// Les coches de mes messages (#142), par identifiant.
  final Map<String, ReceiptStatus> receipts;

  // ── Tranche M2 (#141) ──
  final bool canWrite;
  final void Function(GroupMessageView message)? onLongPress;
  final void Function(GroupMessageView message)? onSwipeReply;
  final void Function(String messageId)? onQuoteTap;
  final void Function(GroupMessageView message)? onReactionsTap;
  final String? highlightId;
  final String? jumpTargetId;
  final GlobalKey? jumpTargetKey;

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

        final mineConfirmed = m.mine && m.isConfirmed;
        final bubble = ChatBubble(
          key: ValueKey(m.id),
          message: m,
          // #142 (M3) : ✓ / ✓✓ / ✓✓ bleu sur mes messages confirmés.
          receiptMark: mineConfirmed
              ? ReceiptMark(status: receipts[m.id] ?? ReceiptStatus.sent)
              : null,
          // « Transféré » et la citation (M2) — toucher la citation y mène.
          header: messageBubbleHeader(
            context,
            m,
            onQuoteTap: m.quote == null || onQuoteTap == null
                ? null
                : () => onQuoteTap!(m.quote!.messageId),
          ),
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
        final gestured = _GesturedMessage(
          key: m.id == jumpTargetId ? jumpTargetKey : null,
          message: m,
          bubble: bubble,
          canSwipe:
              onSwipeReply != null && canSwipeToReply(m, canWrite: canWrite),
          highlighted: m.id == highlightId,
          onLongPress: onLongPress == null ? null : () => onLongPress!(m),
          onSwipeReply: onSwipeReply == null ? null : () => onSwipeReply!(m),
          onReactionsTap:
              onReactionsTap == null ? null : () => onReactionsTap!(m),
        );
        // M8 (#146) : le message trouvé par la recherche.
        if (m.id == focusMessageId) {
          return KeyedSubtree(
            key: focusKey,
            child: MessageFocusHighlight(lit: focusLit, child: gestured),
          );
        }
        return gestured;
      },
    );
  }
}

/// **Une bulle et ses gestes** (M2, #141) : glisser pour répondre, appui long
/// pour le menu, l'agrégat des réactions dessous, et la mise en évidence après
/// un saut depuis une citation. Le geste de glissement ne couvre que la bulle.
class _GesturedMessage extends StatelessWidget {
  const _GesturedMessage({
    super.key,
    required this.message,
    required this.bubble,
    required this.canSwipe,
    required this.highlighted,
    this.onLongPress,
    this.onSwipeReply,
    this.onReactionsTap,
  });

  final GroupMessageView message;
  final Widget bubble;
  final bool canSwipe;
  final bool highlighted;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onReactionsTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: highlighted
            ? palette.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment:
            message.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: Key('message_gestures_${message.id}'),
            // Toute la ligne répond à l'appui long, pas seulement la bulle —
            // comme WhatsApp, et comme l'appui long « Infos » de M3 (#142).
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            child: SwipeToReply(
              enabled: canSwipe,
              onReply: onSwipeReply ?? () {},
              child: bubble,
            ),
          ),
          if (message.reactions.isNotEmpty)
            MessageReactionsRow(
              reactions: message.reactions,
              alignEnd: message.mine,
              onTap: onReactionsTap,
            ),
        ],
      ),
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
