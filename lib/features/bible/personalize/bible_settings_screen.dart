/// **Paramètres du module Bible** (M4, mobile#202) : thème du lecteur, voix,
/// versions, rappels, À propos (licences de la voix et des polices).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import 'bible_prefs.dart';
import 'bible_reminders.dart';
import 'personalize_routes.dart';
import 'piper_voice.dart';

class BibleSettingsScreen extends ConsumerStatefulWidget {
  const BibleSettingsScreen({super.key});

  static const Key appearanceKey = Key('bible_settings_appearance');
  static const Key versionsKey = Key('bible_settings_versions');
  static Key voiceKey(BibleVoice v) => Key('bible_settings_voice_${v.name}');
  static const Key piperDownloadKey = Key('bible_settings_piper_download');
  static const Key piperRemoveKey = Key('bible_settings_piper_remove');
  static const Key verseReminderKey = Key('bible_settings_verse_reminder');
  static const Key planReminderKey = Key('bible_settings_plan_reminder');
  static const Key aboutKey = Key('bible_settings_about');

  @override
  ConsumerState<BibleSettingsScreen> createState() =>
      _BibleSettingsScreenState();
}

class _BibleSettingsScreenState extends ConsumerState<BibleSettingsScreen> {
  double? _piperProgress;
  bool _piperFailed = false;

  Future<void> _update(BiblePrefs Function(BiblePrefs) change) async {
    await ref.read(biblePrefsProvider.notifier).update(change);
    await ref.read(bibleRemindersRefreshProvider)();
  }

  Future<void> _toggleVerseReminder(bool on) async {
    await _update((p) => p.copyWith(verseReminder: on));
    if (ref.read(bibleIsMemberProvider)) {
      await ref.read(bibleVerseOfDaySubscriptionProvider)(on);
    }
  }

  Future<void> _pickTime(
    int minutes,
    BiblePrefs Function(BiblePrefs, int) apply,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    await _update((p) => apply(p, picked.hour * 60 + picked.minute));
  }

  Future<void> _downloadPiper() async {
    setState(() {
      _piperProgress = 0;
      _piperFailed = false;
    });
    try {
      await for (final p in ref.read(piperVoiceStoreProvider).install()) {
        if (mounted) setState(() => _piperProgress = p);
      }
      ref.invalidate(piperVoiceProvider);
    } on Object {
      if (mounted) setState(() => _piperFailed = true);
    } finally {
      if (mounted) setState(() => _piperProgress = null);
    }
  }

  Future<void> _removePiper() async {
    await ref.read(piperVoiceStoreProvider).remove();
    ref.invalidate(piperVoiceProvider);
    if (ref.read(biblePrefsProvider).voice == BibleVoice.piper) {
      await _update((p) => p.copyWith(voice: BibleVoice.system));
    }
  }

  String _time(int minutes) => TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      ).format(context);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prefs = ref.watch(biblePrefsProvider);
    final piper = ref.watch(piperVoiceProvider).value;
    final progress = _piperProgress;
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4SettingsTitle),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          ListTile(
            key: BibleSettingsScreen.appearanceKey,
            leading: const Icon(Icons.text_fields),
            title: Text(l.bibleM4AppearanceTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                openBiblePersonalize(ref, BiblePersonalizePage.appearance),
          ),
          ListTile(
            key: BibleSettingsScreen.versionsKey,
            leading: const Icon(Icons.download_for_offline_outlined),
            title: Text(l.bibleM4VersionsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                openBiblePersonalize(ref, BiblePersonalizePage.offline),
          ),
          const Divider(),
          _Header(l.bibleM4Voice),
          ListTile(
            key: BibleSettingsScreen.voiceKey(BibleVoice.system),
            leading: Icon(
              prefs.voice == BibleVoice.system
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(l.bibleM4VoiceSystem),
            onTap: () => _update((p) => p.copyWith(voice: BibleVoice.system)),
          ),
          if (!kIsWeb)
            ListTile(
              key: BibleSettingsScreen.voiceKey(BibleVoice.piper),
              leading: Icon(
                prefs.voice == BibleVoice.piper && piper != null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(l.bibleM4VoicePiper),
              subtitle: Text(
                _piperFailed
                    ? l.bibleM4VoicePiperFailed
                    : piper == null
                        ? l.bibleM4VoicePiperSize(
                            (kPiperBytes / 1e6).toStringAsFixed(0),
                          )
                        : l.bibleM4VoicePiperReady,
              ),
              onTap: piper == null
                  ? null
                  : () => _update((p) => p.copyWith(voice: BibleVoice.piper)),
              trailing: progress != null
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(value: progress),
                    )
                  : piper == null
                      ? IconButton(
                          key: BibleSettingsScreen.piperDownloadKey,
                          tooltip: l.bibleM4Download,
                          icon: const Icon(Icons.download),
                          onPressed: _downloadPiper,
                        )
                      : IconButton(
                          key: BibleSettingsScreen.piperRemoveKey,
                          tooltip: l.bibleM4Remove,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _removePiper,
                        ),
            ),
          const Divider(),
          _Header(l.bibleM4Reminders),
          SwitchListTile(
            key: BibleSettingsScreen.verseReminderKey,
            title: Text(l.bibleM4VerseOfDayTitle),
            subtitle: Text(_time(prefs.verseReminderMinutes)),
            value: prefs.verseReminder,
            onChanged: (on) => unawaited(_toggleVerseReminder(on)),
          ),
          if (prefs.verseReminder)
            TextButton(
              onPressed: () => _pickTime(
                prefs.verseReminderMinutes,
                (p, m) => p.copyWith(verseReminderMinutes: m),
              ),
              child: Text(l.bibleM4ChangeTime),
            ),
          SwitchListTile(
            key: BibleSettingsScreen.planReminderKey,
            title: Text(l.bibleM4PlanReminderTitle),
            subtitle: Text(_time(prefs.planReminderMinutes)),
            value: prefs.planReminder,
            onChanged: (on) =>
                unawaited(_update((p) => p.copyWith(planReminder: on))),
          ),
          if (prefs.planReminder)
            TextButton(
              onPressed: () => _pickTime(
                prefs.planReminderMinutes,
                (p, m) => p.copyWith(planReminderMinutes: m),
              ),
              child: Text(l.bibleM4ChangeTime),
            ),
          const Divider(),
          _Header(l.bibleM4About),
          Padding(
            key: BibleSettingsScreen.aboutKey,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l.bibleM4Licenses),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(text, style: AppTypography.h5),
      );
}
