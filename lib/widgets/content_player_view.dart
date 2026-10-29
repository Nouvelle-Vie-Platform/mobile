import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../data/local/app_database.dart';
import '../data/repositories/notes_repository.dart';
import '../data/install/install_prompt.dart';
import '../data/local/tables/download_tables.dart';
import '../data/players/content_player.dart';
import '../l10n/l10n_extension.dart';
import '../models/content_view.dart';
import '../router/app_router.dart';
import '../state/downloads_providers.dart';
import '../state/install_providers.dart';
import '../state/playback_controller.dart';
import '../state/player_providers.dart';
import '../state/season_providers.dart';
import '../state/session_gate.dart';
import '../state/notes_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/error_message.dart';
import '../utils/name_list.dart';
import 'app_error_state.dart';
import 'content_absence.dart';
import '../core/config/radio_config.dart';

const _fallbackBase = Color(kBrandFallbackColor);

/// Le lecteur plein écran d'un contenu de médiathèque ou d'un flux direct.
class ContentPlayerView extends ConsumerStatefulWidget {
  const ContentPlayerView({
    super.key,
    required this.content,
    required this.chromeTitle,
    required this.retractedTitle,
    required this.retractedMessage,
    required this.onRetry,
    this.errorTitle,
    this.errorMessage,
    this.guests,
    this.downloadContentType,
    this.isLive = false,
    this.onStop,
    this.fallbackBackgroundAsset,
    this.openSource,
    this.scene,
  });

  /// **La mise en page de l'appelant, à la place de celle de la fiche** (#135).
  ///
  /// `null` — le cas de la médiathèque — garde la fiche : visuel carré, titre,
  /// orateur, commandes.
  ///
  /// Non nul, il **remplace entièrement** le corps de l'écran lecteur, et
  /// **seulement** lui : le chargement (`_loadOnce`, [openSource]), le geste de
  /// lecture (`_togglePlayback`), la rétractation, les états de chargement,
  /// d'échec et d'absence, et la cascade du fond restent ici. L'appelant reçoit
  /// les pièces déjà câblées ([ContentPlayerSceneParts]) et les dispose à sa
  /// façon. Seule la page live de la radio s'en sert : sa forme plein écran
  /// (décision 12 du plan radio live) n'a rien d'une fiche, mais son écoute doit
  /// rester exactement celle que #108, #110 et #125 ont rendue sûre.
  ///
  /// Il succède au paramètre `stage` de #125, dont l'unique appelant était
  /// cette même page : la scène centrale « dit l'état réel de l'antenne » vit
  /// désormais dans la mise en page de la radio, avec le reste.
  final Widget Function(BuildContext context, ContentPlayerSceneParts parts)?
      scene;

  /// **Comment la source s'ouvre, quand cet écran ne doit pas l'ouvrir
  /// lui-même** (#110).
  ///
  /// `null` — le cas de la médiathèque — garde le comportement d'origine : cet
  /// écran résout le téléchargement et charge par le contrôleur global.
  ///
  /// Non nul, il **remplace entièrement** le chargement : ni résolution de
  /// téléchargement, ni `load`, ni déplacement vers la position de reprise. C'est
  /// l'appelant qui ouvre, à sa façon, et qui joue s'il le veut.
  ///
  /// ⚠️ **Il existe pour une seule raison, et elle est mesurée** : l'antenne de
  /// New Life Radio ne s'ouvre qu'après une **poignée de main par cookie**
  /// (#108), et un chargement de `content.playlistUrl` écrit ici ne la porte
  /// pas. Deux chemins y tombaient — un lien profond vers `/radio`, et la course
  /// du second appui pendant le pré-vol de cinq secondes —, et les deux
  /// donnaient un `401 {"error":"session not found"}` que rien à l'écran ne
  /// reliait à sa cause.
  ///
  /// ⚠️ **Et ce n'est pas un second pré-vol.** `RadioListening.start` est
  /// idempotent — un démarrage en vol le fait rendre tout de suite, un lecteur
  /// qui tient déjà l'antenne ne la recharge pas —, donc l'écran ne consomme
  /// aucun aller-retour de plus sur la fenêtre de rattrapage de 40 secondes de
  /// l'antenne. Il **reflète** ce que le contrôleur a démarré, et le démarre
  /// quand personne ne l'a fait.
  final Future<void> Function()? openSource;

  /// **Le dernier étage de la cascade du fond** : une image du dépôt, posée
  /// quand aucune saison n'en fournit. Le site public ferme sa propre cascade
  /// de la même façon, et pour la même raison — un lecteur sans décor le jour
  /// où personne n'a créé de saison serait une régression visible, causée par
  /// une case vide au portail.
  ///
  /// `null` = pas de plancher, l'aplat de couleur du contenu suffit.
  final String? fallbackBackgroundAsset;

  final ProviderListenable<AsyncValue<ContentView?>> content;

  /// **Les invités du contenu, pour la feuille d'info seulement** (#77).
  ///
  /// Un chemin **distinct** de [content], et délibérément : `authorName` est une
  /// chaîne unique partagée avec les rassemblements, ce lecteur et les trois
  /// cartes d'accueil, et elle ne bouge pas. Les invités arrivent donc à côté,
  /// et n'atteignent que la feuille d'info — ni le titre du lecteur, ni la
  /// notification d'écran verrouillé, ni aucune liste.
  ///
  /// `null` = ce contenu-là n'a pas de crédit à montrer (le direct, un
  /// rassemblement) : rien n'est écouté et rien ne se rend. Une liste vide se
  /// rend de la même façon — l'absence s'affiche comme une absence.
  final ProviderListenable<AsyncValue<List<String>>>? guests;

