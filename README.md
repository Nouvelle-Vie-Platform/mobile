# Maison du Miracle 📱

Application mobile de l'**Église Évangélique Nouvelle Vie – Maison du Miracle**.
Construite avec **Flutter**, elle rassemble la vie de l'église : cultes à venir,
enseignements, médiathèque, communauté, espace de prière, dons et annonces.

> ⚠️ État actuel : **maquette fonctionnelle**. L'interface et la navigation sont
> complètes, mais les données sont fictives et l'authentification est simulée
> (voir la feuille de route en bas de page).

## ✨ Fonctionnalités

- **Accueil** — en-tête ondulé, évènements « à venir » et derniers enseignements.
- **Médiathèque** — façon « Découverte » : carrousel phare, sections, recherche.
- **Lecteur d'enseignement** — immersif, habillé par la couleur/image de chaque
  message, avec demi-feuille de détails (description, versets).
- **Communauté** — onglets Groupes · Inbox · Requêtes de prière.
- **Discussion de groupe** — messagerie (bulles, accusés de lecture, annonces).
- **Annonces** de l'église.
- **Profil** — en-tête de marque, raccourcis, réglages (dont mode sombre).
- **Multilingue** — français, anglais, éwé (partiel).
- **Thème clair/sombre** + **glassmorphisme** (fond dégradé, cartes en verre dépoli).

## 🚀 Démarrage

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) **3.44+**
(Dart 3.6+).

```bash
flutter pub get

# Lancer l'app
flutter run -d chrome     # navigateur (le plus simple)
flutter run -d <id>       # simulateur iOS / émulateur Android / appareil

# Qualité
flutter analyze
flutter test
dart format .
```

> Émulateur Android : nécessite un **JDK 17 ou 21** (le JDK 26 fait échouer le
> build Gradle). Configurer avec `flutter config --jdk-dir <chemin>`.

## 🏗️ Architecture

Architecture en couches, pensée pour brancher un vrai backend sans toucher l'UI.

| Couche | Rôle |
|---|---|
| `models/` | Modèles de données immuables |
| `data/` | `SampleData` + `ChurchRepository` (abstraction + impl. en mémoire) |
| `state/` | Providers **Riverpod** (repository, données, thème) |
| `router/` | **go_router** (`routerProvider`, routes nommées, arguments typés) |
| `theme/` | Couleurs, palette adaptative, typographie, espacements |
| `screens/` | Écrans (un par fichier) |
| `widgets/` | Composants partagés (`cards/`, `chat/`) |
| `l10n/` | Traductions (ARB + génération) |

**Gestion d'état** : [Riverpod](https://riverpod.dev) pour l'état partagé
(thème, données, routeur) ; `StatefulWidget` pour l'état local éphémère.

**Brancher un backend** : fournir une nouvelle implémentation de
`ChurchRepository` et surcharger `churchRepositoryProvider`. Aucun écran ne
change.

```text
lib/
├── main.dart            # ProviderScope + MaisonDuMiracleApp
├── app.dart             # MaterialApp.router
├── data/                # modèles via repository
├── state/               # providers Riverpod
├── router/app_router.dart
├── theme/               # design system (couleurs, palette, typo, spacing)
├── screens/             # écrans
├── widgets/             # composants réutilisables (cards/, chat/)
└── l10n/                # internationalisation
```

## 🌍 Internationalisation

Basée sur `flutter_localizations` + `gen-l10n`. Le **français** (`app_fr.arb`)
est la langue modèle ; l'anglais est complet, l'éwé partiel (repli français).

```bash
# Après toute modification d'un fichier .arb :
flutter gen-l10n
```

Dans le code : `context.l10n.maCle`.

## 🎨 Design system

- Police **Atkinson Hyperlegible** (lisibilité).
- Couleurs et dégradés de marque dans `theme/app_colors.dart`.
- Palette adaptative clair/sombre via `context.palette`.
- Composants signature : `BrandAppBar` (en-têtes), `AppCard` (verre dépoli),
  `AppBackground` (fond dégradé global), `TeachingCover`.

## ✅ Tests & CI

Tests « smoke » sous `test/` (montage des écrans, navigation, i18n). Une
**GitHub Action** (`.github/workflows/flutter-ci.yml`) vérifie le formatage,
l'analyse statique et les tests à chaque push/PR.

## 🗺️ Feuille de route

- [ ] Backend & authentification réels (derrière `ChurchRepository`)
- [ ] Dons / paiement (mobile money, carte)
- [ ] Notifications push
- [ ] Finaliser l'habillage des écrans restants (onboarding, connexion, live…)
- [ ] Couverture de tests étendue
- [ ] Icône et écran de lancement natifs

## 🤝 Contribution

- Commits **canoniques** : un par fonctionnalité, préfixes conventionnels
  (`feat`, `fix`, `chore`, `refactor`).
- `flutter analyze` à 0 problème et `flutter test` au vert avant de pousser.

---

Conventions détaillées pour le développement assisté : voir [CLAUDE.md](CLAUDE.md).
