import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` n'est pas exporté par l'entrée principale de
// flutter_riverpod 3 — c'est pourtant le type qui permet de recevoir *un
// provider* plutôt que sa valeur, donc de l'écouter autant que de le lire.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../data/players/content_player.dart';
import '../data/repositories/playback_progress_recorder.dart';
import '../l10n/l10n_extension.dart';
import '../models/content_view.dart';
import '../router/app_router.dart';
import '../state/playback_progress_providers.dart';
import '../state/player_providers.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_error_state.dart';
import 'content_absence.dart';

/// Habillage du lecteur quand il n'y a plus de contenu d'où tirer une couleur :
/// le bleu de marque, dernier maillon de la cascade.
const _fallbackBase = Color(kBrandFallbackColor);

/// **Le lecteur plein écran d'un contenu de médiathèque** — le même pour un
/// enseignement et pour un rassemblement.
///
/// Il ne connaît **aucune famille** : il reçoit le provider d'un
/// `AsyncValue<ContentView?>`, choisi par l'écran qui l'enveloppe. C'est ce qui
/// permet aux deux familles de partager ce dessin sans que le partage devienne
/// un chemin par lequel un rassemblement pourrait s'ouvrir dans l'écran d'un
/// enseignement : la famille est décidée en amont, par le provider et par la
/// route.
///
/// Les providers qu'il lit de lui-même sont ceux du **lecteur**
/// ([contentPlayerProvider], [contentPlaybackProvider]) et de la **reprise de
/// lecture** ([playbackProgressRecorderProvider]) — tous trois sans famille, et
/// c'est pourquoi ils vivent ici plutôt que dans les deux écrans, où ils
/// auraient été écrits deux fois.
///
/// Cinq situations, et elles sont distinctes :
///
/// - **chargement** — le cadre du lecteur, sans son contenu. Aucun titre
///   d'emprunt, aucune couleur devinée ;
/// - **échec de lecture** — une **panne**, pas une absence : il y a quelque
///   chose à réessayer, et `AppErrorState` est le seul état du dépôt qui porte
///   une action ;
/// - **identifiant qui ne résout plus rien** — l'écran **reste ouvert** et
///   bascule sur [ContentAbsence.retracted] : on n'éjecte pas quelqu'un en
///   pleine lecture, et on ne fige pas une copie qui mentirait ;
/// - **contenu publié sans média** (`playlistUrl` nul) —
///   [ContentAbsence.noMedia], **avec la couleur du contenu** : ce n'est pas un
///   retrait, c'est une attente ;
/// - **contenu trouvé** — le lecteur.
///
/// Toutes partagent le même cadre ([_PlayerScaffold]) : basculer sur un écran
/// d'allure différente reviendrait à déplacer le fidèle sans le lui dire.
///
/// **Une rétractation reçue pendant l'écoute arrête le son**, et pas seulement
/// l'affichage. C'est la disparition de la valeur qui le déclenche, jamais un
/// simple retour à l'état « chargement » : un rechargement ne doit pas couper
/// la lecture.
class ContentPlayerView extends ConsumerStatefulWidget {
  const ContentPlayerView({
    super.key,
    required this.content,
    required this.chromeTitle,
    required this.retractedTitle,
    required this.retractedMessage,
    required this.onRetry,
  });

  /// **Le provider du contenu**, et non sa valeur.
  ///
  /// Il est passé tel quel pour que ce widget puisse l'**écouter** en plus de
  /// le lire : l'arrêt de la lecture doit réagir à chaque valeur du flux, pas
  /// aux seules reconstructions. Une rétractation immédiatement suivie d'une
  /// resynchronisation ne produit qu'une reconstruction — le contenu n'aurait
  /// jamais paru absent, et le son aurait continué sur un contenu retiré.
  ///
  /// Déclaré sur [ContentView] : `ProviderListenable` est covariant, un
  /// `StreamProvider<TeachingView?>` se passe donc ici tel quel.
  final ProviderListenable<AsyncValue<ContentView?>> content;

  /// Surtitre du lecteur — « Enseignement », « Rassemblement ». Déjà localisé.
  final String chromeTitle;

  /// Titre et explication de l'absence, plus précis que ceux de la variante
  /// générique. Déjà localisés.
  final String retractedTitle;
  final String retractedMessage;

  /// Relance la lecture du magasin après un échec.
  final VoidCallback onRetry;

  /// Clé de l'indicateur de mise en tampon, pour le cibler depuis les tests.
  static const Key bufferingKey = Key('content_player_buffering');

  @override
  ConsumerState<ContentPlayerView> createState() => _ContentPlayerViewState();
}

class _ContentPlayerViewState extends ConsumerState<ContentPlayerView>
    with WidgetsBindingObserver {
  /// **La dernière affordance encore feinte.** Le cœur n'a aucun contrat
  /// serveur ; le brancher au passage aurait fabriqué une donnée que rien ne
  /// conserve.
  bool _liked = false;

  /// Le contenu que **cet écran** a demandé au lecteur. Sans lui, chaque
  /// reconstruction relancerait le son depuis le début.
  ///
  /// À distinguer de `ContentPlayback.contentId`, qui dit ce que le lecteur —
  /// **global** — joue réellement, et qui peut être autre chose.
  String? _requested;

  /// Vrai dès qu'une rétractation a coupé le son.
  ///
  /// Ce qui suit ne doit pas le relancer tout seul : une rétractation
  /// immédiatement suivie d'une republication est courante, et reprendre le son
  /// sans que personne ne l'ait demandé serait une surprise sonore. Seul un
  /// geste explicite sur le bouton lève l'interdit.
  bool _stoppedByRetraction = false;

  /// L'enregistreur de progression de la session d'écoute en cours (#43), ou
  /// `null` tant que rien n'est ouvert — et quand le magasin est indisponible :
  /// la reprise est un confort, son absence n'empêche pas d'écouter.
  PlaybackProgressRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Sortie de l'écran — l'un des cinq déclencheurs du rapport. La lecture,
    // elle, **continue** : le lecteur est global, `context.pop()` ne l'arrête
    // pas, c'est le sens même de l'écoute en arrière-plan.
    _fireAndForget(_recorder?.onLeft());
    super.dispose();
  }

  /// **Écran éteint, application rangée** — le cas le plus fréquent de tout ce
  /// lot : le fidèle met son téléphone dans sa poche, il ne quitte pas.
  ///
  /// On rapporte, et **on ne touche pas à la lecture**. Couper ici serait la
  /// panne la plus visible du lot.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _fireAndForget(_recorder?.onAppPaused());
  }

  /// Ouvre une demi-feuille native (glissable vers le bas) : description,
  /// rubrique et infos du contenu.
  void _showInfoSheet(BuildContext context, ContentView content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ContentInfoSheet(content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Une rétractation reçue pendant l'écoute doit **arrêter le son**, et pas
    // seulement retirer les commandes de l'écran. On écoute la valeur, pas
    // l'`AsyncValue` : un rechargement qui repasse par « chargement » ne doit
    // pas couper la lecture, seule la disparition le doit.
    ref.listen<AsyncValue<ContentView?>>(widget.content, (_, next) {
      if (next.hasValue && next.value == null) _stopForRetraction();
    });

    // Le lecteur pousse ici sa position et ses événements. Un `listen` et non
    // un `watch` : ce widget-ci ne doit surtout pas se reconstruire au rythme
    // de la position — voir [_ProgressLine], qui s'en charge seule.
    ref.listen<ContentPlayback>(contentPlaybackProvider, _onPlayback);

    return ref.watch(widget.content).when(
          loading: () => _buildLoading(context),
          error: (_, __) => _buildError(context),
          data: (content) => switch (content) {
            null => _buildAbsent(context),
            final found when found.playlistUrl == null =>
              _buildNoMedia(context, found),
            final found => _buildPlayer(context, found),
          },
        );
  }

  /// Le cadre du lecteur, sans son contenu : c'est le même écran, il n'est pas
  /// encore rempli.
  Widget _buildLoading(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
          Expanded(
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: AppErrorState(
                  message: context.l10n.stateErrorMessage,
                  onRetry: widget.onRetry,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// L'identifiant ne résout plus rien : même chrome (le fidèle n'est pas
  /// déplacé), contenu remplacé par la déclaration d'absence.
  Widget _buildAbsent(BuildContext context) {
    return _PlayerScaffold(
      base: _fallbackBase,
      child: Column(
        children: [
          _PlayerTopBar(title: widget.chromeTitle),
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

  /// **Publié sans média** : le contenu est là, son enregistrement n'y est pas
  /// encore. Même cadre, même surtitre, [ContentAbsence.noMedia] à la place du
  /// lecteur — et surtout **pas** [ContentAbsence.retracted] : « pas encore
  /// disponible » n'est pas « contenu retiré », et confondre les deux ferait
  /// cesser d'attendre un enregistrement qui arrive.
  ///
  /// **La couleur est celle du contenu**, et c'est ce qui distingue cet écran
  /// du précédent : là-bas la donnée a disparu, sa teinte avec elle, d'où le
  /// bleu de repli ; ici le contenu existe, son habillage aussi. Les
  /// métadonnées restent consultables pour la même raison.
  ///
  /// Ce n'est pas une branche défensive. La portée de publication du serveur ne
  /// teste aujourd'hui que `published_at` : un contenu publié sans média est un
  /// état courant, et il le restera sur tout appareil déjà synchronisé.
  Widget _buildNoMedia(BuildContext context, ContentView content) {
    return _PlayerScaffold(
      base: Color(content.color),
      child: Column(
        children: [
          _PlayerTopBar(
            title: widget.chromeTitle,
            onInfo: () => _showInfoSheet(context, content),
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

  // ───────────────────────────────────────────────────────────────────────────
  // Le pilotage du lecteur
  // ───────────────────────────────────────────────────────────────────────────

  /// **Confie le contenu au lecteur, une fois par contenu.**
  ///
  /// Appelée à chaque build de l'écran rempli, elle ne fait quelque chose que
  /// la première fois : sans cette garde, chaque reconstruction — et il y en a
  /// une à chaque cycle de synchronisation — relancerait le prêche depuis le
  /// début.
  ///
  /// Le chargement lui-même est reporté **après le frame** : `build` décrit,
  /// il ne commande pas. Charger depuis un `build` ferait muter un provider
  /// pendant la construction de l'arbre.
  void _loadOnce(ContentView content) {
    if (_stoppedByRetraction || _requested == content.id) return;
    _requested = content.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(content));
    });
  }

  /// Ouvre le contenu : reprise résolue, média chargé, lecture démarrée.
  ///
  /// **L'auto-lecture à l'ouverture est un choix**, pas un héritage : elle
  /// coûte désormais du réseau et de la batterie. Elle est conservée parce
  /// qu'ouvrir la fiche d'un prêche est, ici, l'acte d'aller l'écouter.
  Future<void> _open(ContentView content) async {
    final url = content.playlistUrl;
    // Publié sans média : rien à charger. `_buildNoMedia` le dit à l'écran ;
    // cette garde-ci tient l'autre moitié — aucune URL nulle ne part dans le
    // lecteur, y compris par le geste explicite de `_togglePlayback`.
    if (url == null) return;

    final player = ref.read(contentPlayerProvider);
    await _openRecorder(content.id);
    if (!mounted) return;

    // **Déjà chargé** : revenir sur un prêche en cours ne le recharge pas et ne
    // le fait pas repartir de zéro. On ne force pas non plus la lecture — un
    // contenu mis en pause depuis la notification doit le rester.
    if (player.value.contentId == content.id) return;

    await player.load(
      contentId: content.id,
      url: url,
      title: content.title,
      author: content.authorName,
      artUrl: content.landscapeOrPortrait,
    );
    if (!mounted) return;

    // Reprendre où l'on s'était arrêté — **sauf sur un contenu déjà terminé**,
    // qu'on rouvre vraisemblablement pour le réécouter, pas pour en retrouver
    // les trente dernières secondes.
    final resume = _recorder?.resume;
    if (resume != null &&
        !resume.completed &&
        resume.position > Duration.zero) {
      player.seek(resume.position);
    }
    player.play();
  }

  /// Ouvre l'enregistreur de progression de ce contenu.
  ///
  /// Le magasin peut ne pas répondre ; la reprise est alors perdue, et rien de
  /// plus. Une erreur affichée pendant un prêche serait une panne, une
  /// progression perdue est un désagrément — c'est le parti pris de #43, et il
  /// vaut aussi pour l'ouverture.
  Future<void> _openRecorder(String contentId) async {
    if (_recorder?.contentId == contentId) return;
    final open = ref.read(playbackProgressRecorderProvider);
    try {
      final recorder = await open(contentId);
      if (mounted) _recorder = recorder;
    } catch (error, stack) {
      debugPrint('[progression] enregistreur indisponible pour $contentId : '
          '$error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }

  /// **La rétractation coupe le son.**
  ///
  /// `setState` ne suffisait que tant que rien ne jouait. Avec un service de
  /// premier plan derrière, un enseignement retiré continuerait de **jouer,
  /// écran éteint, son titre affiché sur l'écran verrouillé** — l'écran, lui,
  /// montrerait bien l'absence. `stop()` relâche le média **et** vide ce que le
  /// système affiche (élément média, notification, commandes).
  void _stopForRetraction() {
    if (_stoppedByRetraction) return;
    _stoppedByRetraction = true;
    final player = ref.read(contentPlayerProvider);
    // Le lecteur est global : il joue peut-être déjà autre chose, et couper le
    // son d'un contenu qui n'a pas été retiré serait pire que le défaut qu'on
    // corrige.
    if (player.value.contentId != _requested) return;
    player.stop();
  }

  /// Ce que le lecteur pousse à l'écran : la position, et deux transitions.
  void _onPlayback(ContentPlayback? previous, ContentPlayback next) {
    final recorder = _recorder;
    // La valeur d'un **autre** contenu ne le concerne pas — celle que `stop()`
    // remet à vide en particulier, dont la position nulle écraserait la reprise
    // qu'on vient justement de sauver.
    if (recorder == null || next.contentId != recorder.contentId) return;

    // **Fin de piste.** À l'état terminal `just_audio` reste `playing == true`,
    // curseur en fin, sans son : le bouton afficherait « pause » sur un
    // silence. Remettre le lecteur d'aplomb appartient à l'écran — c'est le
    // seul des deux qui connaisse un lecteur.
    if (next.isCompleted && !(previous?.isCompleted ?? false)) {
      _fireAndForget(recorder.onTerminated());
      final player = ref.read(contentPlayerProvider);
      player.pause();
      player.seek(Duration.zero);
      return;
    }

    _fireAndForget(
      recorder.onPosition(
        next.position,
        duration: next.duration,
        isPlaying: next.isPlaying,
      ),
    );
    if ((previous?.isPlaying ?? false) && !next.isPlaying) {
      _fireAndForget(recorder.onPaused());
    }
  }

  /// **Un déclencheur de progression, muet et sans attente.**
  ///
  /// Ces appels partent d'un `dispose`, d'un rappel de cycle de vie ou d'une
  /// émission du lecteur : personne ne peut les attendre, et une erreur non
  /// rattrapée y remonterait jusqu'à la zone. Le rapport réseau est déjà muet
  /// par contrat (#43) ; ce garde-fou couvre l'**écriture locale**, qui peut
  /// échouer sur un magasin plein ou déjà fermé — à l'extinction de
  /// l'application, par exemple. Une progression perdue est un désagrément.
  void _fireAndForget(Future<void>? work) {
    if (work == null) return;
    unawaited(
      work.catchError((Object error) {
        debugPrint('[progression] déclencheur abandonné : $error');
      }),
    );
  }

  /// Lecture/pause — **sur le lecteur**, jamais sur un booléen local.
  void _togglePlayback(ContentView content) {
    final player = ref.read(contentPlayerProvider);
    if (player.value.contentId != content.id) {
      // Rien de chargé : contenu rétracté puis republié, ou lecteur arrêté
      // depuis la notification. Le geste, lui, est explicite — on recharge.
      _stoppedByRetraction = false;
      _requested = content.id;
      unawaited(_open(content));
      return;
    }
    player.value.isPlaying ? player.pause() : player.play();
  }

  Widget _buildPlayer(BuildContext context, ContentView content) {
    _loadOnce(content);

    // Couleur **déjà résolue** par le modèle de lecture : la cascade
    // contenu → rubrique → marque s'est terminée avant d'arriver ici.
    final base = Color(content.color);
    final author = content.authorName;

    return _PlayerScaffold(
      base: base,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerTopBar(
              title: widget.chromeTitle,
              onInfo: () => _showInfoSheet(context, content),
            ),
            Expanded(
              child: _PlayerStage(
                content: content,
                onResume: () =>
                    unawaited(ref.read(contentPlayerProvider).resume()),
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
            // **Pas de ligne d'auteur quand il n'y en a pas.** Un « Auteur
            // inconnu » aurait l'allure d'une donnée, et le fidèle le lirait
            // comme une erreur de saisie de l'église. L'intervenant n'est
            // peut-être qu'en retard d'un cycle de synchronisation.
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
              liked: _liked,
              accent: base,
              onSeek: (position) =>
                  ref.read(contentPlayerProvider).seek(position),
              onPlayPause: () => _togglePlayback(content),
              onLike: () => setState(() => _liked = !_liked),
              onNotes: () => context.pushNamed(AppRoute.notes),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Le cadre du lecteur : dégradé plein écran tiré d'une couleur d'accent.
///
/// Extrait pour que l'**absence** garde exactement le même cadre que la
/// lecture. Basculer sur un écran d'allure différente reviendrait à déplacer le
/// fidèle sans le lui dire.
class _PlayerScaffold extends StatelessWidget {
  const _PlayerScaffold({required this.base, required this.child});

  final Color base;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, Color.lerp(base, Colors.black, 0.55)!],
            stops: const [0.15, 1.0],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

/// Barre supérieure du lecteur (retour, libellé, accès aux détails).
class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.title, this.onInfo});
  final String title;
  final VoidCallback? onInfo;

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
        IconButton(
          icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
          onPressed: onInfo,
        ),
      ],
    );
  }
}

/// Visuel central : image d'habillage si fournie, sinon placeholder coloré.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    // En-tête pleine largeur : le cadrage paysage. Le portrait prend le relais
    // s'il est seul, plutôt que de renoncer à toute image. La résolution des
    // chemins relatifs a déjà eu lieu dans le modèle de lecture.
    final image = _imageProvider(content.landscapeOrPortrait);

    // Pas d'image : grande icône flottant sur le dégradé.
    if (image == null) return _placeholder();

    // Image fondue dans le dégradé : opaque en haut, transparente en bas
    // (et léger fondu en haut) via un masque d'opacité.
    return Hero(
      // Étiquette bâtie sur l'identifiant, et non sur le titre : deux contenus
      // homonymes casseraient l'animation, un titre corrigé la
      // désynchroniserait de la carte d'origine.
      tag: 'content_art_${content.id}',
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.6, 1.0],
        ).createShader(rect),
        // Repli obligatoire (cf. CLAUDE.md) : sans lui, un visuel injoignable
        // — hors ligne, ou `flutter test` qui répond 400 à tout réseau — fait
        // lever le lecteur au lieu de retomber sur le placeholder.
        child: Image(
          image: image,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  /// Les deux cadrages sont servis en **URL relative** par l'API : la
  /// résolution contre la base courante appartient au client (ADR-0005).
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

/// **Ce que montre le grand espace central du lecteur** — quatre réponses, et
/// aucune n'est un écran de remplacement.
///
/// Elles sortent toutes de la **valeur du lecteur**, jamais d'un état mémorisé
/// dans un widget : la notification et l'écran verrouillé pilotent le même
/// lecteur, et le chien de garde peut rouvrir une source sans que personne
/// n'ait rien touché.
enum _Stage {
  /// Le visuel du contenu — le cas normal.
  artwork,

  /// **La mise en tampon**, qui n'est ni un chargement d'écran ni une panne :
  /// un indicateur **par-dessus** le visuel. Basculer sur l'état « chargement »
  /// effacerait le titre et les commandes, et ressemblerait à un redémarrage
  /// au milieu d'une écoute.
  buffering,

  /// **La panne en cours d'écoute** : le son avait commencé, il y a une
  /// position à défendre, et donc quelque chose à *reprendre*.
  interrupted,

  /// **La panne d'une ouverture qui n'a jamais joué** : rien n'a commencé,
  /// il n'y a rien à reprendre, et ce qui manque est du réseau.
  needsNetwork;

  /// **La distinction se déduit de l'échec lui-même.**
  ///
  /// Pas d'un test de connectivité : `connectivity_plus` répond « connecté »
  /// derrière un portail captif — un hôtel, un wifi d'église mal configuré —
  /// c'est-à-dire exactement quand sa réponse compterait. Il n'est pas dans
  /// `pubspec.yaml`, et cette ligne-ci est la raison.
  static _Stage of(ContentPlayback playback, String contentId) {
    // Le lecteur est **global** : il porte peut-être la panne d'un contenu
    // ouvert ailleurs, et cet écran-ci n'a rien à en dire.
    if (playback.contentId != contentId) return _Stage.artwork;
    if (playback.hasError) {
      return playback.hasStarted ? _Stage.interrupted : _Stage.needsNetwork;
    }
    return playback.isBuffering ? _Stage.buffering : _Stage.artwork;
  }
}

/// Le grand espace central du lecteur, seul abonné aux pannes et au tampon.
///
/// Abonné **par `select` sur un [_Stage]**, comme [_ProgressLine] l'est à la
/// position : la valeur du lecteur bat plusieurs fois par seconde, et lire
/// l'état de la panne plus haut reconstruirait le dégradé, le `Hero` et
/// l'image au même rythme.
class _PlayerStage extends ConsumerWidget {
  const _PlayerStage({required this.content, required this.onResume});

  final ContentView content;

  /// Reprend **à la position atteinte** — ce que le mot « Reprendre » promet.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      contentPlaybackProvider.select((p) => _Stage.of(p, content.id)),
    );
    final l10n = context.l10n;

    return switch (stage) {
      _Stage.artwork => Center(child: _Artwork(content: content)),
      _Stage.buffering => Stack(
          fit: StackFit.expand,
          children: [
            Center(child: _Artwork(content: content)),
            const Center(child: _BufferingBadge()),
          ],
        ),
      // `AppErrorState` est le seul état du dépôt qui porte une action — mais
      // **pas avec ses textes** : `stateErrorMessage` dit « Impossible de
      // charger le contenu », ce qui parle du catalogue. Ici le contenu est
      // bien arrivé, c'est le son qui s'est tu.
      _Stage.interrupted => _room(
          AppErrorState(
            title: l10n.playerErrorTitle,
            message: l10n.playerErrorMessage,
            retryLabel: l10n.playerErrorRetry,
            onRetry: onResume,
          ),
        ),
      // Le libellé « il faut du réseau » est celui des quatre absences, écrit
      // une fois pour toutes : on ne réécrit pas une phrase ici.
      _Stage.needsNetwork => ContentAbsenceView(
          absence: ContentAbsence.offlineMedia,
          onDark: true,
          onBack: () => context.pop(),
        ),
    };
  }

  /// Laisse la carte respirer sans jamais déborder : le lecteur garde son
  /// titre et ses commandes, l'espace central est donc étroit sur un petit
  /// écran.
  static Widget _room(Widget child) =>
      Center(child: SingleChildScrollView(child: child));
}

/// L'indicateur de mise en tampon : un disque sombre, posé **sur** le visuel.
///
/// Discret et sans texte : ce n'est pas une nouvelle qu'on annonce, c'est le
/// signe que ça travaille.
class _BufferingBadge extends StatelessWidget {
  const _BufferingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ContentPlayerView.bufferingKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}

/// Bloc de contrôles : progression, actions et lecture/pause.
///
/// **Il ne reçoit ni position ni état de lecture**, et c'est la décision de
/// forme de ce fichier. La position émet plusieurs fois par seconde : la faire
/// descendre en paramètre obligerait tout ce qui est au-dessus — le dégradé, le
/// `Hero`, le `ShaderMask`, l'image — à se reconstruire au même rythme, pendant
/// toute une écoute. Les deux seuls widgets qui affichent l'état du lecteur
/// s'y abonnent donc eux-mêmes, par `select` ([_ProgressLine], [_PlayButton]),
/// et ce bloc-ci n'est plus que la mise en page et les gestes.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.liked,
    required this.accent,
    required this.onSeek,
    required this.onPlayPause,
    required this.onLike,
    required this.onNotes,
  });

  final bool liked;
  final Color accent;

  /// Déplacement de la tête de lecture, **en temps** et non en fraction : une
  /// fraction obligerait l'appelant à connaître la durée, que lui non plus n'a
  /// pas.
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne de lecture + bouton play centré verticalement dessus.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _ProgressLine(onSeek: onSeek)),
            const SizedBox(width: AppSpacing.lg),
            _PlayButton(accent: accent, onPressed: onPlayPause),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              onPressed: onLike,
            ),
            const SizedBox(width: AppSpacing.md),
            _GlassCircleButton(
              icon: Icons.edit_note_rounded,
              onPressed: onNotes,
            ),
          ],
        ),
      ],
    );
  }
}

/// **La ligne de progression** : le curseur et le compteur de temps.
///
/// Le seul widget de l'écran abonné à la position, et il l'est **par `select`**.
///
/// Deux réserves du lecteur s'y dessinent, et aucune n'est théorique :
///
/// - **la durée peut être inconnue** — en HLS elle arrive après le manifeste
///   et, sur iOS, peut ne jamais arriver. Le compteur n'affiche alors que le
///   temps écoulé : un `00:00` de droite se lirait comme un média de durée
///   nulle. Le curseur, lui, ne prétend pas savoir où l'on en est et ne se
///   laisse pas déplacer — il n'y a rien à quoi rapporter la fraction ;
/// - **un glissement ne doit pas se faire écraser** par les émissions de
///   position, qui arrivent plusieurs fois par seconde. D'où la valeur locale
///   « en cours de glissement », qui a la priorité tant que le doigt est posé
///   et n'est commise qu'au relâchement.
class _ProgressLine extends ConsumerStatefulWidget {
  const _ProgressLine({required this.onSeek});

  final ValueChanged<Duration> onSeek;

  @override
  ConsumerState<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends ConsumerState<_ProgressLine> {
  /// Fraction sous le doigt, `null` au repos.
  double? _dragged;

  @override
  Widget build(BuildContext context) {
    final position =
        ref.watch(contentPlaybackProvider.select((p) => p.position));
    final duration =
        ref.watch(contentPlaybackProvider.select((p) => p.duration));
    // La règle « `null` tant que la durée est inconnue » est écrite une fois,
    // dans la valeur du lecteur. La recopier ici en donnerait une seconde
    // version, donc une occasion de diverger.
    final progress =
        ContentPlayback(position: position, duration: duration).progress;
    final dragged = _dragged;
    // Pendant le glissement, le compteur suit le doigt : c'est ce qui permet de
    // viser une minute précise.
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
              // **Rien** plutôt qu'un zéro : une durée inconnue est une
              // absence, pas une valeur.
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

  /// `mm:ss`, ou `h:mm:ss` au-delà de l'heure — un culte entier en dépasse une.
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

/// Gros bouton lecture/pause (cercle blanc, icône à la couleur d'accent).
///
/// Il lit l'état de lecture **dans le lecteur**, par `select` : la notification
/// et l'écran verrouillé pilotent le même lecteur, et un booléen mémorisé ici
/// afficherait « pause » sur un silence dès qu'on met en pause depuis l'écran
/// verrouillé.
class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing =
        ref.watch(contentPlaybackProvider.select((p) => p.isPlaying));
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 36),
        color: accent,
        onPressed: onPressed,
      ),
    );
  }
}

/// Petit bouton circulaire translucide (glassmorphisme).
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onPressed});
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

/// Demi-feuille de détails : intervenant, rubrique et description.
class _ContentInfoSheet extends StatelessWidget {
  const _ContentInfoSheet({required this.content});
  final ContentView content;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    // Deux facultatifs, assemblés sans séparateur orphelin : un contenu sans
    // intervenant **ni** rubrique ne doit pas afficher un « • » seul.
    final subtitle = [content.authorName, content.typeLabel]
        .where((part) => part != null && part.isNotEmpty)
        .join(' • ');
    final description = content.description;

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
            // Section entière absente quand il n'y a rien à décrire : un
            // en-tête « Description » suivi du vide est pire que rien.
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
