/// **Les feuilles de la page live** (#135) : le pseudo d'un invité, les gestes
/// sur un message, et la file des signalements d'un modérateur.
///
/// Toutes passent par le contrôleur (`radioLiveProvider`) ; aucune ne parle au
/// réseau elle-même. Une feuille est une fenêtre surgissante : le mini-lecteur
/// s'efface déjà sous elle (#117), et il est de toute façon masqué sur `/radio`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/radio/radio_live.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../state/radio_live_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Un message bref, en bas de l'écran. Rien quand il n'y a pas de messager
/// (un test qui monte un widget nu).
void showRadioLiveMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// **« Choisissez un pseudo »** — rend `true` quand le pseudo est enregistré.
///
/// S'ouvre quand le serveur répond `E_RADIO_PSEUDONYM_REQUIRED` à un invité qui
/// écrit ou signale ; l'appelant **renvoie** alors son geste, sans que
/// l'auditeur ait à le refaire. Le serveur se souvient du pseudo (lié au jeton
/// d'appareil) : la feuille ne revient pas les fois suivantes.
Future<bool> showRadioPseudonymSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const RadioPseudonymSheet(),
  );
  return saved ?? false;
}

class RadioPseudonymSheet extends ConsumerStatefulWidget {
  const RadioPseudonymSheet({super.key});

  static const Key fieldKey = Key('radio_pseudonym_field');
  static const Key confirmKey = Key('radio_pseudonym_confirm');

  @override
  ConsumerState<RadioPseudonymSheet> createState() =>
      _RadioPseudonymSheetState();
}

class _RadioPseudonymSheetState extends ConsumerState<RadioPseudonymSheet> {
  final _field = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    final outcome =
        await ref.read(radioLiveProvider.notifier).savePseudonym(_field.text);
    if (!mounted) return;
    if (outcome == RadioPseudonymOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = switch (outcome) {
        RadioPseudonymOutcome.invalid => l10n.radioPseudonymInvalid,
        RadioPseudonymOutcome.throttled => l10n.radioPseudonymThrottled,
        _ => l10n.radioPseudonymFailed,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.radioPseudonymTitle,
            style: AppTypography.h3.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.radioPseudonymMessage,
            style: AppTypography.body.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: RadioPseudonymSheet.fieldKey,
            controller: _field,
            autofocus: true,
            maxLength: kRadioPseudonymMax,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              hintText: l10n.radioPseudonymHint,
              errorText: _error,
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: RadioPseudonymSheet.confirmKey,
            onPressed: _saving ? null : _confirm,
            child: Text(l10n.radioPseudonymConfirm),
          ),
        ],
      ),
    );
  }
}

/// **Les gestes sur un message**, à l'appui long : signaler, pour tout le
/// monde ; masquer, réduire au silence et réinitialiser le pseudo, pour un
/// modérateur — et **seulement** pour lui (`viewer.moderator`).
Future<void> showRadioMessageActions(
  BuildContext context,
  RadioComment comment, {
  required bool moderator,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = sheet.l10n;
      void run(Future<void> Function() action) {
        Navigator.of(sheet).pop();
        action();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: RadioMessageActionKeys.report,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.radioReportAction),
              onTap: () => run(() => reportRadioComment(context, comment.id)),
            ),
            if (moderator) ...[
              ListTile(
                key: RadioMessageActionKeys.hide,
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(l10n.radioModHide),
                onTap: () => run(() => moderateRadioComment(
                      context,
                      comment.id,
                      RadioModerationAction.hide,
                    )),
              ),
              ListTile(
                key: RadioMessageActionKeys.silence,
                leading: const Icon(Icons.voice_over_off_outlined),
                title: Text(l10n.radioModSilence),
                onTap: () => run(() => moderateRadioComment(
                      context,
                      comment.id,
                      RadioModerationAction.silence,
                    )),
              ),
              if (comment.byGuest)
                ListTile(
                  key: RadioMessageActionKeys.resetPseudonym,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.radioModResetPseudonym),
                  onTap: () => run(() => moderateRadioComment(
                        context,
                        comment.id,
                        RadioModerationAction.resetPseudonym,
                      )),
                ),
            ],
          ],
        ),
      );
    },
  );
}

