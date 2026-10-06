import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messaging/messaging_signals_api.dart';
import '../l10n/l10n_extension.dart';
import '../state/receipts_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_app_bar.dart';

/// **Confidentialité de la messagerie** (#142, tranche M3, décision 4) — deux
/// interrupteurs, poussés depuis le Profil.
///
/// - **Accusés de lecture** ;
/// - **Vu à et en ligne**.
///
/// ## La réciprocité est dite, pas seulement appliquée
///
/// Comme WhatsApp : qui coupe ne montre plus, **et ne voit plus**. Le serveur
/// l'applique (un accusé ou une présence qu'on n'a pas le droit de voir ne
/// part jamais) ; l'écran le dit sous chaque interrupteur, sans quoi couper
/// ses accusés et ne plus voir ceux des autres se lirait comme une panne.
///
/// ## Les réglages vivent sur le serveur
///
/// Ils suivent le compte d'un téléphone à l'autre, et c'est le serveur qui
/// filtre : ils se lisent (`GET /messaging/privacy`) et s'écrivent
/// (`PUT`) en ligne, jamais dans le magasin. L'interrupteur bascule tout de
/// suite ; un refus le remet en place et le dit.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  static const Key readReceiptsKey = Key('privacy_read_receipts');
  static const Key presenceKey = Key('privacy_presence');

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  MessagingPrivacy? _privacy;
  bool _failed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  void _retry() {
    setState(() => _failed = false);
    unawaited(_load());
  }

  Future<void> _load() async {
    // Pas de `setState` avant la première attente : appelée depuis
    // `initState`, elle lèverait.
    _failed = false;
    try {
      final privacy = await ref.read(messagingSignalsApiProvider).readPrivacy();
      if (mounted) setState(() => _privacy = privacy);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _set({bool? readReceipts, bool? presence}) async {
    final before = _privacy;
    if (before == null || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final failure = context.l10n.privacySaveError;
    setState(() {
      _saving = true;
      _privacy = before.copyWith(
        readReceipts: readReceipts,
        presence: presence,
      );
    });
    try {
      final saved = await ref
          .read(messagingSignalsApiProvider)
          .updatePrivacy(readReceipts: readReceipts, presence: presence);
      if (!mounted) return;
      setState(() => _privacy = saved);
      // Ce que je pouvais voir des autres a pu changer (réciprocité) : les
      // en-têtes relisent leur présence.
      if (presence != null) {
        ref.read(messagingEphemeralStoreProvider).forgetPresence();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _privacy = before);
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    final privacy = _privacy;

    Widget body;
    if (privacy == null && _failed) {
      body = Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.privacyLoadError, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _retry, child: Text(l.stateRetry)),
            ],
          ),
        ),
      );
    } else if (privacy == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  key: PrivacySettingsScreen.readReceiptsKey,
                  value: privacy.readReceipts,
                  onChanged: (value) => _set(readReceipts: value),
                  title: Text(l.privacyReadReceipts),
                  subtitle: Text(
                    l.privacyReadReceiptsHint,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
                Divider(height: 1, color: palette.divider),
                SwitchListTile(
                  key: PrivacySettingsScreen.presenceKey,
                  value: privacy.presence,
                  onChanged: (value) => _set(presence: value),
                  title: Text(l.privacyPresence),
                  subtitle: Text(
                    l.privacyPresenceHint,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BrandAppBar(title: l.privacyTitle),
      body: body,
    );
  }
}
