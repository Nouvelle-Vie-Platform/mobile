/// **Versions et hors ligne** (M4, mobile#202, décision 9) : le catalogue
/// fusionné, « Télécharger » (l'archive réelle depuis C4), « Supprimer », et
/// le choix de la version active.
///
/// **L'invitation** (#265) en est une variante, sans en-tête : la coquille du
/// module la montre tant qu'aucune vraie Bible n'est téléchargée — un court
/// message, puis les seules vraies versions, avec la même ligne, le même
/// « Télécharger » et la même progression.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../state/sync_providers.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/brand_app_bar.dart';
import '../data/bible_providers.dart';
import 'bible_catalog.dart';

class BibleVersionsScreen extends ConsumerStatefulWidget {
  const BibleVersionsScreen({super.key, this.invitation = false});

  /// La page d'invitation de la coquille (#265), et non l'écran poussé.
  final bool invitation;

  static const Key invitationKey = Key('bible_invitation');

  static Key rowKey(String code) => Key('bible_version_row_$code');
  static Key downloadKey(String code) => Key('bible_version_download_$code');
  static Key removeKey(String code) => Key('bible_version_remove_$code');
  static Key activeKey(String code) => Key('bible_version_active_$code');

  @override
  ConsumerState<BibleVersionsScreen> createState() =>
      _BibleVersionsScreenState();
}

class _BibleVersionsScreenState extends ConsumerState<BibleVersionsScreen> {
  /// La progression des téléchargements en cours, par code.
  final Map<String, double> _progress = {};

  Future<void> _download(BibleCatalogEntry entry) async {
    final code = entry.version.code;
    setState(() => _progress[code] = 0);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.bibleM4DownloadFailed;
    final db = ref.read(appDatabaseProvider);
    final installer = ref.read(bibleInstallerProvider);
    final ensureIndexed = ref.read(bibleEnsureIndexedProvider);
    try {
      await for (final p
          in installer.install(db, entry, ensureIndexed: ensureIndexed)) {
        if (mounted) setState(() => _progress[code] = p);
      }
    } on Object {
      // Une archive refusée (empreinte, réseau) **n'installe rien** : le
      // fidèle doit savoir que le bouton n'a rien produit, sinon il le
      // regarde redevenir « Télécharger » sans explication.
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _progress.remove(code));
    }
  }

  void _select(String code) {
    ref.read(activeBibleVersionProvider.notifier).select(code);
    final s = ref.read(bibleReadingStateProvider).value;
    final book = s?.book;
    final chapter = s?.chapter;
    // La version devient durable avec la position ; sans position, elle
    // vaut pour la séance.
    if (book != null && chapter != null) {
      unawaited(
        ref.read(bibleDaoProvider).savePosition(
              member: ref.read(bibleIsMemberProvider),
              versionCode: code,
              book: book,
              chapter: chapter,
              verse: s?.verse,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invitation = widget.invitation;
    // Les exemples ne comptent jamais pour l'invitation : ce sont eux qu'elle
    // remplace. Sans autre ligne (premier lancement hors ligne, catalogue
    // pas encore synchronisé), elle invite à se connecter.
    final entries = [
      for (final e in ref.watch(mergedBibleCatalogProvider).entries)
        if (!invitation || !e.builtIn) e,
    ];
    final active = ref.watch(activeBibleVersionProvider);
    final list = ListView(
      key: invitation ? BibleVersionsScreen.invitationKey : null,
      padding: invitation
          ? AppSpacing.screenPadding.copyWith(top: AppSpacing.xl)
          : AppSpacing.screenPadding,
      children: [
        if (invitation) ...[
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: context.palette.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            entries.isEmpty ? l.bibleInviteOffline : l.bibleInviteDownload,
            textAlign: TextAlign.center,
            style: AppTypography.h5,
          ),
        ] else
          Text(l.bibleM4VersionsHint),
        const SizedBox(height: AppSpacing.md),
        for (final e in entries) _row(context, e, active),
      ],
    );
    if (invitation) return list;
    return Scaffold(
      appBar: BrandAppBar(title: l.bibleM4VersionsTitle),
      body: list,
    );
  }

  Widget _row(BuildContext context, BibleCatalogEntry e, String active) {
    final l = context.l10n;
    final v = e.version;
    final progress = _progress[v.code];
    final size = e.sizeBytes;

    /// La langue, la taille et « incluse » — ce qui aide à choisir quoi
    /// télécharger —, puis **la licence sur sa propre ligne** (#258).
    ///
    /// Elle en était partie le 26/10/2026 pour ne vivre qu'au portail. Mais
    /// plusieurs ayants droit exigent la mention **là où le texte est lu** (la
    /// S21 : « Reproduit avec aimable autorisation » ; l'éwé : Bible Society of
    /// Ghana et of Togo), et le portail n'est pas lu par le fidèle. Cet écran
    /// est l'endroit le plus proche du lecteur qui ne s'immisce pas dans le
    /// texte : un geste depuis la lecture, et c'est là que le fidèle choisit
    /// sa traduction.
    final facts = [
      v.language.toUpperCase(),
      if (size != null) l.bibleM4SizeMb((size / 1e6).toStringAsFixed(1)),
      if (e.builtIn) l.bibleM4VersionBuiltIn,
    ].join(' · ');
    final license = e.license;
    final subtitle = license == null ? facts : '$facts\n$license';
    final Widget trailing;
    if (progress != null) {
      trailing = SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(value: progress),
      );
    } else if (!v.installed) {
      trailing = e.downloadable
          ? IconButton(
              key: BibleVersionsScreen.downloadKey(v.code),
              tooltip: l.bibleM4Download,
              icon: const Icon(Icons.download_for_offline_outlined),
              onPressed: () => _download(e),
            )
          : Text(l.bibleM4VersionSoon);
    } else if (!e.builtIn) {
      trailing = IconButton(
        key: BibleVersionsScreen.removeKey(v.code),
        tooltip: l.bibleM4Remove,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(bibleInstallerProvider).remove(
              ref.read(appDatabaseProvider),
              v.code,
            ),
      );
    } else {
      trailing = const Icon(Icons.offline_pin_outlined);
    }
    return ListTile(
      key: BibleVersionsScreen.rowKey(v.code),
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        key: BibleVersionsScreen.activeKey(v.code),
        tooltip: l.bibleM4ActiveVersion,
        icon: Icon(
          v.code == active
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
        ),
        onPressed: v.installed ? () => _select(v.code) : null,
      ),
      title: Text(v.name),
      // La licence prend une ligne de plus : sans cela, `ListTile` la rogne.
      isThreeLine: license != null,
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
