/// Charges utiles de `GET /events`, telles que le contrat serveur les décrit
/// (issue #16 ; endpoint pas encore déployé, issue serveur #80).
///
/// Partagées par les tests de modèle et ceux du repository : la même donnée
/// doit franchir les deux couches, sinon on teste deux contrats différents.
library;

/// Item **complet** : tous les champs facultatifs renseignés.
const Map<String, dynamic> fullEventPayload = {
  'id': '01920f00-0000-4000-8000-000000000001',
  'starts_at': '2026-08-03T17:30:00Z',
  'ends_at': '2026-08-03T19:00:00Z',
  'timezone': 'Africa/Lome',
  'branch_id': 3,
  'title': {'fr': 'Prière de zone', 'en': 'Zone prayer', 'ee': 'Gbedodoɖa'},
  'body': {'fr': 'Rendez-vous au portail.'},
  'place': 'Temple Central',
  'category': {
    'id': 2,
    'label': {'fr': 'Prière', 'en': 'Prayer'},
    'tone': 'culte',
  },
};

/// Item **minimal** : français seul, aucune description, aucun lieu, aucune
/// catégorie, portée nationale (`branch_id` nul).
const Map<String, dynamic> minimalEventPayload = {
  'id': '01920f00-0000-4000-8000-000000000002',
  'starts_at': '2026-08-10T18:00:00Z',
  'ends_at': null,
  'timezone': 'Africa/Lome',
  'branch_id': null,
  'title': {'fr': 'Veillée'},
  'body': null,
  'place': null,
  'category': null,
};
