import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../state/push_providers.dart';
import '../state/theme_provider.dart' show settingsDaoProvider;
import 'menu_tile.dart';

/// **« Afficher le contenu des messages »** (tranche M5) — l'interrupteur du
/// profil qui masque le texte des notifications de messages.
///
/// Activé (le défaut) : la notification montre les derniers messages.
/// Désactivé : « Nouveau message », ou « Nouveau message de Ama » dans un
/// groupe — rien du texte. C'est un réglage de **ce téléphone** (l'écran
/// verrouillé est le sien), rangé dans le magasin parce que c'est le réveil de
/// l'application fermée, dans son propre isolate, qui le lit.
class NotificationPreviewTile extends ConsumerWidget {
  const NotificationPreviewTile({super.key});

  static const Key switchKey = Key('notification_preview_switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Tant que le magasin n'a pas répondu, on montre le défaut : oui.
    final shown = ref.watch(notificationPreviewProvider).value ?? true;

    void toggle(bool value) =>
        ref.read(settingsDaoProvider).setNotificationPreview(value);

    return MenuTile(
      icon: Icons.notifications_outlined,
      label: l.notificationPreviewSetting,
      subtitle: l.notificationPreviewSettingHint,
      showChevron: false,
      onTap: () => toggle(!shown),
      trailing: Switch(
        key: switchKey,
        value: shown,
        onChanged: toggle,
      ),
    );
  }
}
