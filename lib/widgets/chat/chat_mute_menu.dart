import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/group_dao.dart' show isGroupMuted;
import '../../data/messaging/group_mute_setter.dart';
import '../../l10n/l10n_extension.dart';
import '../../state/echanges_providers.dart';

/// **Le menu « ⋮ » d'une discussion** (tranche M5) : mettre en sourdine — 8 h,
/// 1 semaine, toujours — ou réactiver les notifications.
///
/// Un widget à part, posé dans les `actions` de `ChatAppBar` par une seule
/// ligne de `group_chat_screen.dart` : plusieurs tranches touchent l'écran du
/// fil, et chacune y pose son emplacement sans réécrire celui des autres.
///
/// L'état affiché vient du **magasin** (`group_mutes`) ; le geste part au
/// serveur, et c'est la ligne qu'il rend — rangée dans le magasin — qui fait
/// changer le menu. Un refus se dit tout de suite : la sourdine se règle en
/// ligne (voir `GroupMuteSetter`).
class ChatMuteMenu extends ConsumerWidget {
  const ChatMuteMenu({super.key, required this.groupId});

  final String groupId;

  static const Key buttonKey = Key('chat_mute_menu');
  static const Key muteKey = Key('chat_mute_menu_mute');
  static const Key unmuteKey = Key('chat_mute_menu_unmute');

  /// Les trois durées, dans l'ordre de WhatsApp — une clé par durée pour les
  /// tests.
  static Key durationKey(MuteDuration duration) =>
      Key('chat_mute_duration_${duration.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final mute = ref.watch(groupMuteProvider(groupId)).value;
    final muted = mute != null &&
        isGroupMuted(
          mutedUntil: mute.mutedUntil,
          mutedForever: mute.mutedForever,
          now: DateTime.now(),
        );

    return PopupMenuButton<_MenuChoice>(
      key: buttonKey,
      tooltip: l.chatMuteMenu,
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (choice) => switch (choice) {
        _MenuChoice.mute => _chooseDuration(context, ref),
        _MenuChoice.unmute => _apply(context, ref, null),
      },
      itemBuilder: (_) => [
        if (muted)
          PopupMenuItem(
            key: unmuteKey,
            value: _MenuChoice.unmute,
            child: Text(l.chatUnmute),
          )
        else
          PopupMenuItem(
            key: muteKey,
            value: _MenuChoice.mute,
            child: Text(l.chatMute),
          ),
      ],
    );
  }

  Future<void> _chooseDuration(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final duration = await showDialog<MuteDuration>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l.chatMuteTitle),
        children: [
          for (final (duration, label) in [
            (MuteDuration.eightHours, l.chatMuteEightHours),
            (MuteDuration.oneWeek, l.chatMuteOneWeek),
            (MuteDuration.forever, l.chatMuteForever),
          ])
            SimpleDialogOption(
              key: durationKey(duration),
              onPressed: () => Navigator.of(dialogContext).pop(duration),
              child: Text(label),
            ),
        ],
      ),
    );
    if (duration == null || !context.mounted) return;
    await _apply(context, ref, duration);
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    MuteDuration? duration,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.chatMuteFailed;
    final ok = await ref
        .read(groupMuteSetterProvider)
        .set(groupId: groupId, duration: duration);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

enum _MenuChoice { mute, unmute }
