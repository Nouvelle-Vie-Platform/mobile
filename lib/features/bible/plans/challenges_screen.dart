/// **Les défis communautaires** (M5, #203, décision 16) : membres seulement.
/// L'invité voit les défis et une carte « Connectez-vous pour rejoindre » ;
/// le membre rejoint sous un **nom biblique** choisi dans la liste des noms
/// libres du défi, puis suit le plan et le classement — qui ne montre que des
/// pseudonymes, jamais un vrai nom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart' show BibleChallengeRow;
import '../../../l10n/l10n_extension.dart';
import '../../../state/session_gate.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/error_message.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_error_state.dart';
import '../data/bible_providers.dart';
import 'plan_logic.dart';
import 'plans_api.dart';
import 'plans_providers.dart';
import 'plans_screen.dart';
import 'plans_store.dart';
import 'plans_widgets.dart';

class BibleChallengesScreen extends ConsumerWidget {
  const BibleChallengesScreen({super.key});

  static const Key guestCardKey = Key('bible_challenges_guest');
  static Key joinKey(String id) => Key('bible_challenge_join_$id');
  static Key leaderboardKey(String id) => Key('bible_challenge_board_$id');
  static Key openKey(String id) => Key('bible_challenge_open_$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final member = ref.watch(bibleIsMemberProvider);
    final challenges = ref.watch(bibleChallengesProvider).value;
    final plans = ref.watch(biblePublishedPlansProvider).value;
    final enrollments = ref.watch(biblePlanEnrollmentsProvider).value;
    final dates = MaterialLocalizations.of(context);
    String day(String? d) =>
        parseDay(d) == null ? '' : dates.formatMediumDate(parseDay(d)!);
    return BiblePlansScaffold(
      title: l.biblePlansChallengesTitle,
      body: challenges == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                if (!member)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppCard(
                      key: guestCardKey,
                      color: context.palette.infoBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.biblePlansGuestTitle, style: AppTypography.h5),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l.biblePlansGuestBody),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: () => ref.requireSession(action: () {}),
                            child: Text(l.biblePlansSignIn),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (challenges.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      l.biblePlansChallengesEmpty,
                      style: AppTypography.body.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                for (final c in challenges)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      0,
                    ),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: AppTypography.h5),
                          if (publishedPlan(plans, c.planId) case final p?)
                            Text(p.title, style: AppTypography.body),
                          Text(
                            l.biblePlansChallengeDates(
                              day(c.startsOn),
                              day(c.endsOn),
                            ),
                            style: AppTypography.caption.copyWith(
                              color: context.palette.textSecondary,
                            ),
                          ),
                          if (member) ...[
                            const SizedBox(height: AppSpacing.md),
                            _MemberActions(
                              challenge: c,
                              enrollment: enrollmentForChallenge(
                                enrollments,
                                c.id,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MemberActions extends ConsumerWidget {
  const _MemberActions({required this.challenge, required this.enrollment});

  final BibleChallengeRow challenge;
  final PlanEnrollment? enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = challenge;
    final e = enrollment;
    if (e == null) {
      return FilledButton.icon(
        key: BibleChallengesScreen.joinKey(c.id),
        icon: const Icon(Icons.group_add_outlined),
        label: Text(l.biblePlansJoin),
        onPressed: () => joinBibleChallenge(context, ref, c),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          avatar: const Icon(Icons.check, color: AppColors.success, size: 18),
          label: Text(l.biblePlansJoined),
        ),
        OutlinedButton(
          key: BibleChallengesScreen.openKey(c.id),
          onPressed: () => pushBiblePlansPage<void>(
            ref,
            BiblePlanDetailScreen(enrollmentId: e.id),
          ),
          child: Text(l.biblePlansOpenPlan),
        ),
        OutlinedButton(
          key: BibleChallengesScreen.leaderboardKey(c.id),
          onPressed: () => pushBiblePlansPage<void>(
            ref,
            BibleLeaderboardScreen(challengeId: c.id, title: c.title),
          ),
          child: Text(l.biblePlansLeaderboard),
        ),
      ],
    );
  }
}

/// **Rejoindre un défi** : les noms libres, le choix, le `join`. Un 409 « nom
/// pris » le dit et rouvre la liste rafraîchie ; « déjà inscrit » le dit et
/// recrée l'inscription au plan si l'appareil l'a perdue.
Future<void> joinBibleChallenge(
  BuildContext context,
  WidgetRef ref,
  BibleChallengeRow c,
) async {
  final l = context.l10n;
  final api = ref.read(biblePlansApiProvider);
  final store = ref.read(biblePlansStoreProvider);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  Future<void> enroll() => store.enroll(
        source: PlanSource.published,
        planId: c.planId,
        startedOn: parseDay(c.startsOn) ?? ref.read(bibleTodayProvider),
        challengeId: c.id,
      );

  while (context.mounted) {
    final List<String> names;
    try {
      names = await api.pseudonyms(c.id);
    } catch (e) {
      say(errorStateMessage(e, l));
      return;
    }
    if (!context.mounted) return;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PseudonymSheet(names: names),
    );
    if (name == null) return;
    final JoinOutcome outcome;
    try {
      outcome = await api.join(c.id, name);
    } catch (e) {
      say(errorStateMessage(e, l));
      return;
    }
    switch (outcome) {
      case JoinOutcome.joined:
        await enroll();
        return;
      case JoinOutcome.alreadyJoined:
        say(l.biblePlansAlreadyJoined);
        if (enrollmentForChallenge(
              ref.read(biblePlanEnrollmentsProvider).value,
              c.id,
            ) ==
            null) {
          await enroll();
        }
        return;
      case JoinOutcome.nameTaken:
        say(l.biblePlansNameTaken);
    }
  }
}

/// **Le choix du nom biblique** : une recherche dans la liste ; dépile avec
/// le nom choisi.
class PseudonymSheet extends StatefulWidget {
  const PseudonymSheet({super.key, required this.names});

