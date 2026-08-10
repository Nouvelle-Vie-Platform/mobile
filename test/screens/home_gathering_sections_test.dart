import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';
import 'package:maison_du_miracle/widgets/home/home_content_cards.dart';
import 'package:maison_du_miracle/widgets/home/home_gathering_section.dart';
import 'package:maison_du_miracle/widgets/home/home_teaching_section.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/pump_screen.dart';

/// **Les rassemblements à l'accueil**, composés depuis leur propre référentiel.
///
/// Tout se joue sur le **vrai magasin**, en mémoire, et sur la chaîne entière —
/// lignes répliquées → `GatheringDao.homeSections()` → modèle de lecture →
/// écran. Ce n'est pas « un écran sait afficher une liste » qui est vérifié,
/// c'est que **deux référentiels alimentent deux blocs sans jamais se croiser**.
///
/// L'agenda est neutralisé : la section « À venir » n'est pas le sujet.
class _EmptyCalendarRepository implements CalendarRepository {
  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async =>
      EventWindow.empty;
}

/// `testWidgets`, **plus le démontage explicite de l'arbre dans le corps du
/// test** — même raison que `home_sections_test.dart` : fermer le dernier
/// abonné d'un flux Drift planifie une minuterie à zéro que l'horloge factice
/// ne ferait jamais partir.
void homeTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

void main() {
  late AppDatabase db;
  late SyncDao sync;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
  });

  tearDown(() => db.close());

  Future<void> putGatheringTypes(List<GatheringTypesCompanion> rows) => sync
      .applyPage(sync.gatheringTypesCollection, upserts: rows, cursor: 'gt-1');

  Future<void> putGatherings(
    List<GatheringsCompanion> rows, {
    String cursor = 'g-1',
  }) =>
      sync.applyPage(sync.gatheringsCollection, upserts: rows, cursor: cursor);

  /// Monte l'accueil branché sur le magasin de ce test — les **deux** familles
  /// lisent la même base en mémoire, comme sur un vrai appareil.
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const Scaffold(body: HomeScreen()),
      mediatheque: StoreMediathequeRepository(db.mediathequeDao),
      gatherings: StoreGatheringRepository(db.gatheringDao),
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_EmptyCalendarRepository())
      ],
    );
  }

  homeTest('une rubrique de rassemblement garnie sort à l\'accueil',
      (tester) async {
    await putGatheringTypes([
      gatheringTypeRow(11,
          label: {'fr': 'Concerts'}, slug: 'concerts', layout: 'hero'),
    ]);
    await putGatherings([
      gatheringRow('g-1', title: 'Nuit de gloire', teachingTypeId: 11),
    ]);

    await pumpHome(tester);

    expect(find.text('RASSEMBLEMENTS'), findsOneWidget);
    expect(find.byType(HomeGatheringSection), findsOneWidget);
    expect(find.text('CONCERTS'), findsOneWidget);
    expect(find.text('Nuit de gloire'), findsOneWidget);
    // La mise en page vient du référentiel de rassemblement, comme pour
    // l'autre famille : `hero` demande de grandes cartes.
    expect(find.byType(HomeHeroCard), findsOneWidget);
  });

  homeTest('pas de rassemblement, pas de section — ni titre de bloc',
      (tester) async {
    // Une rubrique visible, mais dont le magasin ne possède aucun contenu.
    // C'est ce qui fait disparaître d'elle-même une rubrique supprimée côté
    // serveur : `gathering_types` n'a pas de tombstone.
    await putGatheringTypes([
      gatheringTypeRow(11, label: {'fr': 'Concerts'}, slug: 'concerts'),
    ]);

    await pumpHome(tester);

    expect(find.byType(HomeGatheringSection), findsNothing);
    // Le titre du bloc n'apparaît que s'il y a quelque chose sous lui : un
    // en-tête suivi du vide est pire que rien.
    expect(find.text('RASSEMBLEMENTS'), findsNothing);
  });

  homeTest(
      'une rubrique de rassemblement masquée n\'y paraît pas, même remplie',
      (tester) async {
    await putGatheringTypes([
      gatheringTypeRow(11,
          label: {'fr': 'Archives'}, slug: 'archives', visibleOnHome: false),
    ]);
    await putGatherings([gatheringRow('g-1', teachingTypeId: 11)]);

    await pumpHome(tester);

    expect(find.byType(HomeGatheringSection), findsNothing);
    expect(find.text('RASSEMBLEMENTS'), findsNothing);
  });

  homeTest('les deux référentiels ne se croisent jamais à l\'écran',
      (tester) async {
    // **Le même identifiant de rubrique des deux côtés**, et deux libellés
    // différents : rien ne garantit que les SERIAL de deux collections soient
    // disjoints, et c'est la table jointe qui décide, jamais l'identifiant.
    await sync.applyPage(
      sync.teachingTypesCollection,
      upserts: [
        teachingTypeRow(1, label: {'fr': 'Dimanche'}, slug: 'dimanche')
      ],
      cursor: 'tt-1',
    );
    await sync.applyPage(
      sync.teachingsCollection,
      upserts: [
        teachingRow('t-1', title: 'Dieu a le dernier mot', teachingTypeId: 1)
      ],
      cursor: 'tc-1',
    );
    await putGatheringTypes([
      gatheringTypeRow(1, label: {'fr': 'Concerts'}, slug: 'concerts'),
    ]);
    await putGatherings([
      gatheringRow('g-1', title: 'Nuit de gloire', teachingTypeId: 1),
    ]);

    await pumpHome(tester);

    expect(find.byType(HomeTeachingSection), findsOneWidget);
    expect(find.byType(HomeGatheringSection), findsOneWidget);
    expect(find.text('DIMANCHE'), findsOneWidget);
    expect(find.text('CONCERTS'), findsOneWidget);

    // Chaque section ne porte que les contenus de sa famille.
    expect(
      find.descendant(
        of: find.byType(HomeGatheringSection),
        matching: find.text('Dieu a le dernier mot'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(HomeTeachingSection),
        matching: find.text('Nuit de gloire'),
      ),
      findsNothing,
    );
  });

  homeTest(
      'un magasin qui n\'a que des rassemblements ne se dit pas « pas encore '
      'synchronisé »', (tester) async {
    // Les trois flux décident ensemble : le magasin **a** reçu quelque chose,
    // même si la médiathèque est vide. Annoncer « pas encore synchronisé »
    // ferait croire l'église muette alors qu'elle publie.
    await putGatheringTypes([
      gatheringTypeRow(11, label: {'fr': 'Concerts'}, slug: 'concerts'),
    ]);
    await putGatherings([
      gatheringRow('g-1', title: 'Nuit de gloire', teachingTypeId: 11),
    ]);

    await pumpHome(tester);

    expect(find.byType(ContentAbsenceView), findsNothing);
    expect(find.text('Nuit de gloire'), findsOneWidget);
  });
}
