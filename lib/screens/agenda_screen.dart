import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/repositories/calendar_repository.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/calendar_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/event_time.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_list_skeleton.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/cards/event_card.dart';

/// Écran « Agenda » : grille du mois et liste **du mois entier**.
///
/// **Tapoter un jour fait défiler la liste jusqu'à lui — ça ne la filtre pas.**
/// Le contenu d'une église est très concentré : trois à cinq séries
/// hebdomadaires font une vingtaine d'occurrences dans le mois, mais réparties
/// sur trois ou quatre jours de la semaine seulement. Filtrer afficherait donc
/// une liste **vide la plupart du temps** — le lecteur tapote un jeudi, ne voit
/// rien, et conclut que l'application est cassée. La question qu'on pose à un
/// agenda d'église est « qu'est-ce qu'il y a ce mois-ci » ; la vue d'ensemble y
/// répond d'un coup d'œil, et le défilement n'est qu'un raccourci vers un jour.
///
/// L'état éphémère (mois consulté, jour mis en avant, position de défilement)
/// vit dans le `State` : ni provider — personne d'autre n'en a besoin — ni
/// `ValueNotifier` fabriqué dans `build()`, qui serait recréé à chaque image.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.initialMonth});

  /// Mois affiché au premier rendu ; `null` = le mois courant.
  ///
  /// Seul `null` sert en production. Le paramètre existe pour que les tests
  /// puissent épingler un mois précis (février bissextile, mois de 31 jours)
  /// sans dépendre de l'horloge de la machine qui les exécute.
  final EventMonth? initialMonth;

  /// Clé de la cellule du jour [day] dans la grille.
  static Key dayKey(int day) => ValueKey('agenda_day_$day');

  /// Clé de la [index]-ième case vide précédant le 1er du mois.
  static Key leadingBlankKey(int index) => ValueKey('agenda_blank_$index');

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  late EventMonth _month;

  /// Jour mis en avant dans la grille — `null` quand le mois consulté n'est pas
  /// celui de l'horloge : rien ne justifie d'y désigner un jour d'office.
  int? _selectedDay;

  final ScrollController _scroll = ScrollController();

  /// Ancres de défilement : une par jour **portant au moins une occurrence**,
  /// posée sur sa première carte. Conservées d'un rendu à l'autre — une
  /// `GlobalKey` recréée dans `build()` ne désignerait plus rien au moment où
  /// l'on veut défiler jusqu'à elle.
  final Map<int, GlobalKey> _anchors = {};

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth ?? EventMonth.current();
    _selectedDay = _isCurrentMonth(_month) ? DateTime.now().day : null;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static bool _isCurrentMonth(EventMonth month) =>
      month == EventMonth.current();

  GlobalKey _anchorFor(int day) =>
      _anchors.putIfAbsent(day, () => GlobalKey(debugLabel: 'agenda-day-$day'));

  /// Quantième du mois [month] auquel appartient [event], **dans le fuseau de
  /// la branche**, ou `null` si l'occurrence tombe hors du mois affiché.
  ///
  /// Le contrôle du mois n'est pas superflu : la fenêtre demandée au serveur est
  /// bornée en UTC, donc un rassemblement du 31 à 23 h 30 dans une branche à
  /// UTC+1 revient avec une date murale au 1er du mois suivant. Le compter dans
  /// la grille le poserait sur le mauvais jour.
  static int? _dayOf(ChurchEvent event, EventMonth month) {
    final local = wallClockAt(event.startsAt, event.timezone);
    if (local.year != month.year || local.month != month.month) return null;
    return local.day;
  }

  /// Nombre d'occurrences par quantième, pour les pastilles de la grille.
  static Map<int, int> _countByDay(List<ChurchEvent> events, EventMonth month) {
    final counts = <int, int>{};
    for (final event in events) {
      final day = _dayOf(event, month);
      if (day == null) continue;
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  void _goToMonth(EventMonth month) {
    setState(() {
      _month = month;
      _selectedDay = _isCurrentMonth(month) ? DateTime.now().day : null;
    });
    // Le mois change, la liste aussi : rester à mi-course du mois précédent
    // n'aurait aucun sens.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Met [day] en avant et **amène la liste jusqu'à lui**.
  ///
  /// Un jour sans occurrence n'est pas un cul-de-sac : on vise la première
  /// occurrence **à partir** de ce jour (à défaut, la dernière du mois). La
  /// liste, elle, reste entière dans tous les cas.
  void _selectDay(int day, List<ChurchEvent> events) {
    setState(() => _selectedDay = day);

    final populated = events
        .map((event) => _dayOf(event, _month))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    if (populated.isEmpty) return;

    final target = populated.firstWhere(
      (candidate) => candidate >= day,
      orElse: () => populated.last,
    );

    // Le jour mis en avant vient de changer : la cible n'est posée qu'au rendu
    // suivant, on attend donc l'image d'après pour connaître sa position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = _anchors[target]?.currentContext;
      if (anchor == null) return;
      Scrollable.ensureVisible(
        anchor,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final window = ref.watch(monthEventsProvider(_month));
    final events = window.value?.items ?? const <ChurchEvent>[];

    // Horizon : borne au-delà de laquelle le serveur **n'affirme rien**. Un mois
    // postérieur ne serait pas « vide », il serait inconnu — on désactive donc
    // la navigation plutôt que d'afficher une absence qu'on ne peut pas
    // garantir. Horizon inconnu (mode maquette, chargement en cours) = aucune
    // bride : on ne restreint jamais sur une information qu'on n'a pas.
    final horizon = ref.watch(eventsHorizonProvider(_month));
    final atHorizon = horizon != null && _month.to.isAfter(horizon);

    return Scaffold(
      appBar: BrandAppBar(
        title: _monthTitle(_month, l10n.localeName),
        actions: [
          _MonthArrow(
            icon: Icons.chevron_left,
            tooltip: l10n.agendaPreviousMonth,
            onPressed: () => _goToMonth(_month.previous),
          ),
          _MonthArrow(
            icon: Icons.chevron_right,
            tooltip: l10n.agendaNextMonth,
            onPressed: atHorizon ? null : () => _goToMonth(_month.next),
          ),
        ],
      ),
      // `SingleChildScrollView` et non `ListView` : défiler jusqu'à un jour
      // suppose que sa carte soit **posée**, or une liste paresseuse ne
      // construit pas ce qui est hors champ. Un mois d'église tient en quelques
      // dizaines de cartes ; la construction paresseuse n'y gagnerait rien et
      // coûterait la fonctionnalité.
      body: SingleChildScrollView(
        controller: _scroll,
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            _MonthCalendar(
              month: _month,
              counts: _countByDay(events, _month),
              selectedDay: _selectedDay,
              onDaySelected: (day) => _selectDay(day, events),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildBody(window, l10n),
            if (window.hasValue && atHorizon)
              AppEmptyState(
                variant: AppEmptyStateVariant.endOfRange,
                title: l10n.agendaHorizonTitle,
                message: l10n.agendaHorizonMessage,
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// Les trois états de la liste : chargement, échec, contenu (dont le vide).
  Widget _buildBody(AsyncValue<EventWindow> window, AppLocalizations l10n) {
    return switch (window) {
      AsyncError(:final error) => AppErrorState(
          message: _errorMessage(error, l10n),
          onRetry: () => ref.invalidate(monthEventsProvider(_month)),
        ),
      AsyncData(:final value) => _buildList(value.items, l10n),
      _ => const AppListSkeleton(itemCount: 4),
    };
  }

  Widget _buildList(List<ChurchEvent> events, AppLocalizations l10n) {
    if (events.isEmpty) {
      return AppEmptyState(
        title: l10n.agendaEmptyMonthTitle,
        message: l10n.agendaEmptyMonthMessage,
        icon: Icons.event_busy_outlined,
      );
    }

    // Une ancre par jour, posée sur sa **première** occurrence : c'est là que le
    // lecteur veut arriver quand il tapote ce jour.
    final anchored = <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in events) ...[
          KeyedSubtree(
            key: switch (_dayOf(event, _month)) {
              final int day when anchored.add(day) => _anchorFor(day),
              _ => null,
            },
            child: EventCard(
              event: event,
              onTap: () =>
                  context.pushNamed(AppRoute.eventDetail, extra: event),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Cause de l'échec, **en langage humain**.
///
/// `null` laisse `AppErrorState` sur son message réseau par défaut : c'est le
/// cas majoritaire (coupure). Un serveur joignable mais en panne mérite un autre
/// texte — dire « vérifiez votre connexion » à quelqu'un dont la connexion
/// fonctionne est une fausse piste.
String? _errorMessage(Object error, AppLocalizations l10n) =>
    error is CalendarException && error.code == CalendarErrorCode.server
        ? l10n.stateErrorServerMessage
        : null;

/// Intitulé du mois affiché (« Juillet 2026 »), dans la locale courante.
///
/// `intl` décide de l'ordre et du libellé ; on ne pose que la majuscule
/// initiale, que le français attend en tête de titre et que `DateFormat` ne met
/// pas.
String _monthTitle(EventMonth month, String locale) {
  final text =
      DateFormat.yMMMM(locale).format(DateTime(month.year, month.month));
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// Flèche de navigation entre mois, posée sur le dégradé de la [BrandAppBar].
///
/// `onPressed` à `null` la grise : c'est ainsi que se lit la borne d'horizon.
class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      // Contenu posé sur le dégradé primaire : la couleur « sur primaire » du
      // système de design, pas la palette de surface (illisible ici).
      color: AppColors.textOnPrimary,
      disabledColor: AppColors.textOnPrimary.withValues(alpha: 0.38),
    );
  }
}

/// Grille calendaire d'un mois : en-têtes Lun→Dim, pastilles d'occurrences,
/// jour mis en avant.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.counts,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final EventMonth month;

  /// Nombre d'occurrences par quantième (les jours sans évènement sont absents).
  final Map<int, int> counts;

  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = context.l10n;

    // Jour 0 du mois suivant = dernier jour de celui-ci : les années
    // bissextiles sont l'affaire de `DateTime`, pas la nôtre.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Grille lundi→dimanche : `DateTime.weekday` vaut 1 pour lundi.
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;

    final today = DateTime.now();
    final todayDay =
        today.year == month.year && today.month == month.month ? today.day : 0;

    final weekdays = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];

    final cells = <Widget>[
      for (final label in weekdays)
        Center(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
        ),
      for (var i = 0; i < leadingBlanks; i++)
        SizedBox.shrink(key: AgendaScreen.leadingBlankKey(i)),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          key: AgendaScreen.dayKey(day),
          day: day,
          count: counts[day] ?? 0,
          selected: day == selectedDay,
          isToday: day == todayDay,
          onTap: () => onDaySelected(day),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palette.divider),
      ),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        children: cells,
      ),
    );
  }
}

/// Une case de la grille : le quantième, et sous lui les pastilles.
class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.count,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.agendaDaySummary(day, count),
      // Le quantième et les pastilles sont déjà résumés par le libellé ci-dessus
      // : les laisser parler séparément ferait lire « 12 », puis « 12, 2
      // évènements ».
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        // Sur un très petit écran la case peut être plus étroite que son
        // contenu : on réduit plutôt que de déborder.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? palette.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: palette.primary)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: AppTypography.caption.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : palette.textPrimary,
                    fontWeight:
                        selected || isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              _DayDots(count: count, selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilles d'un jour : **une par occurrence**, jusqu'à trois.
///
/// Un point unique quel que soit le nombre masquerait exactement ce que l'agenda
/// doit montrer : deux rassemblements peuvent tomber le même jour, et c'est
/// précisément le jour où le lecteur doit y regarder à deux fois. Au-delà de
/// trois, la nuance ne se lit plus à cette taille — la liste, elle, les porte
/// tous.
class _DayDots extends StatelessWidget {
  const _DayDots({required this.count, required this.selected});

  final int count;
  final bool selected;

  static const int _maxDots = 3;
  static const double _size = 4;

  @override
  Widget build(BuildContext context) {
    final shown = count > _maxDots ? _maxDots : count;
    final palette = context.palette;
    final color =
        selected ? palette.primary : palette.primary.withValues(alpha: 0.75);

    return SizedBox(
      height: _size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}
