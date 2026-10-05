// **Le contrat d'écriture des annonces**, écrit sur un adaptateur factice.
//
// Aucun de ces trois endpoints n'est déployé (issue serveur #142) : ces tests
// *sont* la spécification côté client, comme l'ont été ceux du socle de
// synchronisation avant que `/sync` n'existe.
//
// Ce qu'ils protègent tient en deux phrases. **Quatre champs ne doivent jamais
// partir** — `branchId`, `audienceId`, `isPinned`, `notify` —, et un test qui
// vérifie seulement ce qui est envoyé ne les verrait jamais apparaître. Et
// **trois modes de publication se replient sur un seul champ**, où la nuance
// entre une clé absente et une clé nulle décide si l'annonce est publiée ou
// gardée au chaud.
//
// Le corps est en `camelCase`, comme tous les corps de cette API : son
// `snake_case` ne concerne que les query strings et l'enveloppe `/sync`.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/repositories/announcement_composer.dart';
import 'package:maison_du_miracle/data/repositories/http_announcement_composer.dart';
import 'package:maison_du_miracle/models/announcement_draft.dart';

import '../helpers/fake_api.dart';

AnnouncementDraft _draft({
  int accountId = 3,
  String? title = 'Convention annuelle',
  String? body = 'Trois jours de louange.',
  int? backgroundId = 5,
  PublicationTiming timing = PublicationTiming.now,
  DateTime? publishedAt,
  DateTime? expiresAt,
  StatusImageUpload? image,
  bool hasBackgroundImage = false,
}) =>
    AnnouncementDraft(
      accountId: accountId,
      title: title,
      body: body,
      backgroundId: backgroundId,
      timing: timing,
      publishedAt: publishedAt,
      expiresAt: expiresAt,
      image: image,
      hasBackgroundImage: hasBackgroundImage,
    );