  final String chromeTitle;
  final String retractedTitle;
  final String retractedMessage;
  final VoidCallback onRetry;

  /// Le titre et la phrase d'un échec de chargement, quand l'écran sait mieux
  /// que le message générique ce qui se passe — la radio, qui repart seule au
  /// retour du réseau. Nuls : `errorStateMessage` décide.
  final String? errorTitle;
  final String? errorMessage;
  final String? downloadContentType;

  /// Mode live : masque les options secondaires et adapte les contrôles.
  final bool isLive;

  /// Rappel pour arrêter la lecture du live.
  final VoidCallback? onStop;

  static const Key downloadButtonKey = Key('content_player_download');

  /// Le bouton « Installer » de l'invitation ouverte quand le stockage du
  /// navigateur n'est pas durable (#273) — visé par clé parce que son libellé
  /// est celui du bandeau d'installation, présent ailleurs dans l'arbre.
  static const Key downloadInstallKey = Key('content_player_download_install');

  /// Le gros bouton lecture/pause — visé par clé : c'est son pictogramme qu'on
  /// vérifie, et chercher `Icons.play_arrow` dans tout l'écran trouverait aussi
  /// celui du mini-lecteur.
  static const Key playButtonKey = Key('content_player_play');

  /// Le bouton d'arrêt d'un direct, quand une [scene] le dispose (#135).
  static const Key stopButtonKey = Key('content_player_stop');

  /// Le bouton « prendre une note » — **le seul geste réservé de cet écran**, et
  /// donc le seul qui ait besoin d'être désigné depuis un test. Une clé plutôt
  /// qu'un pictogramme : `Icons.edit_note_rounded` peut changer, ce que le bouton
  /// exige ne changera pas.
  static const Key notesButtonKey = Key('content_player_notes');

  /// La ligne de crédit des **invités**, dans la feuille d'info (#77).
  ///
  /// Une clé plutôt que le texte : ce qu'un test doit pouvoir constater est
  /// qu'**aucune ligne ne se rend** quand il n'y a pas d'invité, et chercher
  /// l'absence d'un libellé traduit reviendrait à vérifier une traduction.
  static const Key guestsLineKey = Key('content_info_guests');

  @override
  ConsumerState<ContentPlayerView> createState() => _ContentPlayerViewState();
}

/// **Cet écran ne suit plus l'écoute** (#115).
///
/// La position de reprise et la mesure d'écoute vivaient ici, attachées au
/// cycle de vie de la fiche : quitter l'écran coupait le suivi d'un prêche qui
/// continuait de sonner, et une carte de l'accueil n'en ouvrait aucun. Elles
/// vivent désormais dans le contrôleur global (`PlaybackController`), qui suit
/// ce qui est **chargé**, quel que soit l'écran. Cet écran charge et commande ;
/// il n'écrit plus rien — et c'est ce qui garantit qu'aucune écriture n'est
/// faite deux fois.
class _ContentPlayerViewState extends ConsumerState<ContentPlayerView> {
  bool _liked = false;
  String? _requested;
  bool _stoppedByRetraction = false;

  void _showInfoSheet(BuildContext context, ContentView content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          _ContentInfoSheet(content: content, guests: widget.guests),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ContentView?>>(widget.content, (_, next) {
      if (next.hasValue && next.value == null) _stopForRetraction();
    });

    ref.listen<ContentPlayback>(contentPlaybackProvider, _onPlayback);

    return ref.watch(widget.content).when(
          loading: () => _buildLoading(context),
          error: (error, __) => _buildError(context, error),
          data: (content) => switch (content) {
            null => _buildAbsent(context),
            final found when found.playlistUrl == null =>
              _buildNoMedia(context, found),
            final found => _buildPlayer(context, found),
          },
        );
  }

  /// **La cascade du fond**, écrite une fois pour les cinq états de l'écran.
  ///
  /// Le fond de la saison gagne ; l'image du dépôt ferme la cascade, comme sur
  /// le site public. Elle est lue **ici** et non dans `_PlayerScaffold` pour
  /// que le cadre reste un widget sans provider : il est monté par les deux
  /// écrans et par les tests, et un `ref.watch` de plus y obligerait chacun à
  /// savoir ce qu'est une saison.
  ///
  /// `.value`, jamais l'`AsyncValue` : tant que le fichier n'est pas là, il n'y
  /// a **rien à attendre**. Un lecteur qui retarderait son premier rendu pour
  /// un décor serait un lecteur qui met une seconde à s'ouvrir — et le fond
  /// arrive tout seul à la reconstruction suivante.
  ImageProvider? _background() {
    final season = ref.watch(seasonBackgroundProvider).value;
    if (season != null) return season;
    final fallback = widget.fallbackBackgroundAsset;
    return fallback == null ? null : AssetImage(fallback);
  }

