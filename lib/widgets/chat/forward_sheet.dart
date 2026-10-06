import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../state/echanges_providers.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Le plafond du serveur : cinq discussions par transfert.
const int kForwardMaxTargets = 5;

/// **« Transférer à… »** (M2, #141) — mes discussions **où je peux écrire**
/// (celles où le serveur refuserait la copie ne sont pas proposées), cinq au
/// plus. Rend les groupes choisis, ou `null` si la feuille est fermée.
Future<List<String>?> showForwardSheet(
  BuildContext context, {
  required String? actor,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _ForwardSheet(actor: actor),
  );
}

class _ForwardSheet extends ConsumerStatefulWidget {
  const _ForwardSheet({required this.actor});

  final String? actor;

  @override
  ConsumerState<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<_ForwardSheet> {
  final List<String> _picked = [];

  void _toggle(ConversationView conversation) {
    setState(() {
      if (_picked.remove(conversation.groupId)) return;
      if (_picked.length >= kForwardMaxTargets) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.chatForwardLimit)),
        );
        return;
      }
      _picked.add(conversation.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final conversations =
        (ref.watch(conversationsProvider(widget.actor)).value ??
                const <ConversationView>[])
            .where((c) => c.canWrite)
            .toList(growable: false);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          key: const Key('forward_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l.chatForwardTitle,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(l.chatForwardEmpty),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final conversation in conversations)
                      CheckboxListTile(
                        key: Key('forward_target_${conversation.groupId}'),
                        value: _picked.contains(conversation.groupId),
                        onChanged: (_) => _toggle(conversation),
                        title: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                key: const Key('forward_send'),
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(List.of(_picked)),
                icon: const Icon(Icons.send),
                label: Text(l.chatForwardSend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