/// Les clés des gestes, visées par les tests.
abstract final class RadioMessageActionKeys {
  static const Key report = Key('radio_action_report');
  static const Key hide = Key('radio_action_hide');
  static const Key silence = Key('radio_action_silence');
  static const Key resetPseudonym = Key('radio_action_reset_pseudonym');
  static const Key keep = Key('radio_action_keep');
}

/// **Signale un message**, en passant par le pseudo si le serveur le demande —
/// puis le signalement repart de lui-même.
Future<void> reportRadioComment(BuildContext context, String commentId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = context.l10n;
  final live = container.read(radioLiveProvider.notifier);
  var outcome = await live.report(commentId);
  if (outcome == RadioReportOutcome.pseudonymRequired) {
    if (!context.mounted) return;
    if (!await showRadioPseudonymSheet(context)) return;
    outcome = await live.report(commentId);
  }
  if (!context.mounted) return;
  showRadioLiveMessage(
      context,
      switch (outcome) {
        RadioReportOutcome.reported => l10n.radioReported,
        RadioReportOutcome.alreadyReported => l10n.radioAlreadyReported,
        RadioReportOutcome.gone => l10n.radioMessageGone,
        _ => l10n.radioActionFailed,
      });
}

/// Les quatre gestes d'un modérateur.
enum RadioModerationAction { hide, keep, silence, resetPseudonym }

Future<void> moderateRadioComment(
  BuildContext context,
  String commentId,
  RadioModerationAction action,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final l10n = context.l10n;
  final live = container.read(radioLiveProvider.notifier);
  final outcome = await switch (action) {
    RadioModerationAction.hide => live.hide(commentId),
    RadioModerationAction.keep => live.keep(commentId),
    RadioModerationAction.silence => live.silence(commentId),
    RadioModerationAction.resetPseudonym => live.resetPseudonym(commentId),
  };
  if (!context.mounted) return;
  showRadioLiveMessage(context, _moderationMessage(action, outcome, l10n));
}

String _moderationMessage(
  RadioModerationAction action,
  RadioModerationOutcome outcome,
  AppLocalizations l10n,
) =>
    switch (outcome) {
      RadioModerationOutcome.done => switch (action) {
          RadioModerationAction.hide => l10n.radioModHidden,
          RadioModerationAction.keep => l10n.radioModKept,
          RadioModerationAction.silence => l10n.radioModSilenced,
          RadioModerationAction.resetPseudonym => l10n.radioModPseudonymReset,
        },
      RadioModerationOutcome.notGuest => l10n.radioModNotGuest,
      RadioModerationOutcome.gone => l10n.radioMessageGone,
      RadioModerationOutcome.failed => l10n.radioActionFailed,
    };

/// **La file des signalements** d'un modérateur : chaque message, son nombre de
/// signalements, et deux décisions — garder ou masquer. Elle se tient à jour
/// pendant qu'elle est ouverte (canal privé `radio/moderation`).
Future<void> showRadioReportedQueue(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const RadioReportedQueueSheet(),
  );
}

class RadioReportedQueueSheet extends ConsumerWidget {
  const RadioReportedQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final items = ref.watch(radioLiveProvider.select((s) => s.reported));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                l10n.radioReportedQueue,
                style: AppTypography.h3.copyWith(color: palette.textPrimary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.radioReportedEmpty,
                  style:
                      AppTypography.body.copyWith(color: palette.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ReportedTile(item: items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportedTile extends StatelessWidget {
  const _ReportedTile({required this.item});

  final RadioReportedComment item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final comment = item.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.authorName,
            style:
                AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            comment.body,
            style: AppTypography.body.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.radioReportedCount(item.pendingReports),
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: RadioMessageActionKeys.keep,
                onPressed: () => moderateRadioComment(
                  context,
                  comment.id,
                  RadioModerationAction.keep,
                ),
                child: Text(l10n.radioModKeep),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                key: RadioMessageActionKeys.hide,
                onPressed: () => moderateRadioComment(
                  context,
                  comment.id,
                  RadioModerationAction.hide,
                ),
                child: Text(l10n.radioModHide),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