  Widget _buildLoading(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      background: _background(),
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// **La cause vient de l'erreur, pas d'un défaut.**
  ///
  /// Cet état n'était atteint que par la médiathèque, dont les échecs sont des
  /// lectures de magasin, et le message réseau y passait inaperçu. L'écran
  /// d'antenne l'atteint désormais aussi : `radioAntennaProvider` est un appel
  /// HTTP (`GET /radio/antenna`) dont la `DioException` remonte telle quelle, et
  /// un 404 y annonçait « vérifiez votre connexion internet ». Voir
  /// `utils/error_message.dart`.
  Widget _buildError(BuildContext context, Object error) {
    return _PlayerScaffold(
      base: _fallbackBase,
      background: _background(),
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: AppErrorState(
                  title: widget.errorTitle,
                  message: widget.errorMessage ??
                      errorStateMessage(error, context.l10n),
                  onRetry: widget.onRetry,
                  onDark: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsent(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      background: _background(),
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
          ),
          Expanded(
            child: ContentAbsenceView(
              absence: ContentAbsence.retracted,
              onDark: true,
              title: widget.retractedTitle,
              message: widget.retractedMessage,
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMedia(BuildContext context, ContentView content) {
    return _PlayerScaffold(
      base: Color(content.color),
      background: _background(),
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            isLive: widget.isLive,
            onInfo:
                widget.isLive ? null : () => _showInfoSheet(context, content),
          ),
          Expanded(
            child: ContentAbsenceView(
              absence: ContentAbsence.noMedia,
              onDark: true,
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  /// **L'arrivée sur l'écran**, une fois par contenu.
  ///
  /// Sur un enseignement ou un rassemblement, elle **ne charge rien** : ouvrir
  /// une fiche n'est pas l'acte d'écouter — le son, le réseau et la batterie
  /// attendent le premier appui, qui charge et joue ([_togglePlayback]). Seul
  /// le direct s'ouvre et joue dès l'arrivée : un flux qu'on ouvre sans le
  /// suivre n'a pas de sens.
  void _loadOnce(ContentView content) {
    if (_stoppedByRetraction || _requested == content.id) return;
    _requested = content.id;
    if (!widget.isLive) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(content));
    });
  }

  /// Ouvre le contenu et **le joue** : média chargé, reprise appliquée par le
  /// contrôleur, puis lecture.
  ///
  /// Deux appelants, et tous deux veulent entendre : [_loadOnce] sur le direct,
  /// et [_togglePlayback] au premier appui sur la fiche — ou quand le média
  /// doit être rouvert (contenu rétracté puis republié, lecteur arrêté depuis
  /// la notification). Charger et jouer tiennent en un seul appui ; il n'y a
  /// plus d'ouverture silencieuse.
  Future<void> _open(ContentView content) async {
    final url = content.playlistUrl;
    if (url == null) return;

    final controller = ref.read(playbackControllerProvider.notifier);

    // **Déjà chargé** : revenir sur un prêche en cours ne le recharge pas et ne
    // le fait pas repartir de zéro. On ne force pas non plus la lecture — un
    // contenu mis en pause depuis la notification doit le rester, et c'est vrai
    // du direct comme du reste.
    if (controller.playback.contentId == content.id) return;

    // **L'ouverture appartient à l'appelant quand il l'a demandée** (#110) :
    // c'est tout ce qui suit — résolution, en-têtes, lecture — qui lui revient.
    // Voir [ContentPlayerView.openSource].
    final opener = widget.openSource;
    if (opener != null) {
      await opener();
      return;
    }

    // **Le garde-fou de #110, en mode debug seulement.** Un `load` nu sur
    // l'antenne est le défaut que cette tranche referme : il rend
    // `401 {"error":"session not found"}` et il ne se voit nulle part, parce
    // qu'un flux qui ne joue pas ressemble à un réseau lent. Un écran qui monte
    // l'antenne dans ce lecteur **doit** passer par le contrôleur d'écoute, qui
    // seul fait la poignée de main — l'assertion le dit ici et maintenant plutôt
    // que de laisser quelqu'un y perdre une soirée.
    assert(
      content.id != RadioConfig.contentId,
      'L\'antenne de New Life Radio ne peut pas être ouverte par '
      'ContentPlayerView : ce chargement partirait sans le cookie de session de '
      'MediaMTX (#108) et rendrait 401. Passez `openSource:` pour déléguer '
      'l\'ouverture à RadioListening.start — voir radio_screen.dart.',
    );

    final resolution = await ref
        .read(downloadResolverProvider)
        .resolve(contentId: content.id, hlsUrl: url);
    if (!mounted) return;

    await controller.load(
      ContentRequest(
        contentId: content.id,
        url: url,
        filePath: resolution.localFilePath,
        // La durée du contrat voyage avec la source qu'elle décrit (#222) :
        // posée ici, elle est lue par les deux barres et par l'enregistreur.
        contractDuration: resolution.contractDuration,
        title: content.title,
        author: content.authorName,
        artUrl: content.squareOrLandscape,
        // **Le régime de la source descend jusqu'au système** (#104) : une
        // antenne n'a ni « −30 s » ni déplacement sur l'écran verrouillé, et
        // c'est ce drapeau qui le dit au handler. L'écran est le seul à le
        // savoir.
        isLive: widget.isLive,
      ),
    );
    // La position de reprise est appliquée par le contrôleur, au chargement :
    // c'est lui qui tient l'enregistreur (#115). Un chargement supplanté pendant
    // ce temps — un autre contenu, ou un arrêt — n'a plus rien à jouer ici.
    if (!mounted || controller.playback.contentId != content.id) return;

    controller.play();
  }

  void _stopForRetraction() {
    if (_stoppedByRetraction) return;
    _stoppedByRetraction = true;
    final controller = ref.read(playbackControllerProvider.notifier);
    if (controller.playback.contentId != _requested) return;
    controller.stop();
  }

  /// **La fin de lecture, vue de la fiche** : le lecteur est remis d'aplomb.
  ///
  /// À l'état terminal, `just_audio` reste `playing == true`, curseur en fin,
  /// sans son — le bouton afficherait « pause » sur un silence. Ce n'est **pas**
  /// du suivi : la complétion s'enregistre dans le contrôleur global, que la
  /// fiche soit ouverte ou non (#115).
  void _onPlayback(ContentPlayback? previous, ContentPlayback next) {
    if (next.contentId == null || next.contentId != _requested) return;
    if (!next.isCompleted || (previous?.isCompleted ?? false)) return;
    final controller = ref.read(playbackControllerProvider.notifier);
    controller.pause();
    controller.seek(Duration.zero);
  }

  /// Lecture/pause — **sur le lecteur**, par le contrôleur global, jamais sur
  /// un booléen local.
  ///
  /// Rien de chargé sous la main : contenu rétracté puis republié, lecteur
  /// arrêté depuis la notification, ou fiche ouverte sans démarrage automatique,
  /// ce qui est désormais le cas courant. Le geste, lui, est explicite — on
  /// rouvre **et on joue**, en un seul appui.
  void _togglePlayback(ContentView content) {
    final controller = ref.read(playbackControllerProvider.notifier);
    final playback = controller.playback;
    if (playback.contentId != content.id) {
      _stoppedByRetraction = false;
      _requested = content.id;
      unawaited(_open(content));
      return;
    }
    // **Quand l'appelant ouvre la source, c'est lui qui relance** (#125) : sur
    // l'antenne, un `play()` nu après un abandon ne ferait rien — le lecteur
    // porte encore sa panne, et `RadioListening` ne réessaie plus. `start` sait
    // reconnaître une antenne en pause (simple `play()`) d'une antenne en panne
    // (pré-vol, puis réouverture).
    final opener = widget.openSource;
    // **Une panne n'est pas une lecture** (#125), même quand la valeur porte
    // encore `isPlaying` : le bouton y affiche ▶ ([_PlayButton]), et l'appui
    // **relance** au lieu de « mettre en pause » un silence. Sans appelant qui
    // ouvre, c'est le geste de « Reprendre » sur la scène : `resume()`, qui
    // repart d'où l'on en était.
    if (playback.hasError) {
      unawaited(opener != null ? opener() : controller.resume());
      return;
    }
    if (playback.isPlaying) {
      controller.pause();
      return;
    }
    if (opener != null) {
      unawaited(opener());
      return;
    }
    controller.play();
  }

  /// **Prendre une note exige un compte**, et l'écran de lecture n'en exige pas.
  ///
  /// `/notes` est dans `memberOnlyRoutes` : pour un invité, la garde du routeur
  /// renverrait ce bouton sur `/home` — la fiche disparaîtrait sous ses doigts,
  /// prêche compris, sans qu'aucune phrase ne dise pourquoi. `requireSession()`
  /// ouvre la connexion à la place, et les notes s'ouvrent après.
  ///
  /// **Le geste est rejouable, et ce n'est pas gratuit** : la `GoRouter` et le
  /// DAO sont lus *maintenant*, tant que cet élément est monté. La reprise passe
  /// par un `router.go(origin)` qui reconstruit la pile, et un
  /// `context.pushNamed` s'appuierait alors sur un `BuildContext` dont rien ne
  /// garantit la survie.
  ///
  /// **Le geste porte l'enseignement** (#190) : s'il existe déjà une note de ce
  /// contenu, c'est elle qu'on ouvre ; sinon un brouillon **pré-lié**, sous un
  /// identifiant frappé ici.
  void _requireNotes(String teachingId) {
    final router = ref.read(routerProvider);
    final dao = ref.read(notesDaoProvider);
    ref.requireSession(action: () {
      unawaited(() async {
        final id = await dao.noteIdForTeaching(teachingId) ?? mintNoteId();
        await router.pushNamed(
          AppRoute.noteEditor,
          pathParameters: {'id': id},
          extra: teachingId,
        );
      }());
    });
  }

  Widget _buildPlayer(BuildContext context, ContentView content) {
    _loadOnce(content);

    final base = Color(content.color);
    final author = content.authorName;

    final scene = widget.scene;
    if (scene != null) {
      final onStop = widget.onStop;
      return _PlayerScaffold(
        base: base,
        background: _background(),
        child: scene(
          context,
          ContentPlayerSceneParts(
            playButton: _PlayButton(
              contentId: content.id,
              accent: base,
              onPressed: () => _togglePlayback(content),
            ),
            stopButton: onStop == null
                ? null
                : _GlassCircleButton(
                    key: ContentPlayerView.stopButtonKey,
                    icon: Icons.stop_rounded,
                    onPressed: onStop,
                  ),
          ),
        ),
      );
    }

    return _PlayerScaffold(
      base: base,
      background: _background(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerTopBar(
              title: widget.chromeTitle,
              isLive: widget.isLive,
              onInfo:
                  widget.isLive ? null : () => _showInfoSheet(context, content),
            ),
            Expanded(
              child: _PlayerStage(
                content: content,
                onResume: () => unawaited(
                  ref.read(playbackControllerProvider.notifier).resume(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            if (author != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                author,
                style: AppTypography.h4.copyWith(color: Colors.white),
              ),
            ],
            if (content.typeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.sell_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    content.typeLabel,
                    style: AppTypography.caption
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _Controls(
              contentId: content.id,
              isLive: widget.isLive,
              onStop: widget.onStop,
              liked: _liked,
              accent: base,
              onSeek: (position) =>
                  ref.read(playbackControllerProvider.notifier).seek(position),
              onPlayPause: () => _togglePlayback(content),
              onLike: () => setState(() => _liked = !_liked),
              onNotes: () => _requireNotes(content.id),
              downloadButton:
                  widget.downloadContentType == null || widget.isLive
                      ? null
                      : _DownloadButton(
                          contentId: content.id,
                          contentType: widget.downloadContentType!,
                        ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// **Les pièces de l'écran lecteur, déjà câblées**, pour une [ContentPlayerView.scene]
/// (#135).
///
/// Le gros bouton porte tout le geste de la fiche — rouvrir par `openSource`,
/// relancer après une panne, mettre en pause — et s'abonne au lecteur par
/// `select` : une scène qui le place n'a rien à savoir de l'écoute.
@immutable
class ContentPlayerSceneParts {
  const ContentPlayerSceneParts({required this.playButton, this.stopButton});

  /// Lecture / pause, clé [ContentPlayerView.playButtonKey].
  final Widget playButton;

  /// L'arrêt du direct ([ContentPlayerView.onStop]), `null` sans rappel.
  final Widget? stopButton;
}

class _PlayerScaffold extends StatelessWidget {
  const _PlayerScaffold({
    required this.base,
    required this.child,
    this.background,
  });

  final Color base;
  final Widget child;

  /// Le fond **déjà résolu** — fichier de saison descendu sur le disque, ou
  /// image du dépôt. Le cadre ne sait pas d'où il vient et n'a pas à le savoir.
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Image de fond (si fournie) ou fond de couleur
          //
          // La couleur est peinte **sous** l'image, et pas seulement en repli :
          // le fichier de saison est décodé de façon asynchrone, et sans elle
          // le premier rendu laisserait voir le noir de la fenêtre.
          Container(color: base),
          if (background != null)
            Image(
              image: background!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          // 2. Dégradé sombre par-dessus l'image pour garder la lisibilité des textes/boutons
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black
                      .withValues(alpha: 0.35), // Légèrement sombre en haut
                  Colors.black.withValues(alpha: 0.65), // Plus sombre au milieu
                  Color.lerp(base, Colors.black, 0.85)!, // Très sombre en bas
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // 3. Contenu du lecteur
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.title,
    this.onInfo,
    this.isLive = false,
  });

  final String title;
  final VoidCallback? onInfo;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        Text(
          title.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        if (!isLive && onInfo != null)
          IconButton(
            icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
            onPressed: onInfo,
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider(content.squareOrLandscape);

    if (image == null) return _placeholder();

    // **Le visuel est carré, et il le reste.** Sans cette contrainte, l'image
    // prenait tout l'espace central — un rectangle haut — et `BoxFit.cover`
    // rognait le carré **à gauche et à droite** : un sujet centré sortait du
    // cadre des deux côtés, ce qui se lit à l'œil comme une image déformée.
    // Mesuré : sur un cadre de 390 × 495, un carré de 600 px perdait 52 px de
    // chaque bord.
    //
    // `AspectRatio` se replie tout seul sur la hauteur disponible quand le
    // cadre est plus haut que large — il n'y a donc pas de cas où le carré
    // déborderait. Un visuel **non** carré (le repli paysage ou portrait, quand
    // la rubrique n'a pas de carré) est recadré au centre, et c'est ce qu'on
    // veut : un carré rogné reste plus informatif qu'un aplat de couleur.
    return Hero(
      tag: 'content_art_${content.id}',
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.92,
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image(
                image: image,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static ImageProvider? _imageProvider(String? source) {
    if (source == null) return null;
    return source.startsWith('http')
        ? NetworkImage(source)
        : AssetImage(source);
  }

  Widget _placeholder() => Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 110,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      );
}

enum _Stage {
  artwork,
  buffering,
  interrupted,
  needsNetwork;

  static _Stage of(ContentPlayback playback, String contentId) {
    if (playback.contentId != contentId) return _Stage.artwork;
    if (playback.hasError) {
      return playback.hasStarted ? _Stage.interrupted : _Stage.needsNetwork;
    }
    return playback.isBuffering ? _Stage.buffering : _Stage.artwork;
  }
}

class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({required this.content, required this.onResume});

  final ContentView content;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      contentPlaybackProvider.select((p) => _Stage.of(p, content.id)),
    );
    final l10n = context.l10n;

    // Si c'est le flux direct, on masque l'illustration centrale pour laisser voir l'image de fond
    final isLiveContent = content.id == RadioConfig.contentId;
    final Widget artworkWidget =
        isLiveContent ? const SizedBox.shrink() : _Artwork(content: content);

    return switch (stage) {
      _Stage.artwork => Center(child: artworkWidget),
      _Stage.buffering => Center(
          child:
              artworkWidget), // Plus de loader centré - le bouton play sert d'indicateur
      _Stage.interrupted => _room(
          AppErrorState(
            title: l10n.playerErrorTitle,
            message: l10n.playerErrorMessage,
            retryLabel: l10n.playerErrorRetry,
            onRetry: onResume,
            onDark: true,
          ),
        ),
      _Stage.needsNetwork => ContentAbsenceView(
          absence: ContentAbsence.offlineMedia,
          onDark: true,
          onBack: () => context.pop(),
        ),
    };
  }

  static Widget _room(Widget child) =>
      Center(child: SingleChildScrollView(child: child));
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.contentId,
    required this.liked,
    required this.accent,
    required this.onSeek,
    required this.onPlayPause,
    required this.onLike,
    required this.onNotes,
    this.downloadButton,
    this.isLive = false,
    this.onStop,
  });

  final String contentId;
  final bool liked;
  final Color accent;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onNotes;
  final Widget? downloadButton;
  final bool isLive;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // **Par `select`** : seul « ce contenu joue » fait apparaître ou disparaître
    // le bouton d'arrêt. La position qui avance ne reconstruit pas cette rangée.
    final isPlaying = ref.watch(
      contentPlaybackProvider
          .select((p) => p.contentId == contentId && p.isPlaying),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de progression + grand bouton Play/Pause (identique à l'Image 1)
        //
        // **Aucune barre de progression sur une antenne** (#104) : il n'y a ni
        // durée à parcourir ni position à reprendre, et une barre qui n'avance
        // vers rien se lit comme une lecture figée au début. Le bouton reste,
        // seul, parce qu'arrêter garde tout son sens.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLive)
              const Spacer()
            else ...[
              Expanded(
                  child: _ProgressLine(contentId: contentId, onSeek: onSeek)),
              const SizedBox(width: AppSpacing.lg),
            ],
            _PlayButton(
              contentId: contentId,
              accent: accent,
              onPressed: onPlayPause,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Rangée d'icônes inférieures
        Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            if (isLive) ...[
              if (onStop != null)
                _GlassCircleButton(
                  icon: Icons.stop_rounded,
                  onPressed: onStop!,
                ),
            ] else ...[
              _GlassCircleButton(
                icon: liked ? Icons.favorite : Icons.favorite_border,
                onPressed: onLike,
              ),
              const SizedBox(width: AppSpacing.md),
              _GlassCircleButton(
                key: ContentPlayerView.notesButtonKey,
                icon: Icons.edit_note_rounded,
                onPressed: onNotes,
              ),
              if (downloadButton != null) ...[
                const SizedBox(width: AppSpacing.md),
                downloadButton!,
              ],
              const Spacer(),
              // Bouton Stop à droite quand un enseignement est en lecture
              if (isPlaying)
                _GlassCircleButton(
                  icon: Icons.stop_rounded,
                  onPressed: () =>
                      ref.read(playbackControllerProvider.notifier).stop(),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressLine extends ConsumerStatefulWidget {
  const _ProgressLine({required this.contentId, required this.onSeek});

  final String contentId;
  final ValueChanged<Duration> onSeek;

  @override
  ConsumerState<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends ConsumerState<_ProgressLine> {
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    // Un autre contenu chargé — ou rien — se lit comme un début : zéro écoulé,
    // pas de durée. Des `select` plutôt que la valeur entière : la panne, le
    // tampon ou la lecture qui basculent ne redessinent pas la barre.
    final contentId = widget.contentId;
    final position = ref.watch(contentPlaybackProvider.select(
      (p) => p.contentId == contentId ? p.position : Duration.zero,
    ));
    // **La durée du contrat gagne sur celle du lecteur** (#222) : sur un `.aac`
    // téléchargé, le lecteur ne fait que l'estimer — jusqu'à ~6 minutes d'écart
    // sur deux heures —, et c'est cette barre-là qui ment au fidèle. Elle n'est
    // posée que sur une copie locale ; en HLS elle est nulle et le lecteur
    // reprend la main, où sa mesure est juste.
    final contractDuration = ref.watch(playbackControllerProvider.select(
      (r) => r?.contentId == contentId ? r?.contractDuration : null,
    ));
    final playerDuration = ref.watch(contentPlaybackProvider.select(
      (p) => p.contentId == contentId ? p.duration : null,
    ));
    final duration = contractDuration ?? playerDuration;
    // Calculée contre la **même** durée que le compteur : la barre et les
    // chiffres doivent toucher le bout en même temps.
    final progress = ref.watch(contentPlaybackProvider.select(
      (p) => p.contentId == contentId ? p.progressFor(duration) : 0.0,
    ));
    final dragged = _dragged;
    final elapsed =
        dragged != null && duration != null ? duration * dragged : position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            thumbColor: Colors.white,
            disabledActiveTrackColor: Colors.white.withValues(alpha: 0.5),
            disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            disabledThumbColor: Colors.white.withValues(alpha: 0.5),
          ),
          child: Slider(
            value: dragged ?? progress ?? 0,
            onChanged: duration == null
                ? null
                : (value) => setState(() => _dragged = value),
            onChangeEnd: duration == null
                ? null
                : (value) {
                    setState(() => _dragged = null);
                    widget.onSeek(duration * value);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_clock(elapsed), style: _clockStyle),
              if (duration != null) Text(_clock(duration), style: _clockStyle),
            ],
          ),
        ),
      ],
    );
  }

  static final TextStyle _clockStyle = AppTypography.caption.copyWith(
    color: Colors.white.withValues(alpha: 0.7),
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static String _clock(Duration value) {
    final seconds = value.inSeconds;
    final minutes = (seconds ~/ 60) % 60;
    final rest = seconds % 60;
    final hours = seconds ~/ 3600;
    final body = '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$body' : body;
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({
    required this.contentId,
    required this.accent,
    required this.onPressed,
  });

  final String contentId;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deux `select` : la position qui avance ne reconstruit pas le bouton.
    //
    // ⚠️ **Une panne éteint les deux** (#125) : `copyWith` ne sait pas effacer
    // `isPlaying`, et une valeur en panne le porte souvent encore. Le bouton
    // afficherait ⏸ — ou l'anneau d'attente — sur un silence, et le premier
    // appui « mettrait en pause » ce qui ne joue pas. En panne, il offre ▶, et
    // l'appui relance (`_togglePlayback`).
    final playing = ref.watch(contentPlaybackProvider
        .select((p) => p.contentId == contentId && p.isPlaying && !p.hasError));
    final buffering = ref.watch(contentPlaybackProvider.select(
        (p) => p.contentId == contentId && p.isBuffering && !p.hasError));

    return _AnimatedPlayButton(
      key: ContentPlayerView.playButtonKey,
      isPlaying: playing,
      isLoading: buffering,
      accent: accent,
      onPressed: onPressed,
    );
  }
}

/// Bouton play avec animation de remplissage progressif pendant le chargement.
///
/// États :
/// - `isLoading = true` : cercle avec bordure blanche, remplissage progressif blanc
/// - `isLoading = false` : cercle plein blanc avec icône play/pause
class _AnimatedPlayButton extends StatefulWidget {
  const _AnimatedPlayButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.accent,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accent;
  final VoidCallback onPressed;

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fillController;
  late final Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fillAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeInOut),
    );
    if (widget.isLoading) {
      _fillController.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _fillController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _fillController.stop();
      _fillController.reset();
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 70.0;
    final iconSize = 36.0;

    return GestureDetector(
      onTap: widget.onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _fillAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: widget.isLoading
                  ? _LoadingButtonPainter(
                      progress: _fillAnimation.value,
                      accentColor: widget.accent,
                    )
                  : _FilledButtonPainter(accentColor: widget.accent),
              child: child,
            );
          },
          child: Center(
            child: Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              size: iconSize,
              color: widget.isLoading ? Colors.white : widget.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Peinture pour le bouton rempli (état normal).
class _FilledButtonPainter extends CustomPainter {
  _FilledButtonPainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cercle plein blanc
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Ombre portée
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black.withValues(alpha: 0.2),
      8,
      true,
    );
  }

  @override
  bool shouldRepaint(_FilledButtonPainter oldDelegate) => false;
}

/// Peinture personnalisée pour le bouton en mode chargement.
///
/// Dessine un cercle avec une bordure blanche et un remplissage progressif blanc.
class _LoadingButtonPainter extends CustomPainter {
  _LoadingButtonPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cercle de fond (couleur d'accent semi-transparente)
    final bgPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Remplissage progressif blanc (angle -90° pour commencer en haut)
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Commencer en haut
        2 * math.pi * progress,
        true,
        fillPaint,
      );
    }

    // Bordure blanche fine
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, borderPaint);
  }

  @override
  bool shouldRepaint(_LoadingButtonPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.contentId, required this.contentType});

  final String contentId;
  final String contentType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final capabilities = ref.watch(downloadCapabilitiesProvider);
    // **Là où il n'y a pas de moteur de transfert, il n'y a pas de bouton**
    // (#273) : Safari n'a pas Background Fetch, quel que soit le code. Absence,
    // jamais grisage — un bouton qui ne téléchargerait rien serait une promesse
    // que personne ne tient.
    if (!capabilities.available) return const SizedBox.shrink();

    final row = ref.watch(downloadForContentProvider(contentId)).value;
    final state = row?.state;

    if (row == null || state == null) {
      return _glass(
        icon: Icons.download_outlined,
        semantics: l10n.actionDownload,
        onTap: () => unawaited(_start(context, ref)),
      );
    }

    return switch (state) {
      DownloadState.queued ||
      DownloadState.running =>
        _progress(context, ref, row, canPause: capabilities.canPause),
      DownloadState.paused => _glass(
          icon: Icons.download,
          semantics: l10n.downloadActionResume,
          onTap: () => ref.read(downloadManagerProvider).resume(contentId),
        ),
      DownloadState.waitingWifi => _glass(
          icon: Icons.wifi_off_rounded,
          semantics: l10n.downloadStateWaitingWifi,
          onTap: () => ref.read(downloadManagerProvider).resume(contentId),
        ),
      DownloadState.complete => _glass(
          icon: Icons.download_done_rounded,
          semantics: l10n.downloadStateComplete,
          onTap: () => _confirmDelete(context, ref),
        ),
      DownloadState.outdated => _outdated(context, ref),
      DownloadState.failed => _glass(
          icon: Icons.refresh_rounded,
          semantics: l10n.downloadActionRetry,
          onTap: () => unawaited(_start(context, ref)),
        ),
    };
  }

  /// **Pas un octet avant que le stockage ne garde ce qu'on y descend** (#273).
  ///
  /// Sur un appareil, `ensureDurable()` rend vrai sans rien demander. Dans un
  /// onglet non installé, `navigator.storage.persist()` répond **non** (mesuré
  /// le 29/10/2026), et le navigateur peut alors évincer tout le stockage de
  /// l'origine d'un coup — les enseignements **et** le magasin. On invite donc à
  /// installer plutôt que de faire payer 80 Mo de données pour rien.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final durable =
        await ref.read(downloadCapabilitiesProvider).ensureDurable();
    if (!context.mounted) return;
    if (!durable) {
      await _inviteToInstall(context, ref);
      return;
    }
    await ref.read(downloadManagerProvider).download(
          contentId: contentId,
          contentType: contentType,
          quality: ref.read(downloadQualityProvider),
        );
  }

  /// L'invitation, et le bouton qui ouvre la vraie boîte du navigateur quand
  /// elle est disponible. Sur iPhone il n'y en a aucune — mais là-bas le bouton
  /// Télécharger ne paraît déjà pas, faute de Background Fetch.
  Future<void> _inviteToInstall(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // L'offre se lit **sur l'invite elle-même**, et non sur
    // `installOfferProvider` : ce flux n'a pas encore émis au moment du geste
    // (`ref.read` y rend `AsyncLoading`), et le bouton d'installation aurait
    // donc manqué précisément là où il sert.
    final offer = ref.read(installPromptProvider).offer;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadNeedsInstallTitle),
        content: Text(l10n.downloadNeedsInstallMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.installBannerDismiss),
          ),
          if (offer == InstallOffer.prompt)
            TextButton(
              key: ContentPlayerView.downloadInstallKey,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Installer **puis** demander la permission d'annonces (#283) :
                // la règle est écrite une fois, à côté de l'offre.
                unawaited(installThenAskForNotifications(ref));
              },
              child: Text(l10n.installBannerAction),
            ),
        ],
      ),
    );
  }

  /// L'anneau de progression, et le geste qu'il porte vraiment.
  ///
  /// [canPause] faux — un navigateur — : l'appui **annule**, et l'icône le dit.
  /// Background Fetch n'a ni pause ni reprise à l'octet (c'est la contrepartie
  /// assumée du transfert qui survit à la fermeture de l'onglet), et un bouton
  /// Pause qui ne ferait rien serait pire que son absence.
  Widget _progress(
    BuildContext context,
    WidgetRef ref,
    DownloadRow row, {
    required bool canPause,
  }) {
    final l10n = context.l10n;
    final total = row.bytesTotal;
    final fraction =
        total > 0 ? (row.bytesReceived / total).clamp(0.0, 1.0) : null;
    final percent = fraction == null ? null : (fraction * 100).round();

    final manager = ref.read(downloadManagerProvider);
    return Semantics(
      button: true,
      label:
          canPause ? l10n.downloadStateDownloading : l10n.downloadActionCancel,
      child: InkResponse(
        key: ContentPlayerView.downloadButtonKey,
        onTap: () => unawaited(
          canPause ? manager.pause(contentId) : manager.cancel(contentId),
        ),
        radius: 28,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2.5,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
              if (percent != null)
                Text(
                  '$percent',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Icon(
                  canPause ? Icons.pause : Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadDeleteConfirmTitle),
        content: Text(l10n.downloadDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.downloadDeleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(downloadManagerProvider).cancel(contentId);
    }
  }

  Widget _outdated(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _glass(
          icon: Icons.download_done_rounded,
          semantics: l10n.downloadUpdateAvailable,
          onTap: () => _outdatedMenu(context, ref),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _outdatedMenu(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text(l10n.downloadActionUpdate),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_start(context, ref));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.downloadActionDelete),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _glass({
    required IconData icon,
    required String semantics,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          key: ContentPlayerView.downloadButtonKey,
          icon: Icon(icon, color: Colors.white, size: 22),
          tooltip: semantics,
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// **La feuille d'info — le seul endroit où les invités s'affichent** (#77).
///
/// L'écran de détail, et rien d'autre : les listes, les carrousels, les
/// vignettes et la notification d'écran verrouillé continuent d'afficher le seul
/// animateur. Aucune règle de troncature à inventer, aucune régression visuelle,
/// et c'est la convention des applications de podcast.
///
/// Un `ConsumerWidget` parce que la liste arrive par un **provider**, pas par le
/// contenu : la feuille peut donc s'ouvrir avant que le magasin ait livré les
/// crédits, et la ligne paraîtra sous les doigts du fidèle. Un paramètre passé à
/// l'ouverture aurait figé ce que la feuille sait au moment du clic.
class _ContentInfoSheet extends ConsumerWidget {
  const _ContentInfoSheet({required this.content, this.guests});

  final ContentView content;

  /// `null` = ce contenu n'a pas de crédit à montrer. Voir
  /// [ContentPlayerView.guests].
  final ProviderListenable<AsyncValue<List<String>>>? guests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final subtitle = [content.authorName, content.typeLabel]
        .where((part) => part != null && part.isNotEmpty)
        .join(' • ');
    final description = content.description;

    // **Pas d'invité, aucune ligne ne se rend** — ni « Avec », ni tiret, ni
    // « aucun invité ». C'est la règle du dépôt : l'absence s'affiche comme une
    // absence, jamais un libellé de remplacement. Les trois états de
    // l'`AsyncValue` retombent ici sur la même chose, et c'est voulu : une
    // panne de lecture du magasin ne doit pas mettre un message d'erreur au
    // milieu de la fiche d'un prêche.
    final listenable = guests;
    final names = listenable == null
        ? const <String>[]
        : ref.watch(listenable).value ?? const <String>[];
    final guestLine = names.isEmpty
        ? null
        : l.contentGuests(joinNames(names, and: l.listAnd));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.5,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.title, style: AppTypography.h3),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
            ],
            if (guestLine != null) ...[
              const SizedBox(height: 4),
              Text(
                guestLine,
                key: ContentPlayerView.guestsLineKey,
                style: AppTypography.body.copyWith(color: palette.textPrimary),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l.tabDescription, style: AppTypography.h5),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: AppTypography.bodyLarge
                    .copyWith(color: palette.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
