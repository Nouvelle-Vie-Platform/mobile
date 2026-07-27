import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/models/models.dart';

/// Charge utile telle que le serveur la renvoie (`POST /auth/verify-code`),
/// **après déballage de l'enveloppe `data`** — voir docs/auth-contract.md (v2).
const _sessionFixture = '''
{
  "token": "oat_MQ.dGVzdC10b2tlbi1vcGFxdWU",
  "isNewUser": false,
  "user": {
    "id": "6f1c8a2e-6a5f-4f2b-9c3d-7b1e0a5d2c44",
    "phone": "+22890123456",
    "email": "jean.kossi@email.com",
    "title": "brother",
    "firstName": "Jean",
    "lastName": "Kossi",
    "branchId": 3,
    "status": "affiliated",
    "avatarUrl": null,
    "profileComplete": true
  }
}
''';

/// Utilisateur tout juste créé : profil non complété, aucune branche.
const _newUserFixture = '''
{
  "id": "0f7b1d9c-1111-4a44-8f2e-3c9d0b6a7e51",
  "phone": null,
  "email": "nouveau@email.com",
  "title": null,
  "firstName": null,
  "lastName": null,
  "branchId": null,
  "status": "newcomer",
  "avatarUrl": null,
  "profileComplete": false
}
''';

/// Un élément de `GET /sync/branches`.
const _branchFixture = '''
{
  "id": 1,
  "name": "Église Mère – Lomé",
  "address": "Boulevard du 13 Janvier, Lomé",
  "isMotherChurch": true,
  "email": "contact@maisondumiracle.tg",
  "phone": "+22890000000",
  "postalBox": "BP 1234"
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('User.fromJson (contrat v2)', () {
    test('accepte la charge réelle du serveur', () {
      final session = Session.fromJson(_decode(_sessionFixture));

      expect(session.token, startsWith('oat_'));
      expect(session.isNewUser, isFalse);

      final user = session.user;
      expect(user.id, '6f1c8a2e-6a5f-4f2b-9c3d-7b1e0a5d2c44');
      expect(user.phone, '+22890123456');
      expect(user.email, 'jean.kossi@email.com');
      expect(user.title, UserTitle.brother);
      expect(user.firstName, 'Jean');
      expect(user.lastName, 'Kossi');
      // Entier, pas une chaîne : se compare directement à `Branch.id`.
      expect(user.branchId, 3);
      expect(user.status, UserStatus.affiliated);
      expect(user.avatarUrl, isNull);
      expect(user.profileComplete, isTrue);
    });

    test('accepte un utilisateur au profil vierge', () {
      final user = User.fromJson(_decode(_newUserFixture));

      expect(user.title, isNull);
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.branchId, isNull);
      expect(user.status, UserStatus.newcomer);
      expect(user.profileComplete, isFalse);
    });

    test('repli sur newcomer quand le statut est absent', () {
      final user = User.fromJson({'id': 'u_1'});

      expect(user.status, UserStatus.newcomer);
      expect(user.profileComplete, isFalse);
    });

    test('toJson produit exactement les clés du contrat', () {
      final user = User.fromJson(_decode(_sessionFixture)['user']);

      expect(user.toJson(), {
        'id': '6f1c8a2e-6a5f-4f2b-9c3d-7b1e0a5d2c44',
        'phone': '+22890123456',
        'email': 'jean.kossi@email.com',
        'title': 'brother',
        'firstName': 'Jean',
        'lastName': 'Kossi',
        'branchId': 3,
        'status': 'affiliated',
        'avatarUrl': null,
        'profileComplete': true,
      });
    });

    test('les enums portent bien les valeurs JSON du serveur', () {
      expect(IdentifierChannel.values.map((c) => c.name), ['phone', 'email']);
      expect(UserTitle.values.map((t) => t.name), ['brother', 'sister']);
      expect(UserStatus.values.map((s) => s.name), ['affiliated', 'newcomer']);
    });
  });

  group('User.displayName', () {
    const jean = User(id: 'u_1', title: UserTitle.brother, firstName: 'Jean');

    test('civilité + prénom', () {
      expect(jean.displayName('Frère'), 'Frère Jean');
    });

    test('civilité + prénom + nom', () {
      const user = User(
        id: 'u_1',
        title: UserTitle.sister,
        firstName: 'Adjo',
        lastName: 'Kossi',
      );
      expect(user.displayName('Sœur'), 'Sœur Adjo Kossi');
    });

    test('sans libellé de civilité : prénom seul', () {
      expect(jean.displayName(), 'Jean');
    });

    test('sans aucun nom : chaîne vide', () {
      expect(const User(id: 'u_1').displayName('Frère'), 'Frère');
      expect(const User(id: 'u_1').displayName(), '');
    });
  });

  group('Branch.fromJson', () {
    test('lit un élément de /sync/branches et ignore les champs à venir', () {
      final branch = Branch.fromJson(_decode(_branchFixture));

      expect(branch.id, 1);
      expect(branch.name, 'Église Mère – Lomé');
      expect(branch.address, 'Boulevard du 13 Janvier, Lomé');
      expect(branch.isMotherChurch, isTrue);
    });

    test('isMotherChurch vaut false par défaut', () {
      final branch = Branch.fromJson({'id': 2, 'name': 'Bethel – Agoè'});

      expect(branch.isMotherChurch, isFalse);
      expect(branch.address, isNull);
    });

    test('un id de branche se compare directement au branchId du user', () {
      final user = Session.fromJson(_decode(_sessionFixture)).user;
      const branch = Branch(id: 3, name: 'Béthesda – Kara');

      // Régression corrigée : `3 == "3"` était toujours faux en Dart, la
      // branche choisie n'affichait donc jamais son nom dans l'onglet Profil.
      expect(branch.id == user.branchId, isTrue);
    });
  });
}
