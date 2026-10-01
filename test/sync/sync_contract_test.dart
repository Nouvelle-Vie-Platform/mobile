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
    test('les vingt-neuf collections du registre, dans l\'ordre', () {
      // **Ce nombre avait menti.** Il disait dix-neuf quand le registre serveur
      // en comptait vingt-cinq, et le test passait au vert en gardant un contrat
      // périmé — `seasons`, `decor`, `teaching_guests`, `group_members`,
      // `profiles` et `group_join_requests` manquaient, dont quatre que ce
      // client réplique. Remis d'aplomb en #81, où `presentation_vocabulary`
      // devient la vingt-sixième.
      //
      // **Et l'en-tête du registre serveur ment à son tour** : il annonçait
      // « vingt-six » alors que son tableau en portait déjà vingt-sept,
      // `auth_channels` comprise. Ce nombre-ci est **compté sur les
      // descripteurs**, jamais lu dans la phrase qui les précède — recompté en
      // #91, où `device_settings` devient la vingt-huitième, puis en #82, où
      // `menu_entries` devient la vingt-neuvième. Cette fois l'en-tête et le
      // tableau s'accordent, et c'est le **tableau** qui a été compté.
      expect(kSyncCollections, hasLength(29));
      expect(
        _collections(manifestNominal()).map((c) => c['key']),
        kSyncCollections.keys,
      );
    });

    test('le vocabulaire est un référentiel, rangé avant les contenus', () {
      // `partition: 'reference'` : un mot n'appartient à aucune branche — il n'y
      // a qu'un site public et qu'une application, et le mot choisi depuis Aného
      // est celui de Lomé. Et il est **servi au porteur sans compte**, faute de
      // quoi deux téléphones côte à côte montreraient deux vocabulaires.
      expect(kSyncCollections['presentation_vocabulary'], 'reference');

      final keys = kSyncCollections.keys.toList();
      expect(
        keys.indexOf('presentation_vocabulary'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('presentation_vocabulary'),
        lessThan(keys.indexOf('gatherings')),
      );
    });

    test('les canaux de connexion sont un référentiel, servi sans compte', () {
      // `partition: 'reference'` : une porte d'entrée n'appartient à aucune
      // branche — il n'y a pas une connexion de Lomé et une d'Aného. Et la
      // collection est servie **sans compte** (`servesAnonymous: true`) : l'écran
      // de connexion est par définition regardé par quelqu'un qui n'en a pas, et
      // un refus y laisserait l'application proposer pour toujours une porte
      // fermée.
      expect(kSyncCollections['auth_channels'], 'reference');

      final keys = kSyncCollections.keys.toList();
      // Rangée avec les référentiels, avant les contenus : toute erreur autre
      // qu'un 404 coupe le cycle, donc toutes les collections rangées après.
      //
      // ⚠️ La comparaison ne vise pas `announcements`, et ce n'est pas un
      // oubli : elle ouvre le registre serveur depuis l'issue #46, avant même
      // les référentiels. **L'ordre du manifeste n'est pas l'ordre
      // d'application du client** — celui-là vit dans `synced_collection.dart`,
      // et c'est `test/sync/auth_channels_collection_test.dart` qui le garde.
      expect(
        keys.indexOf('auth_channels'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('auth_channels'),
        lessThan(keys.indexOf('gatherings')),
      );
    });

    test('le réglage du parc est un référentiel, servi sans compte', () {
      // `partition: 'reference'` : un parc d'appareils n'appartient à aucune
      // branche — il n'y a pas une version recommandée à Lomé et une autre à
      // Aného. Et la collection est servie **sans compte**
      // (`servesAnonymous: true`) : un invité utilise l'application, et son APK
      // est exactement aussi vieux que celui du membre assis à côté de lui. Sans
      // ce drapeau, deux téléphones côte à côte sur la même version périmée
      // n'auraient qu'un seul avertissement — et l'oubli n'aurait rien cassé de
      // visible, puisqu'un bandeau qui se tait ressemble à un bandeau qui n'a
      // rien à dire.
      expect(kSyncCollections['device_settings'], 'reference');

      final keys = kSyncCollections.keys.toList();
      // Rangée avec les référentiels, avant les contenus : toute erreur autre
      // qu'un 404 coupe le cycle, donc toutes les collections rangées après.
      //
      // ⚠️ Même remarque que pour les canaux : la comparaison ne vise pas
      // `announcements`, qui ouvre le registre serveur depuis #46. L'ordre du
      // manifeste n'est pas l'ordre d'application du client — celui-là vit dans
      // `synced_collection.dart`, et c'est
      // `test/sync/device_settings_collection_test.dart` qui le garde.
      expect(
        keys.indexOf('device_settings'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('device_settings'),
        lessThan(keys.indexOf('gatherings')),
      );
    });

    test('les menus sont un référentiel, servi sans compte et sans tombstone',
        () {
      // `partition: 'reference'` : un menu n'appartient à aucune branche — il y a
      // un site public et une application, et la barre réglée depuis Aného est
      // celle de Lomé. `scopeFilter` est donc vide, et ce vide **est** la
      // décision.
      expect(kSyncCollections['menu_entries'], 'reference');

      final keys = kSyncCollections.keys.toList();
      // Rangée **immédiatement après le vocabulaire et avant `decor`** : c'est
      // la position réelle du tableau `syncDescriptors`, relevée dessus et non
      // sur l'intuition qu'un menu « devrait » venir avec les référentiels
      // d'habillage.
      expect(
        keys.indexOf('menu_entries'),
        keys.indexOf('presentation_vocabulary') + 1,
      );
      expect(keys.indexOf('menu_entries'), lessThan(keys.indexOf('decor')));
      // Et avant tout contenu : un menu doit arriver avant les listes qu'il
      // intitule, et toute erreur autre qu'un 404 coupe le cycle, donc toutes
      // les collections rangées après la fautive.
      expect(
        keys.indexOf('menu_entries'),
        lessThan(keys.indexOf('teachings')),
      );
      expect(
        keys.indexOf('menu_entries'),
        lessThan(keys.indexOf('gatherings')),
      );
    });

    test('un pivot est un référentiel, une appartenance est privée', () {
      // Les deux partitions qu'on corrigerait de travers, et qui se relèvent sur
      // le champ `partition:` du descripteur, jamais sur l'intuition.
      expect(kSyncCollections['teaching_guests'], 'reference');
      expect(kSyncCollections['group_members'], 'private');
      expect(kSyncCollections['profiles'], 'private');
      expect(kSyncCollections['group_join_requests'], 'private');
    });

    test(
      'les deux familles de la médiathèque ont chacune leur paire de clés',
      () {
        // **Quatre clés, pas deux élargies** (issue serveur #133). Une
        // collection neuve est ignorée par un client qui ne la demande pas ; une
        // collection élargie contamine ceux qui ne savent pas la lire — un
        // concert arrivé dans `teachings` se rangerait dans les rubriques
        // d'accueil de la médiathèque et s'y afficherait comme un message du
        // dimanche.
        expect(kSyncCollections['teaching_types'], 'reference');
        expect(kSyncCollections['gathering_types'], 'reference');
        expect(kSyncCollections['teachings'], 'branch');
        expect(kSyncCollections['gatherings'], 'branch');
      },
    );

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
    /// Les vingt clés d'un enseignement, en `camelCase`.
    ///
    /// **La dix-neuvième est `download`** (ADR-0038, issue #188) : le contrat de
    /// téléchargement hors ligne, additif à `playlistUrl` et servi par le même
    /// transformer. Il vaut `null` tant que l'enseignement n'a pas de `.aac`.
    ///
    /// **La vingtième est `imageSquareUrl`** (issue #209) : le troisième cadrage,
    /// additif au paysage et au portrait, servi par le même `TeachingTransformer`.
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
      'download',
      'imageLandscapeUrl',
      'imagePortraitUrl',
      'imageSquareUrl',
      'publishedAt',
      'clientCreatedAt',
      'createdAt',
      'updatedAt',
      'recordedAt',
      'color',
    ];

    test('vingt clés, ni une de plus', () {
      expect(keys, hasLength(20));
      for (final teaching in _teachings) {
        expect(teaching.keys.toSet(), keys.toSet());
      }
    });

    test('`download` porte version, durée et une rendition par qualité', () {
      // Relevé sur `download_info.ts` : `{ version, duration, renditions }`,
      // chaque rendition `{ url, bytes }`. C'est ce qui donne au client les URLs
      // et les tailles **hors ligne** (pourcentage, reprise `Range`, pré-check
      // disque) sans jamais toucher au réseau.
      final download = fullTeachingPayload['download']! as Map<String, Object?>;
      expect(download['version'], isA<String>());
      expect(download['duration'], isA<int>());
      final renditions = download['renditions']! as Map<String, Object?>;
      expect(renditions.keys.toSet(), {'low', 'mid', 'high'});
      for (final entry in renditions.values) {
        final rendition = entry! as Map<String, Object?>;
        expect(rendition['url'], isA<String>());
        expect(rendition['bytes'], isA<int>());
      }
    });

    test('`download` peut être nul : un enseignement n\'est pas téléchargeable',
        () {
      // Fonds ancien jamais re-transcodé, ou média HLS sans `.aac` : le
      // téléchargeable est **additif**, il n'accompagne pas forcément le HLS.
      expect(teachingWithoutPlaylistPayload['download'], isNull);
      expect(teachingWithoutColorPayload['download'], isNull);
      expect(fullTeachingPayload['download'], isNotNull);
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
        for (final key in const [
          'imageLandscapeUrl',
          'imagePortraitUrl',
          'imageSquareUrl',
        ]) {
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

  group('GET /sync/teaching_guests — la ligne', () {
    /// Les **sept** clés d'un crédit d'invité, en `camelCase`, relevées sur
    /// `teaching_guest_transformer.ts` (issue serveur #436).
    const keys = [
      'id',
      'teachingId',
      'contributorId',
      'position',
      'createdAt',
      'updatedAt',
      'deletedAt',
    ];

    test('sept clés, ni une de plus', () {
      expect(keys, hasLength(7));
      for (final guest in _teachingGuests) {
        expect(guest.keys.toSet(), keys.toSet());
      }
    });

    test('ni nom, ni biographie, ni titre, ni rôle : rien de dénormalisé', () {
      // **Le cœur du contrat.** Un nom recopié dans le pivot serait une valeur
      // **figée** : renommer un intervenant n'écrit rien sur `teaching_guests`,
      // donc ne bouscule aucun `updatedAt`, donc la ligne ne repasserait
      // **jamais** dans le flux delta — le téléphone afficherait l'ancien nom
      // indéfiniment et en silence. Le client joint contre sa copie de
      // `contributors` (ADR-0026, décision 3).
      //
      // Pas de `role` non plus, et ce n'est pas un oubli : `contributorId` sur
      // l'enseignement **est** l'animateur, être dans ce pivot veut dire être
      // invité. Le nom de la collection porte le sens.
      for (final guest in _teachingGuests) {
        expect(
          guest.keys,
          isNot(anyElement(isIn(const [
            'name',
            'contributorName',
            'bio',
            'title',
            'teachingTitle',
            'role',
          ]))),
        );
      }
    });

    test('deux identifiants, deux types préservés', () {
      // L'identifiant du pivot est un **entier** (`increments` côté serveur),
      // celui du parent un **UUIDv7**. Les confondre ferait comparer
      // `'10' < '9'` quelque part, et le client rangerait la ligne au mauvais
      // endroit.
      for (final guest in _teachingGuests) {
        expect(guest['id'], isA<int>());
        expect(guest['teachingId'], isA<String>());
        expect(guest['contributorId'], isA<int>());
      }
    });

    test('`position` est l\'ordre saisi, 1-based', () {
      // Le générique d'un enseignement à plusieurs voix n'est pas une liste
      // alphabétique : l'ordre est une **donnée**, pas un tri que le client
      // pourrait recalculer. Le défaut serveur est `1`, jamais `0`.
      for (final guest in _teachingGuests) {
        expect(guest['position'], isA<int>());
        expect(guest['position']! as int, greaterThanOrEqualTo(1));
      }
      expect(teachingGuestPayload['position'], 1);
      expect(secondTeachingGuestPayload['position'], 2);
    });

    test('`deletedAt` voyage toujours, `null` compris', () {
      // C'est le drapeau tombstone (ADR-0017), et il est servi sur **chaque**
      // ligne, vivante comprise : un client qui ne le verrait que sur un retrait
      // ne saurait pas que cette collection en émet.
      for (final guest in _teachingGuests) {
        expect(guest.keys, contains('deletedAt'));
      }
      expect(teachingGuestPayload['deletedAt'], isNull);
      expect(retractedTeachingGuestPayload['deletedAt'], isNotNull);
    });

    test('le retrait part **entier**, contrairement à une rétractation', () {
      // La nuance compte. Une rétractation d'enseignement est réduite à
      // `{ id, deletedAt }` parce que la ligne **n'a pas le droit d'être vue** —
      // servir son titre après l'avoir dépubliée annulerait le geste. Un crédit
      // retiré, lui, ne dit rien qu'il faille cacher : le même transformer sert
      // les deux états, et le client ne trie que sur `deletedAt`.
      expect(retractedTeachingGuestPayload.keys.toSet(), keys.toSet());
      expect(retractedTeachingPayload.keys.toSet(), {'id', 'deletedAt'});
    });

    test('un retrait réanimable : la même ligne, le même `id`', () {
      // L'unicité serveur porte sur `(teaching_id, contributor_id)` **tombstones
      // compris**, précisément pour que retirer puis remettre un invité réanime
      // cette ligne-ci (`deleted_at → NULL`). Un index partiel aurait autorisé
      // deux lignes pour la même paire, dont une morte : le client aurait reçu un
      // tombstone et une création portant des `id` différents, et l'**ordre
      // d'arrivée** aurait décidé de ce qu'il affiche.
      expect(
        retractedTeachingGuestPayload['id'],
        secondTeachingGuestPayload['id'],
      );
      expect(
        retractedTeachingGuestPayload['contributorId'],
        secondTeachingGuestPayload['contributorId'],
      );
      // Et l'`updatedAt` a bougé : c'est ce qui fait repasser la ligne dans le
      // flux. Sans ce bump, le retrait n'arriverait jamais.
      expect(
        DateTime.parse(retractedTeachingGuestPayload['updatedAt']! as String)
            .isAfter(
          DateTime.parse(secondTeachingGuestPayload['updatedAt']! as String),
        ),
        isTrue,
      );
    });

    test('ni `seriesId` ni `numero` : la série n\'entre pas par ici', () {
      // Le serveur les sert sur `teachings`, le mobile ne les lit pas, et le
      // regroupement des épisodes reste vitrine + admin. Le pivot n'en a jamais
      // porté : le vérifier ici évite qu'on les y glisse « tant qu'on y est ».
      for (final guest in _teachingGuests) {
        expect(
          guest.keys,
          isNot(anyElement(isIn(const ['seriesId', 'numero', 'episode']))),
        );
      }
    });

    test('les dates sont des instants ISO-8601 analysables', () {
      for (final guest in _teachingGuests) {
        for (final key in const ['createdAt', 'updatedAt']) {
          expect(
            DateTime.tryParse(guest[key]! as String),
            isNotNull,
            reason: '$key doit être analysé, jamais comparé comme une chaîne',
          );
        }
      }
    });
  });

  group('GET /sync/announcements — la ligne', () {
    test('treize clés : deux identifiants à joindre, aucune valeur résolue',
        () {
      for (final announcement in _announcements) {
        expect(announcement.keys.toSet(), {
          'id',
          'accountId',
          'branchId',
          'title',
          'body',
          'publishedAt',
          'expiresAt',
          'backgroundId',
          'backgroundImageUrl',
          'isPinned',
          'ownerId',
          'createdAt',
          'updatedAt',
        });
        expect(announcement['id'], isA<String>());
        expect(announcement['accountId'], isA<int>());
      }
    });

    test('ni `author`, ni `tag`, ni `backgroundColor`, ni durée d\'affichage',
        () {
      // Le cœur de la refonte. Un nom d'auteur recopié dans chaque annonce est
      // une **valeur figée** : renommer le compte ne bouscule l'`updatedAt`
      // d'aucune annonce, donc aucune ligne ne repasserait par le flux delta
      // pour corriger la copie — les téléphones garderaient l'ancien nom
      // indéfiniment et en silence. Même raisonnement pour la couleur.
      //
      // `tag` est parti pour une autre raison : le compte occupe déjà
      // l'en-tête, « COE » en auteur *et* en pastille dit deux fois la même
      // chose.
      for (final announcement in _announcements) {
        expect(
          announcement.keys,
          isNot(anyElement(isIn(const [
            'author',
            'tag',
            'backgroundColor',
            'durationMs',
            'actionLabel',
            'actionRoute',
            'audio',
            'video',
          ]))),
        );
      }
    });

    test('`expiresAt` voyage brut, et l\'annonce expirée reste dans le flux',
        () {
      // Le serveur ne retire **jamais** une annonce expirée du flux delta. Un
      // statut « valable jusqu'à ce soir » doit disparaître **à la seconde**, y
      // compris hors-ligne : un filtrage serveur le laisserait affiché jusqu'à
      // la synchronisation suivante. Le filtre appartient au client, et à lui
      // seul.
      expect(
        DateTime.tryParse(expiringAnnouncementPayload['expiresAt']! as String),
        isNotNull,
      );
      // `null` = n'expire jamais, le défaut.
      expect(fullAnnouncementPayload['expiresAt'], isNull);
    });

    test('titre, corps, fond et image sont tous facultatifs', () {
      // Un statut façon WhatsApp n'a souvent pas de titre ; sans fond servi, le
      // rendu retombe sur la teinte dérivée du hash de l'identifiant.
      expect(expiringAnnouncementPayload['title'], isNull);
      expect(expiringAnnouncementPayload['backgroundId'], isNull);
      expect(fullAnnouncementPayload['backgroundImageUrl'], isNull);
    });

    test('la rétractation porte `deletedAt`', () {
      expect(retractedAnnouncementPayload['deletedAt'], isNotNull);
      expect(
        DateTime.tryParse(retractedAnnouncementPayload['deletedAt']! as String),
        isNotNull,
      );
    });

    test('les deux natures voyagent dans le même tableau', () {
      final items = (mixedAnnouncementsPage()['items']! as List)
          .cast<Map<String, Object?>>();

      expect(items.where((i) => i['deletedAt'] != null), hasLength(1));
      expect(items.last['deletedAt'], isNotNull);
    });
  });

  group('GET /sync/gatherings — la ligne', () {
    test('la même charge utile qu\'un enseignement, clé pour clé', () {
      // Les deux familles passent par le **même transformer** côté serveur
      // (`teaching_family_collection.ts`). Ce test l'écrit noir sur blanc :
      // le jour où l'un des deux gagnerait un champ que l'autre n'a pas, il
      // tombe ici plutôt qu'à l'écran.
      for (final gathering in _gatherings) {
        expect(gathering.keys.toSet(), fullTeachingPayload.keys.toSet());
        expect(gathering.keys, hasLength(20));
      }
    });

    test('ni `family`, ni `deletedAt`, ni durée, ni `mimeType`', () {
      // **La famille ne voyage pas**, et ce n'est pas un oubli : la clé de
      // collection est le discriminant, et servir un champ dont le filtre
      // garantit qu'il vaut toujours la même valeur serait une constante
      // déguisée en donnée.
      for (final gathering in _gatherings) {
        expect(
          gathering.keys,
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

    test('la rubrique se nomme `teachingTypeId` — la verrue, assumée', () {
      // Le nom de la colonne FK de la table partagée côté serveur. La renommer
      // aurait cassé les consommateurs de `teachings`, qui la lisent déjà ; et
      // l'identifiant se joint bien sur `gathering_types`.
      for (final gathering in _gatherings) {
        expect(gathering.containsKey('teachingTypeId'), isTrue);
        expect(gathering.containsKey('gatheringTypeId'), isFalse);
        expect(gathering['teachingTypeId'], isA<int>());
      }
    });

    test('`recordedAt` est un jour, `color` et `branchId` peuvent être nuls',
        () {
      for (final gathering in _gatherings) {
        expect(
          gathering['recordedAt'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        );
      }
      expect(gatheringWithoutColorPayload['color'], isNull);
      expect(gatheringWithoutColorPayload['branchId'], isNull);
      expect(gatheringWithoutColorPayload['playlistUrl'], isNull);
    });

    test('la rétractation a exactement deux clés, comme celle de teachings',
        () {
      expect(retractedGatheringPayload.keys.toSet(), {'id', 'deletedAt'});
      expect(
        DateTime.tryParse(retractedGatheringPayload['deletedAt']! as String),
        isNotNull,
      );
    });

    test('les deux natures voyagent dans le même tableau', () {
      final items = (mixedGatheringsPage()['items']! as List)
          .cast<Map<String, Object?>>();

      expect(items.where((i) => i.length == 2), hasLength(1));
      expect(items.where((i) => i.length == 20), hasLength(2));
      expect(items.last.keys.toSet(), {'id', 'deletedAt'});
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
      expect(items.where((i) => i.length == 20), hasLength(3));
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

    test('gathering_types : la même forme que teaching_types', () {
      // Le même transformer côté serveur : les deux référentiels ne diffèrent
      // **que** par le canal. Vérifié clé à clé plutôt que de bonne foi — si
      // l'un des deux gagnait un champ, ce test le dirait.
      for (final type in _gatheringTypes) {
        expect(type.keys.toSet(), heroTeachingTypePayload.keys.toSet());
        final label = type['label']! as Map<String, Object?>;
        expect(label.keys.toSet(), {'fr', 'en', 'ee'});
        expect(type['id'], isA<int>());
        expect(type['layout'], isIn(kTeachingTypeLayouts));
      }
      // Et la couleur d'une rubrique peut être nulle, comme partout.
      expect(listGatheringTypePayload['color'], isNull);
    });

    test(
      'status_backgrounds : les trois arrêts et l\'encre, dérivés à l\'écriture',
      () {
        // C'est le contrat central de l'habillage des statuts (ADR-0030) : le
        // serveur **a déjà** dérivé la variation et tranché le contraste. Un
        // client qui recalculerait un dégradé à partir de `baseColor` rendrait
        // deux fonds différents pour la même annonce selon la version
        // installée ; un client qui déduirait l'encre de la luminance
        // laisserait un or pâle sous un texte blanc.
        for (final background in _statusBackgrounds) {
          expect(background.keys.toSet(), {
            'id',
            'label',
            'baseColor',
            'topColor',
            'bottomColor',
            'ink',
            'position',
            'isActive',
            'createdAt',
            'updatedAt',
          });
          expect(background['id'], isA<int>());
          expect(background['ink'], isIn(const ['light', 'dark']));
          for (final key in ['baseColor', 'topColor', 'bottomColor']) {
            expect(background[key], matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
          }
        }
        // Un fond retiré du catalogue voyage quand même : c'est le drapeau qui
        // l'apprend au client, et les annonces qui le portent gardent leur
        // habillage.
        expect(retiredStatusBackgroundPayload['isActive'], isFalse);
      },
    );

    test('legal_documents : huit clés, aucune de plus', () {
      // Le contrat du transformer serveur, écrit noir sur blanc. Deux absences
      // comptent plus que les huit présences — voir le test suivant.
      for (final document in _legalDocuments) {
        expect(document.keys.toSet(), {
          'id',
          'kind',
          'version',
          'lastMandatoryVersion',
          'sections',
          'publishedAt',
          'createdAt',
          'updatedAt',
        });
        expect(document['id'], isA<int>());
        expect(document['kind'], isIn(const ['cgu', 'privacy', 'about']));
      }
    });

    test('legal_documents : ni `publishedBy`, ni `requiresReacceptance`', () {
      // Le second est le piège qu'ADR-0037 a écarté : il dit si *cette
      // édition-ci* a exigé une ré-acceptation, ce qui ne répond pas à la
      // question posée. Un fidèle resté en v2 pendant que passaient 3 (typo),
      // 4 (substantielle) et 5 (typo) doit être arrêté, alors même que la
      // courante n'exige rien. Le servir inviterait à recoder la règle côté
      // mobile, et à la recoder faux.
      for (final document in _legalDocuments) {
        expect(
          document.keys,
          isNot(anyElement(
            isIn(const ['publishedBy', 'requiresReacceptance']),
          )),
        );
      }
    });

    test('legal_documents : les sections voyagent brutes, dans l\'ordre', () {
      // Le serveur n'ose pas choisir la langue à la place du client (ADR-0023),
      // et le client ne replie pas champ par champ (ADR-0035) : il faut donc
      // que les cartes arrivent entières.
      for (final document in _legalDocuments) {
        final sections = document['sections']! as List;
        expect(sections, isNotEmpty);
        for (final section in sections.cast<Map<String, Object?>>()) {
          expect(section.keys.toSet(), {'key', 'heading', 'body'});
          expect(section['heading'], isA<Map<String, Object?>>());
          expect((section['heading']! as Map).keys, contains('fr'));
          expect((section['body']! as Map).keys, contains('fr'));
        }
      }
    });

    test('legal_documents : `about` n\'exige aucune acceptation', () {
      // `lastMandatoryVersion` nul = pas de barrière. Accepter une présentation
      // n'a pas de sens, et le genre n'entre jamais dans le calcul.
      expect(aboutDocumentPayload['lastMandatoryVersion'], isNull);
      expect(termsDocumentPayload['lastMandatoryVersion'], isA<int>());
    });

    test('legal_documents : aucune rétractation ne voyage', () {
      // `tombstoneColumn: null` côté descripteur : un document ne se supprime
      // pas, il s'édite.
      for (final document in _legalDocuments) {
        expect(document.keys, isNot(contains('deletedAt')));
      }
      final items =
          (legalDocumentsPage()['items']! as List).cast<Map<String, Object?>>();
      expect(items.where((i) => i['deletedAt'] != null), isEmpty);
    });

    test('official_accounts : le nom court et l\'avatar peuvent être nuls', () {
      for (final account in _officialAccounts) {
        expect(account.keys.toSet(), {
          'id',
          'name',
          'shortName',
          'branchId',
          'avatarUrl',
          'backgroundId',
          'isActive',
          'createdAt',
          'updatedAt',
        });
        expect(account['id'], isA<int>());
      }
      // `branchId: null` = **national**, pas « inconnu » ; `shortName: null` =
      // l'en-tête retombe sur le nom complet.
      expect(minimalOfficialAccountPayload['shortName'], isNull);
      expect(minimalOfficialAccountPayload['branchId'], isNull);
      expect(minimalOfficialAccountPayload['avatarUrl'], isNull);
      // L'URL d'avatar est **relative** : l'hôte change d'un environnement à
      // l'autre, la résolution appartient au client.
      expect(officialAccountPayload['avatarUrl'], startsWith('/uploads/'));
    });

    test('official_account_memberships : cinq clés, scoppée sur l\'acteur', () {
      expect(membershipPayload.keys.toSet(), {
        'id',
        'accountId',
        'userId',
        'createdAt',
        'updatedAt',
      });
      // Le serveur n'y sert jamais l'appartenance de quelqu'un d'autre : une
      // ligne suffit à décider de l'affordance d'écriture, et il n'y a personne
      // à écarter côté client.
      expect(membershipPayload['accountId'], isA<int>());
      expect(membershipPayload['userId'], isA<String>());
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

/// Les crédits d'invité, **retrait compris** : le tombstone porte les mêmes sept
/// clés qu'une ligne vivante, et doit donc passer les mêmes assertions.
const List<Map<String, Object?>> _teachingGuests = [
  teachingGuestPayload,
  secondTeachingGuestPayload,
  otherTeachingGuestPayload,
  retractedTeachingGuestPayload,
];

const List<Map<String, Object?>> _gatherings = [
  fullGatheringPayload,
  gatheringWithoutColorPayload,
];

const List<Map<String, Object?>> _gatheringTypes = [
  heroGatheringTypePayload,
  listGatheringTypePayload,
];

const List<Map<String, Object?>> _announcements = [
  fullAnnouncementPayload,
  expiringAnnouncementPayload,
];

const List<Map<String, Object?>> _statusBackgrounds = [
  brandStatusBackgroundPayload,
  lightStatusBackgroundPayload,
  retiredStatusBackgroundPayload,
];

const List<Map<String, Object?>> _officialAccounts = [
  officialAccountPayload,
  minimalOfficialAccountPayload,
];

const List<Map<String, Object?>> _legalDocuments = [
  termsDocumentPayload,
  privacyDocumentPayload,
  aboutDocumentPayload,
];

List<Map<String, Object?>> _collections(Map<String, Object?> manifest) =>
    (manifest['collections']! as List).cast<Map<String, Object?>>();
