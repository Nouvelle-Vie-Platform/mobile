import 'package:flutter_test/flutter_test.dart';

import '../helpers/sync_fixtures.dart';

/// **Le contrat serveur, écrit noir sur blanc.**
///
/// Ces tests ne vérifient pas du code applicatif : ils gardent les *fixtures*.
/// Leur rôle est qu'une « correction » faite plus tard sur une intuition — tout
/// passer en `snake_case`, ajouter un `deletedAt` aux enseignements, faire de
/// `recordedAt` un instant — échoue tout de suite, ici, plutôt qu'en
/// production sur le téléphone d'un fidèle.
///
/// Chaque groupe cite la route serveur dont il relève. La table complète des
/// origines est en tête de `test/helpers/sync_fixtures.dart`.
void main() {
  group('GET /sync — l\'enveloppe du manifeste est en snake_case', () {
    test('les treize collections du registre, dans l\'ordre', () {
      expect(kSyncCollections, hasLength(13));
      expect(
        _collections(manifestNominal()).map((c) => c['key']),
        kSyncCollections.keys,
      );
    });

    test('les clés de protocole ne sont jamais en camelCase', () {
      final manifest = manifestNominal();

      expect(manifest.keys, containsAll(['scope_version', 'collections']));
      for (final entry in _collections(manifest)) {
        expect(entry.keys, [
          'key',
          'partition',
          'current_cursor',
          'has_changes',
          'from_zero',
          'full_resync_required',
        ]);
      }
    });

    test('la partition vaut branch, private ou reference', () {
      for (final entry in _collections(manifestNominal())) {
        expect(
          entry['partition'],
          isIn(const ['branch', 'private', 'reference']),
        );
      }
    });

    test('`from_zero` : le client n\'a aucun curseur, la collection en a un',
        () {
      for (final entry in _collections(manifestFromZero())) {
        expect(entry['from_zero'], isTrue);
        expect(entry['has_changes'], isTrue);
        expect(entry['current_cursor'], isNotNull);
      }
    });

    test('`has_changes: false` garde quand même le curseur courant', () {
      for (final entry in _collections(manifestNothingToPull())) {
        expect(entry['has_changes'], isFalse);
        // La borne haute du périmètre, pas un accusé de réception.
        expect(entry['current_cursor'], isNotNull);
      }
    });

    test('droits changés : `full_resync_required` sur les seules `branch`', () {
      for (final entry in _collections(manifestScopeChanged())) {
        expect(
          entry['full_resync_required'],
          entry['partition'] == 'branch',
          reason: 'le garde-fou « droits changés » ne vise que les collections '
              'branch — un référentiel comme `${entry['key']}` ne peut pas le '
              'lever, et c\'est pourquoi le vérifier sur `branches` ne '
              'vérifiait rien',
        );
      }
    });

    test('curseur périmé : `full_resync_required` sur toutes les partitions',
        () {
      for (final entry in _collections(manifestStaleCursor())) {
        expect(entry['full_resync_required'], isTrue);
      }
    });

    test('la `scope_version` progresse et n\'est jamais l\'écho du client', () {
      final versions = manifestScopeVersionProgression()
          .map((m) => m['scope_version'])
          .toList(growable: false);

      expect(versions, [4, 5, 5]);
    });
  });

  group('GET /sync/{collection} — l\'enveloppe du tirage', () {
    test('quatre clés, toutes en snake_case', () {
      expect(deltaPage().keys, [
        'items',
        'next_cursor',
        'has_more',
        'full_resync',
      ]);
    });

    test('resync forcé : un 200 à `items` vide et `next_cursor` nul', () {
      final page = fullResyncPage();

      expect(page['full_resync'], isTrue);
      expect(page['items'], isEmpty);
      expect(page['next_cursor'], isNull);
      expect(page['has_more'], isFalse);
    });

    test('page vide : le curseur entrant est conservé', () {
      final page = emptyPageKeepingCursor(teachingsCursorPage2);

      expect(page['items'], isEmpty);
      expect(page['next_cursor'], teachingsCursorPage2);
      expect(page['full_resync'], isFalse);
    });

    test('page vide depuis zéro : le curseur reste nul', () {
      expect(emptyPageFromZero()['next_cursor'], isNull);
    });

    test('`has_more` mène à une page finale, pas à un tableau vide', () {
      final pages = teachingsPagesAtLimitOne();

      expect(pages.take(2).map((p) => p['has_more']), everyElement(isTrue));
      expect(pages.last['has_more'], isFalse);
      expect(pages.last['items'], isNotEmpty);
      // Les curseurs avancent : chaque page rend celui de sa dernière ligne.
      expect(
        pages.map((p) => p['next_cursor']).toSet(),
        hasLength(pages.length),
      );
    });

    test('le curseur est opaque : le client le rejoue, il ne le lit pas', () {
      // Sa forme (base64url d'un JSON `{u, i}`) n'appartient qu'au serveur —
      // ADR-0026 interdit au client d'en fabriquer un. On vérifie seulement
      // qu'il ne ressemble à rien d'interprétable.
      expect(teachingsCursorPage1, isNot(contains('=')));
      expect(teachingsCursorPage1, isNot(contains('2026')));
      expect(staleCursor, isNot(teachingsCursorPage1));
    });
  });

  group('GET /sync/teachings — la ligne', () {
    /// Les dix-huit clés d'un enseignement, en `camelCase`.
    const keys = [
      'id',
      'ownerId',
      'branchId',
      'contributorId',
      'teachingTypeId',
      'title',
      'description',
      'isLive',
      'isFullService',
      'playlistUrl',
      'imageLandscapeUrl',
      'imagePortraitUrl',
      'publishedAt',
      'clientCreatedAt',
      'createdAt',
      'updatedAt',
      'recordedAt',
      'color',
    ];

    test('dix-huit clés, ni une de plus', () {
      expect(keys, hasLength(18));
      for (final teaching in _teachings) {
        expect(teaching.keys.toSet(), keys.toSet());
      }
    });

    test('ni `family`, ni `deletedAt`, ni durée, ni `mimeType`', () {
      for (final teaching in _teachings) {
        expect(
          teaching.keys,
          isNot(anyElement(isIn(const [
            'family',
            'deletedAt',
            'duration',
            'durationSeconds',
            'mimeType',
          ]))),
        );
      }
    });

    test('`recordedAt` est un jour, pas un instant', () {
      for (final teaching in _teachings) {
        expect(
          teaching['recordedAt'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          reason: 'la date d\'un culte ne se décale pas d\'un fuseau',
        );
      }
    });

    test('les autres dates sont des instants ISO-8601 analysables', () {
      for (final teaching in _teachings) {
        for (final key in const ['createdAt', 'updatedAt']) {
          expect(
            DateTime.tryParse(teaching[key]! as String),
            isNotNull,
            reason: '$key doit être analysé, jamais comparé comme une chaîne',
          );
        }
      }
    });

    test('les images sont relatives, à résoudre contre la base d\'API', () {
      for (final teaching in _teachings) {
        for (final key in const ['imageLandscapeUrl', 'imagePortraitUrl']) {
          expect(teaching[key], startsWith('/uploads/'));
          expect(teaching[key], isNot(startsWith('http')));
        }
      }
    });

    test('`playlistUrl` peut être nul : un enseignement précède son média', () {
      expect(teachingWithoutPlaylistPayload['playlistUrl'], isNull);
      expect(fullTeachingPayload['playlistUrl'], isNotNull);
    });

    test('`color` peut être nulle : « hérite de ma rubrique »', () {
      // Aujourd'hui le serveur résout toujours la cascade ; l'issue serveur
      // #130 le fera servir `null`. Les deux cas existent dès maintenant pour
      // qu'un désérialiseur strict ne casse pas le jour de la bascule.
      expect(teachingWithoutColorPayload['color'], isNull);
      expect(fullTeachingPayload['color'], matches(RegExp(r'^#[0-9A-F]{6}$')));
    });

    test('`branchId` nul veut dire national, pas « inconnu »', () {
      expect(teachingWithoutColorPayload['branchId'], isNull);
      expect(fullTeachingPayload['branchId'], isA<int>());
    });
  });

  group('GET /sync/teachings — la rétractation', () {
    test('exactement deux clés', () {
      for (final retraction in const [
        retractedTeachingPayload,
        otherRetractedTeachingPayload,
      ]) {
        expect(
          retraction.keys.toSet(),
          {'id', 'deletedAt'},
          reason: 'la ligne existe toujours côté serveur et n\'a pas le droit '
              'd\'être vue : servir son titre annulerait le geste',
        );
      }
    });

    test('elle ne dit rien du contenu retiré', () {
      expect(retractedTeachingPayload.containsKey('title'), isFalse);
      expect(retractedTeachingPayload.containsKey('contributorId'), isFalse);
      expect(retractedTeachingPayload.containsKey('branchId'), isFalse);
    });

    test('`deletedAt` est un instant analysable', () {
      expect(
        DateTime.tryParse(retractedTeachingPayload['deletedAt']! as String),
        isNotNull,
      );
    });
  });

  group('La page qui mélange enseignements et rétractations', () {
    test('les deux natures voyagent dans le même tableau', () {
      final items =
          (mixedTeachingsPage()['items']! as List).cast<Map<String, Object?>>();

      expect(items.where((i) => i.length == 2), hasLength(2));
      expect(items.where((i) => i.length == 18), hasLength(3));
    });

    test('une rétractation est en dernière position', () {
      final items =
          (mixedTeachingsPage()['items']! as List).cast<Map<String, Object?>>();

      // Un désérialiseur qui ne se protège que du premier élément se fait
      // quand même prendre : le tri du serveur est `(updated_at, id)`, il ne
      // regroupe rien.
      expect(items.last.keys.toSet(), {'id', 'deletedAt'});
    });

    test('aucune rétractation ne porte les clés qu\'un fromJson strict exige',
        () {
      final items =
          (mixedTeachingsPage()['items']! as List).cast<Map<String, Object?>>();

      for (final item in items.where((i) => i.containsKey('deletedAt'))) {
        for (final required in const ['title', 'recordedAt', 'color']) {
          expect(
            item.containsKey(required),
            isFalse,
            reason: 'le flux se lit « rétractation ou ligne », décidé AVANT '
                'toute construction d\'objet',
          );
        }
      }
    });
  });

  group('Les référentiels', () {
    test('teaching_types : label multilingue {fr, en, ee}', () {
      for (final type in _teachingTypes) {
        final label = type['label']! as Map<String, Object?>;
        expect(label.keys.toSet(), {'fr', 'en', 'ee'});
        expect(label['fr'], isNotEmpty);
      }
    });

    test('teaching_types : `layout` dans le jeu fermé', () {
      expect(kTeachingTypeLayouts, ['hero', 'carousel', 'list']);
      expect(
        _teachingTypes.map((t) => t['layout']).toSet(),
        kTeachingTypeLayouts.toSet(),
      );
    });

    test('teaching_types : une rubrique masquée voyage quand même', () {
      expect(hiddenTeachingTypePayload['visibleOnHome'], isFalse);
      expect(
        (teachingTypesPage()['items']! as List),
        contains(hiddenTeachingTypePayload),
        reason: 'c\'est `visibleOnHome` qui apprend au client qu\'une rubrique '
            'a quitté l\'accueil ; la filtrer la ferait disparaître du delta',
      );
    });

    test('teaching_types : `position` ordonne l\'accueil', () {
      expect(
        _teachingTypes.map((t) => t['position']),
        everyElement(isA<int>()),
      );
    });

    test('les référentiels ont un `id` entier (PK SERIAL)', () {
      for (final row in [
        ..._teachingTypes,
        contributorPayload,
        contributorWithoutBioPayload,
        branchPayload,
        motherBranchPayload,
      ]) {
        expect(row['id'], isA<int>());
      }
    });

    test('contributors : cinq clés, ni `prefix` ni `category`', () {
      expect(contributorPayload.keys.toSet(), {
        'id',
        'name',
        'bio',
        'createdAt',
        'updatedAt',
      });
      expect(contributorWithoutBioPayload['bio'], isNull);
    });

    test('branches : ni `timezone` ni `pastorId` ne voyagent', () {
      expect(branchPayload.keys.toSet(), {
        'id',
        'name',
        'isMotherChurch',
        'address',
        'email',
        'phone',
        'postalBox',
        'createdAt',
        'updatedAt',
      });
      expect(motherBranchPayload['isMotherChurch'], isTrue);
    });
  });
}

const List<Map<String, Object?>> _teachings = [
  fullTeachingPayload,
  teachingWithoutPlaylistPayload,
  teachingWithoutColorPayload,
];

const List<Map<String, Object?>> _teachingTypes = [
  heroTeachingTypePayload,
  carouselTeachingTypePayload,
  hiddenTeachingTypePayload,
];

List<Map<String, Object?>> _collections(Map<String, Object?> manifest) =>
    (manifest['collections']! as List).cast<Map<String, Object?>>();
