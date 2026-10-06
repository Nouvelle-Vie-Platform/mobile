import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/messaging/messaging_signals_api.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../models/receipt_view.dart';
import '../../state/echanges_providers.dart';
import '../../state/receipts_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/presence_labels.dart';
import '../app_avatar.dart';
import 'receipt_mark.dart';

/// **L'appui long sur un de mes messages** (#142, tranche M3) : le menu, dont
/// la seule entrée de cette tranche est « Infos ». Les autres gestes (répondre,
/// copier, transférer…) viennent avec leur tranche.
Future<void> showMyMessageActions(
  BuildContext context, {
  required GroupMessageView message,
  required GroupDetailView group,
}) async {
  final l = context.l10n;
  final open = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('message_action_info'),
            leading: const Icon(Icons.info_outline),
            title: Text(l.messageInfoAction),
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    ),
  );
  if (open != true || !context.mounted) return;
  await showMessageInfo(context, message: message, group: group);
}

/// **« Infos du message »** — qui a reçu, qui a lu, avec l'heure. Lu en ligne
/// (`GET /groups/:id/messages/:messageId/receipts`), jamais stocké ; relu à
/// chaque changement de la coche du message (un `receipt.updated` arrivé
/// pendant que la feuille est ouverte).
///
/// La réciprocité (tête-à-tête seulement — en groupe, le réglage ne
/// s'applique pas) est appliquée par le serveur : une lecture cachée arrive
/// comme « pas lue », et l'écran la montre comme telle — il n'a aucun moyen de
/// les distinguer, et c'est voulu.
Future<void> showMessageInfo(
  BuildContext context, {
  required GroupMessageView message,
  required GroupDetailView group,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MessageInfoSheet(message: message, group: group),
  );
}

class MessageInfoSheet extends ConsumerStatefulWidget {
  const MessageInfoSheet({
    super.key,
    required this.message,
    required this.group,
  });

  final GroupMessageView message;
  final GroupDetailView group;

  @override
  ConsumerState<MessageInfoSheet> createState() => _MessageInfoSheetState();
}

class _MessageInfoSheetState extends ConsumerState<MessageInfoSheet> {
  late Future<List<MessageRecipientReceipt>> _recipients = _load();

  Future<List<MessageRecipientReceipt>> _load() =>
      ref.read(messagingSignalsApiProvider).messageReceipts(
            groupId: widget.group.groupId,
            messageId: widget.message.id,
          );

  void _reload() => setState(() => _recipients = _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(echangesActorProvider);
    // La coche du message bouge (canal ou synchro) : la liste a pu changer.
    ref.listen(
      messageReceiptsProvider((actor: me, id: widget.group.groupId))
          .select((async) => async.value?[widget.message.id]),
      (previous, next) {
        if (previous != next) _reload();
      },
    );

    final names = {
      for (final member in widget.group.members)
        member.userId: member.displayName,
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.messageInfoTitle, style: AppTypography.h5),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: FutureBuilder<List<MessageRecipientReceipt>>(
                  future: _recipients,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        l.messageInfoError,
                        key: const Key('message_info_error'),
                      );
                    }
                    final recipients = snapshot.data;
                    if (recipients == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _RecipientsList(
                      recipients: recipients,
                      names: names,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trois sections, dans l'ordre de WhatsApp : **Lu par**, **Distribué à**, puis
/// ceux qui ne l'ont pas encore reçu. Une section vide ne se rend pas.
class _RecipientsList extends StatelessWidget {
  const _RecipientsList({required this.recipients, required this.names});

  final List<MessageRecipientReceipt> recipients;
  final Map<String, String?> names;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final read = recipients.where((r) => r.readAt != null).toList();
    final delivered = recipients
        .where((r) => r.readAt == null && r.deliveredAt != null)
        .toList();
    final pending = recipients.where((r) => r.deliveredAt == null).toList();

    if (recipients.isEmpty) {
      return Text(l.messageInfoEmpty);
    }

    return ListView(
      shrinkWrap: true,
      children: [
        if (read.isNotEmpty) ...[
          _Header(
            label: l.messageInfoReadBy,
            mark: const ReceiptMark(status: ReceiptStatus.read),
          ),
          for (final r in read)
            _RecipientRow(name: names[r.userId], at: r.readAt),
        ],
        if (delivered.isNotEmpty) ...[
          _Header(
            label: l.messageInfoDeliveredTo,
            mark: const ReceiptMark(status: ReceiptStatus.delivered),
          ),
          for (final r in delivered)
            _RecipientRow(name: names[r.userId], at: r.deliveredAt),
        ],
        if (pending.isNotEmpty) ...[
          _Header(label: l.messageInfoPending),
          for (final r in pending) _RecipientRow(name: names[r.userId]),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, this.mark});

  final String label;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Row(
        children: [
          if (mark != null) ...[
            // La coche est blanche sur la bulle ; ici elle est posée sur une
            // pastille de la teinte de la bulle, pour garder sa lecture.
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.textSecondary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: mark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.name, this.at});

  /// `null` : le profil n'est pas (encore) arrivé — avatar neutre, et un tiret
  /// plutôt qu'un nom inventé.
  final String? name;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final hasName = name != null && name!.trim().isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: hasName
          ? AppAvatar(name: name!, size: 36)
          : const AppAvatar.neutral(size: 36),
      title: Text(hasName ? name! : '—'),
      subtitle: at == null
          ? null
          : Text(
              receiptInstantLabel(l, at!),
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
    );
  }
}