void main() {
  late FakeAdapter adapter;
  late ApiClient api;
  late HttpAnnouncementComposer composer;

  void serve(ResponseBody Function(RequestOptions options) reply) {
    adapter = FakeAdapter(reply);
    api.dio.httpClientAdapter = adapter;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = ApiClient.instance;
    composer = HttpAnnouncementComposer(client: api);
    serve((_) => jsonReply(201, null));
  });

  group('POST /announcements', () {
    test('poste le contrat en camelCase', () async {
      await composer.create(
        _draft(expiresAt: DateTime.utc(2026, 9, 1, 18)),
      );

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.path, '/announcements');
      expect(adapter.lastBody, {
        'accountId': 3,
        'title': 'Convention annuelle',
        'body': 'Trois jours de louange.',
        'backgroundId': 5,
        // Toujours en UTC sur le fil : le serveur reçoit un instant, pas
        // l'heure murale du téléphone de l'auteur.
        'expiresAt': '2026-09-01T18:00:00.000Z',
      });
    });

    test(
      'n\'envoie jamais branchId, audienceId, isPinned ni notify',
      () async {
        // Les quatre champs que le serveur refuse en 422 pour un membre de
        // compte, chacun pour une raison différente : la branche est dérivée du
        // compte, la restriction d'audience et l'épinglage sont des leviers
        // d'administration, et la notification est une prérogative éditoriale du
        // portail. Aucun n'a d'entrée dans le composeur — ce test vérifie qu'il
        // n'en pousse pas non plus par un chemin détourné.
        await composer.create(_draft());

        expect(adapter.lastBody.keys, isNot(contains('branchId')));
        expect(adapter.lastBody.keys, isNot(contains('audienceId')));
        expect(adapter.lastBody.keys, isNot(contains('isPinned')));
        expect(adapter.lastBody.keys, isNot(contains('notify')));
        // Et pas davantage sous l'ancienne convention : un serveur tolérant aux
        // deux graphies laisserait passer ce qu'on croit interdire.
        expect(adapter.lastBody.keys, isNot(contains('branch_id')));
      },
    );

    test(
      'publier maintenant **omet** publishedAt : l\'horloge est celle du serveur',
      () async {
        await composer.create(_draft());

        expect(adapter.lastBody.containsKey('publishedAt'), isFalse);
      },
    );

    test('un brouillon envoie publishedAt explicitement nul', () async {
      // La nuance « clé absente » / « clé nulle » n'est pas de la
      // sérialisation : c'est elle qui sépare « publie tout de suite » de
      // « garde ça au chaud ».
      await composer.create(_draft(timing: PublicationTiming.draft));

      expect(adapter.lastBody.containsKey('publishedAt'), isTrue);
      expect(adapter.lastBody['publishedAt'], isNull);
    });

    test('une annonce programmée envoie l\'instant choisi, en UTC', () async {
      await composer.create(
        _draft(
          timing: PublicationTiming.scheduled,
          publishedAt: DateTime.utc(2026, 8, 30, 7, 30),
        ),
      );

      expect(adapter.lastBody['publishedAt'], '2026-08-30T07:30:00.000Z');
    });

    test('un titre et un corps vides partent à null, jamais en \'\'', () async {
      // Le rendu teste `title == null` pour décider s'il centre le bloc de
      // texte : une chaîne vide passerait pour un titre présent.
      await composer.create(_draft(title: '   ', body: ''));

      expect(adapter.lastBody['title'], isNull);
      expect(adapter.lastBody['body'], isNull);
    });

    test('une image bascule le corps en multipart', () async {
      await composer.create(
        _draft(
          image: StatusImageUpload(
            bytes: Uint8List.fromList(const [1, 2, 3]),
            filename: 'affiche.jpg',
          ),
        ),
      );

      final data = adapter.lastRequest.data;
      expect(data, isA<FormData>());
      final form = data as FormData;
      expect(
        form.fields.map((field) => field.key),
        containsAll(<String>['accountId', 'title', 'body', 'backgroundId']),
      );
      expect(form.files.single.key, kAnnouncementImageField);
      expect(form.files.single.value.filename, 'affiche.jpg');
      // Le Content-Type JSON par défaut d'`ApiClient` doit avoir été remplacé,
      // sinon le serveur lit un corps multipart comme du JSON et refuse tout.
      expect(
        adapter.lastRequest.contentType,
        contains(Headers.multipartFormDataContentType),
      );
    });

    test(
      'en multipart, la chaîne vide dit null — c\'est la règle du contrat',
      () async {
        // Ce n'est pas un contournement du multipart : le PRD §18 pose déjà la
        // règle pour `title` / `body`, et elle s'étend à `publishedAt`,
        // `expiresAt` et `backgroundId`. C'est elle qui permet aux trois modes
        // de publication de rester repliés sur le seul `publishedAt`, en JSON
        // comme en multipart — un booléen `draft` de plus ferait diverger le
        // mobile du portail.
        await composer.create(
          _draft(
            title: null,
            body: null,
            backgroundId: null,
            timing: PublicationTiming.draft,
            image: StatusImageUpload(
              bytes: Uint8List.fromList(const [1]),
              filename: 'affiche.png',
            ),
            hasBackgroundImage: true,
          ),
        );

        final fields = {
          for (final field in (adapter.lastRequest.data as FormData).fields)
            field.key: field.value,
        };
        expect(fields['title'], '');
        expect(fields['body'], '');
        expect(fields['backgroundId'], '');
        // Une chaîne vide **fait un brouillon**, comme le `null` du JSON.
        expect(fields['publishedAt'], '');
        expect(fields['expiresAt'], '');
      },
    );

    test(
      'en multipart non plus, aucun des quatre champs interdits ne passe',
      () async {
        await composer.create(
          _draft(
            image: StatusImageUpload(
              bytes: Uint8List.fromList(const [1]),
              filename: 'a.png',
            ),
          ),
        );

        final keys = (adapter.lastRequest.data as FormData)
            .fields
            .map((field) => field.key)
            .toSet();
        expect(keys, isNot(contains('branchId')));
        expect(keys, isNot(contains('audienceId')));
        expect(keys, isNot(contains('isPinned')));
        expect(keys, isNot(contains('notify')));
      },
    );
  });

  group('PUT et DELETE /announcements/:id', () {
    test('la modification vise l\'annonce par son identifiant', () async {
      serve((_) => jsonReply(200, null));

      await composer.update(id: 'a-1', draft: _draft());

      expect(adapter.lastRequest.method, 'PUT');
      expect(adapter.lastRequest.path, '/announcements/a-1');
      expect(adapter.lastBody['accountId'], 3);
    });

    test('la suppression n\'envoie aucun corps', () async {
      serve((_) => jsonReply(204, null));

      await composer.remove('a-1');

      expect(adapter.lastRequest.method, 'DELETE');
      expect(adapter.lastRequest.path, '/announcements/a-1');
      expect(adapter.lastRequest.data, isNull);
    });
  });

  group('Les refus, traduits en codes et jamais en HTTP brut', () {
    Future<AnnouncementWriteException> failure() async {
      try {
        await composer.create(_draft());
      } on AnnouncementWriteException catch (e) {
        return e;
      }
      fail('une exception était attendue');
    }

    test('403 — le membre a été retiré du bureau', () async {
      // Le chemin **normal** : l'appartenance connue du téléphone est un
      // confort d'affichage, jamais une autorisation.
      serve((_) => errorReply(403, 'E_OUTSIDE_SCOPE'));

      expect((await failure()).code, AnnouncementWriteErrorCode.forbidden);
    });

    test('422 — le contenu est refusé, et le message est exploitable',
        () async {
      serve(
        (_) => errorReply(
          422,
          'E_VALIDATION_ERROR',
          'La fin de publication doit suivre la publication.',
        ),
      );

      final error = await failure();
      expect(error.code, AnnouncementWriteErrorCode.rejected);
      expect(
          error.message, 'La fin de publication doit suivre la publication.');
    });

    test('401 — la session n\'est plus valide', () async {
      serve((_) => errorReply(401, 'E_UNAUTHORIZED'));

      expect((await failure()).code, AnnouncementWriteErrorCode.unauthorized);
    });

    test('404 — l\'annonce a disparu entre-temps', () async {
      serve((_) => errorReply(404, 'E_RESSOURCE_NOT_EXISTS'));

      expect((await failure()).code, AnnouncementWriteErrorCode.gone);
    });

    test('500 — le serveur est joignable et en panne', () async {
      serve((_) => errorReply(500, 'E_INTERNAL'));

      expect((await failure()).code, AnnouncementWriteErrorCode.server);
    });

    test('aucune réponse — hors ligne, et ça se dit', () async {
      // Le partage se fait sur **l'existence d'une réponse**, pas sur le
      // statut : « le serveur n'a rien dit » se règle en retrouvant du réseau,
      // « le serveur a dit non » jamais.
      serve((options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'réseau coupé',
          ));

      expect((await failure()).code, AnnouncementWriteErrorCode.network);
    });
  });

  group('Le composeur du mode maquette', () {
    test('refuse tout en disant qu\'il faut du réseau', () async {
      // Pas de file d'envoi, pas de brouillon local : un double qui
      // « réussirait » en mémoire mentirait sur l'existence d'un chemin
      // hors-ligne qui n'existe pas (ADR-0031).
      const offline = UnavailableAnnouncementComposer();

      await expectLater(
        offline.create(_draft()),
        throwsA(
          isA<AnnouncementWriteException>().having(
            (e) => e.code,
            'code',
            AnnouncementWriteErrorCode.network,
          ),
        ),
      );
      await expectLater(
        offline.remove('a-1'),
        throwsA(isA<AnnouncementWriteException>()),
      );
    });
  });

  group('La validité d\'un brouillon, avant tout appel réseau', () {
    final now = DateTime.utc(2026, 8, 10, 12);

    test('ni titre, ni corps, ni image : rien à publier', () {
      final draft = AnnouncementDraft(accountId: 3, title: '  ', body: null);

      expect(draft.issuesAt(now), contains(DraftIssue.nothingToPublish));
    });

    test('une affiche — image seule, sans texte — est valide', () {
      // Le cas le plus courant en pratique, pas une exception à tolérer.
      final draft = AnnouncementDraft(
        accountId: 3,
        image: StatusImageUpload(
          bytes: Uint8List.fromList(const [1]),
          filename: 'affiche.png',
        ),
      );

      expect(draft.issuesAt(now), isEmpty);
    });

    test(
      'une affiche déjà publiée reste valide quand on la rouvre sans image',
      () {
        // On ne recharge pas les octets d'une image déjà déposée : sans ce
        // rattrapage, corriger la date de fin d'une affiche la ferait refuser.
        final draft = AnnouncementDraft(accountId: 3, hasBackgroundImage: true);

        expect(draft.issuesAt(now), isEmpty);
      },
    );

    test('un statut qui n\'est qu\'un média est valide', () {
      final draft = AnnouncementDraft(accountId: 3, hasMedia: true);

      expect(draft.issuesAt(now), isEmpty);
    });

    test('une fin antérieure au début est refusée', () {
      final draft = AnnouncementDraft(
        accountId: 3,
        body: 'Collecte',
        timing: PublicationTiming.scheduled,
        publishedAt: DateTime.utc(2026, 8, 20),
        expiresAt: DateTime.utc(2026, 8, 19),
      );

      expect(
        draft.issuesAt(now),
        contains(DraftIssue.expiryBeforePublication),
      );
    });

    test('« programmer » sans date choisie est refusé', () {
      final draft = AnnouncementDraft(
        accountId: 3,
        body: 'Collecte',
        timing: PublicationTiming.scheduled,
      );

      expect(draft.issuesAt(now), contains(DraftIssue.missingSchedule));
    });

    test('un brouillon sans publication ne compare aucune date', () {
      // `expiresAt > publishedAt` n'a pas de sens quand la publication n'a
      // pas encore de date : on ne fabrique pas une comparaison contre
      // l'horloge de l'appareil.
      final draft = AnnouncementDraft(
        accountId: 3,
        body: 'Collecte',
        timing: PublicationTiming.draft,
        expiresAt: DateTime.utc(2026, 1, 1),
      );

      expect(draft.issuesAt(now), isEmpty);
    });
  });
}