  final List<String> names;

  static const Key searchKey = Key('bible_pseudonym_search');
  static Key nameKey(String name) => Key('bible_pseudonym_$name');

  @override
  State<PseudonymSheet> createState() => _PseudonymSheetState();
}

class _PseudonymSheetState extends State<PseudonymSheet> {
  String _query = '';

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _fold(_query.trim());
    final shown = [
      for (final n in widget.names)
        if (q.isEmpty || _fold(n).contains(q)) n,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.biblePlansPickName, style: AppTypography.h4),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.biblePlansPickNameBody,
                    style: AppTypography.body.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: PseudonymSheet.searchKey,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l.biblePlansPickNameSearch,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, i) => ListTile(
                  key: PseudonymSheet.nameKey(shown[i]),
                  title: Text(shown[i]),
                  onTap: () => Navigator.of(context).pop(shown[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Le classement d'un défi**, relu à chaque ouverture (et en tirant).
class BibleLeaderboardScreen extends ConsumerStatefulWidget {
  const BibleLeaderboardScreen({
    super.key,
    required this.challengeId,
    this.title,
  });

  final String challengeId;
  final String? title;

  static const Key meKey = Key('bible_leaderboard_me');

  @override
  ConsumerState<BibleLeaderboardScreen> createState() =>
      _BibleLeaderboardScreenState();
}

class _BibleLeaderboardScreenState
    extends ConsumerState<BibleLeaderboardScreen> {
  late Future<Leaderboard> _board = _load();

  Future<Leaderboard> _load() =>
      ref.read(biblePlansApiProvider).leaderboard(widget.challengeId);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _board = next);
    await next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    return BiblePlansScaffold(
      title: widget.title ?? l.biblePlansLeaderboard,
      body: FutureBuilder<Leaderboard>(
        future: _board,
        builder: (context, snap) {
          if (snap.hasError) {
            return AppErrorState(
              message: errorStateMessage(snap.error, l),
              retryLabel: l.biblePlansRetry,
              onRetry: _refresh,
            );
          }
          final board = snap.data;
          if (board == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = board.me?.pseudonym;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                PlansSectionTitle(
                  '${l.biblePlansLeaderboard} · ${l.biblePlansParticipants(board.participants)}',
                ),
                for (final e in board.entries)
                  ListTile(
                    key:
                        e.pseudonym == me ? BibleLeaderboardScreen.meKey : null,
                    tileColor: e.pseudonym == me
                        ? palette.primary.withValues(alpha: 0.10)
                        : null,
                    leading: CircleAvatar(
                      backgroundColor:
                          e.rank <= 3 ? AppColors.accent : palette.divider,
                      foregroundColor: AppColors.primary,
                      child: Text('${e.rank}'),
                    ),
                    title: Text(
                      e.pseudonym == me
                          ? '${e.pseudonym} (${l.biblePlansYou})'
                          : e.pseudonym,
                      style: e.pseudonym == me
                          ? AppTypography.bodyStrong
                          : AppTypography.body,
                    ),
                    subtitle: Text(
                        '${l.biblePlansOnTime(e.onTime)} · ${l.biblePlansStreak(e.streak)}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
