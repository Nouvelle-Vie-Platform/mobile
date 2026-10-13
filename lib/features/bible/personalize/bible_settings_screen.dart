/// **Paramètres du module Bible** (M4, mobile#202) : thème du lecteur, voix,
/// versions, rappels, À propos (licences des polices).
library;

import 'dart:async';

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

class BibleSettingsScreen extends ConsumerStatefulWidget {
  const BibleSettingsScreen({super.key});

  static const Key appearanceKey = Key('bible_settings_appearance');
  static const Key versionsKey = Key('bible_settings_versions');
  static const Key voiceKey = Key('bible_settings_voice');
  static const Key verseReminderKey = Key('bible_settings_verse_reminder');
  static const Key planReminderKey = Key('bible_settings_plan_reminder');
  static const Key aboutKey = Key('bible_settings_about');

  @override
  ConsumerState<BibleSettingsScreen> createState() =>
      _BibleSettingsScreenState();
}

class _BibleSettingsScreenState extends ConsumerState<BibleSettingsScreen> {
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

  String _time(int minutes) => TimeOfDay(
        hour: minutes ~/ 60,
        minute: minutes % 60,
      ).format(context);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prefs = ref.watch(biblePrefsProvider);
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
          // La voix du système seulement : la voix naturelle Piper est
          // retirée (espeak-ng, GPL 3.0, incompatible avec les magasins).
          ListTile(
            key: BibleSettingsScreen.voiceKey,
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(l.bibleM4VoiceSystem),
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
