import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/chat_search_repository.dart';
import '../l10n/l10n_extension.dart';
import '../models/chat_organization.dart';
import '../models/echanges_view.dart';
import '../router/app_router.dart';
import '../state/chat_organization_providers.dart';
import '../state/echanges_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/event_time.dart';
import '../widgets/app_avatar.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/community/conversation_tile.dart';

/// **Rechercher dans mes discussions** (#146, tranche M8).
///
/// Deux recherches, dans cet ordre :
///
/// 1. **locale, à chaque frappe** — les **noms** de discussions (sur la liste
///    déjà lue, accents et casse ignorés) et le **texte** des messages du
///    magasin. Instantanée, hors ligne ;
/// 2. **serveur, après une courte pause** — `GET /groups/messages/search`, pour
///    l'historique que le magasin n'a pas. Ses résultats s'ajoutent aux locaux,
///    sans doublon ; injoignable, elle se tait (une ligne le dit) et les
///    résultats locaux restent.
///
/// Toucher un message ouvre la discussion **sur lui**, mis en évidence
/// (`/group-chat/:id?message=<id>`) — le fil remonte l'historique s'il le faut.
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key});

  /// La pause avant d'interroger le serveur : une requête par mot, pas par
  /// lettre.
  static const Duration remoteDelay = Duration(milliseconds: 400);

  static const Key fieldKey = Key('chat_search_field');
  static const Key moreKey = Key('chat_search_more');

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final TextEditingController _field = TextEditingController();
  Timer? _remoteTimer;

  String _query = '';

  /// Chaque frappe numérote sa recherche : une réponse arrivée après une
  /// frappe plus récente est jetée.
  int _generation = 0;

  List<MessageSearchHit> _local = const [];
  List<MessageSearchHit> _remote = const [];
  bool _remoteLoading = false;
  bool _remoteHasMore = false;
  bool _remoteUnreachable = false;

  @override
  void dispose() {
    _remoteTimer?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final query = text.trim();
    final generation = ++_generation;
    _remoteTimer?.cancel();
    setState(() {
      _query = query;
      _remote = const [];
      _remoteHasMore = false;
      _remoteUnreachable = false;
      if (query.length < kMinSearchLength) _local = const [];
    });
    if (query.length < kMinSearchLength) return;

    final search = _repository();
    unawaited(
      search.searchLocal(query).then((hits) {
        if (!mounted || generation != _generation) return;
        setState(() => _local = hits);
      }).catchError((Object _) {}),
    );
    _remoteTimer = Timer(
      ChatSearchScreen.remoteDelay,
      () => _loadRemote(generation),
    );
  }

  Future<void> _loadRemote(int generation, {String? before}) async {
    if (!mounted || generation != _generation) return;
    setState(() => _remoteLoading = true);
    RemoteSearchPage? page;
    try {
      page = await _repository().searchRemote(_query, before: before);
    } catch (_) {
      page = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _remoteLoading = false;
      if (page == null) {
        _remoteUnreachable = true;
        _remoteHasMore = false;
        return;
      }
      _remote = [..._remote, ...page.hits];
      _remoteHasMore = page.hasMore;
    });
  }

  ChatSearchRepository _repository() =>
      ref.read(chatSearchRepositoryProvider(ref.read(echangesActorProvider)));

  void _openMessage(MessageSearchHit hit) {
    context.pushNamed(
      AppRoute.groupChat,
      pathParameters: {'id': hit.groupId},
      queryParameters: {'message': hit.messageId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final me = ref.watch(echangesActorProvider);
    final conversations =
        ref.watch(conversationsProvider(me)).value ?? const [];
    final titles = {for (final c in conversations) c.groupId: c};

    final searching = _query.length >= kMinSearchLength;
    final named = searching
        ? conversationsMatching(conversations, _query)
        : const <ConversationView>[];
    final localIds = {for (final h in _local) h.messageId};
    final messages = [
      ..._local,
      for (final h in _remote)
        if (!localIds.contains(h.messageId)) h,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.chatSearchTitle),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                key: ChatSearchScreen.fieldKey,
                controller: _field,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: l.chatSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: !searching
                  ? Padding(
                      padding: AppSpacing.screenPadding,
                      child: Text(
                        l.chatSearchMinLength(kMinSearchLength),
                        style: AppTypography.caption
                            .copyWith(color: palette.textSecondary),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      children: [
                        if (named.isNotEmpty) ...[
                          _SectionTitle(l.chatSearchChats),
                          for (final c in named)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.md,
                              ),
                              child: ConversationTile(
                                conversation: c,
                                onTap: () => context.pushNamed(
                                  AppRoute.groupChat,
                                  pathParameters: {'id': c.groupId},
                                ),
                              ),
                            ),
                        ],
                        if (messages.isNotEmpty) ...[
                          _SectionTitle(l.chatSearchMessages),
                          for (final hit in messages)
                            _MessageHitTile(
                              key: ValueKey('chat_search_hit_${hit.messageId}'),
                              hit: hit,
                              title: titles[hit.groupId]?.title,
                              onTap: () => _openMessage(hit),
                            ),
                        ],
                        if (_remoteLoading)
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_remoteHasMore)
                          Center(
                            child: TextButton(
                              key: ChatSearchScreen.moreKey,
                              onPressed: () => _loadRemote(
                                _generation,
                                before: _remote.isEmpty
                                    ? null
                                    : _remote.last.messageId,
                              ),
                              child: Text(l.chatSearchMore),
                            ),
                          ),
                        if (_remoteUnreachable)
                          Padding(
                            padding: AppSpacing.screenPadding,
                            child: Text(
                              l.chatSearchOffline,
                              style: AppTypography.caption
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                        if (named.isEmpty &&
                            messages.isEmpty &&
                            !_remoteLoading)
                          Padding(
                            padding: AppSpacing.screenPadding,
                            child: Text(
                              l.chatSearchNoResult,
                              style: AppTypography.body
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(label, style: AppTypography.h5),
    );
  }
}

/// Un message trouvé : la discussion, l'auteur, l'extrait, la date.
class _MessageHitTile extends StatelessWidget {
  const _MessageHitTile({
    super.key,
    required this.hit,
    required this.title,
    required this.onTap,
  });

  final MessageSearchHit hit;

  /// Le nom de la discussion, ou `null` si la liste ne la connaît pas encore.
  final String? title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final stamp = hit.createdAt;
    final heading = title ?? l.chatSearchUnknownChat;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(name: heading, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong,
                        ),
                      ),
                      if (stamp != null)
                        Text(
                          formatConversationStamp(stamp, l.intlLocale),
                          style: AppTypography.caption
                              .copyWith(color: palette.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hit.authorName == null
                        ? hit.body
                        : '${hit.authorName} : ${hit.body}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
