# CLAUDE.md — Maison du Miracle (app mobile)

Application Flutter de l'**Église Évangélique Nouvelle Vie – Maison du Miracle**.
Ce fichier résume ce qu'il faut savoir pour travailler efficacement sur ce
dépôt. Le respecter prime sur les habitudes par défaut.

## Stack & versions
- **Flutter 3.44.2** / Dart `>=3.6.0 <4.0.0`. Material 3.
- **flutter_riverpod ^3.x** (gestion d'état), **go_router ^17.x** (navigation),
  **flutter_localizations** + `gen-l10n` (i18n). `flutter_lints ^6`.
- Aucune dépendance native/plugin → l'app tourne aussi sur **web**.

## Commandes
```bash
flutter run -d <device>      # macos | chrome | <id simulateur/emulateur>
flutter analyze              # doit rester à 0 problème
flutter test                 # tests (smoke) — doivent rester verts
flutter gen-l10n             # OBLIGATOIRE après toute édition d'un .arb
dart format lib/ test/       # formatage (CI le vérifie)
```
La CI (`.github/workflows/flutter-ci.yml`) lance format + analyze + test.

## Architecture (à respecter)
Couches claires, pensées pour brancher un backend sans toucher l'UI :

- `lib/models/` — modèles immuables (`ChurchEvent`, `Teaching`, `CommunityGroup`,
  `PrayerRequest`, `SpiritualNote`, `ChatMessage`, `Announcement`).
- `lib/data/` — `sample_data.dart` (données fictives) + `repositories/church_repository.dart`
  (`ChurchRepository` abstrait + `InMemoryChurchRepository`).
- `lib/state/` — providers Riverpod :
  - `repository_providers.dart` : `churchRepositoryProvider` + providers de données
    (`eventsProvider`, `teachingsProvider`, `groupsProvider`, `prayersProvider`,
    `notesProvider`, `announcementsProvider`, `chatProvider.family`).
  - `theme_provider.dart` : `themeModeProvider` (Notifier) + `isDarkModeActive`.
  - **Brancher un vrai backend = surcharger `churchRepositoryProvider`** avec une
    autre implémentation. Aucun écran ne change.
- `lib/router/app_router.dart` — `routerProvider` (GoRouter), noms dans `AppRoute`.
  Les écrans de détail reçoivent leur objet via `extra` (ex. `Teaching`,
  `CommunityGroup`), avec repli sur le 1er élément si accès direct.
- `lib/theme/` — `app_colors.dart` (couleurs de marque + dégradés),
  `app_palette.dart` (palette adaptative clair/sombre via `ThemeExtension`,
  accès `context.palette`), `app_typography.dart` (police **Atkinson Hyperlegible**),
  `app_spacing.dart` (`AppSpacing`, `AppRadius`, `AppShadows`), `app_theme.dart`.
- `lib/screens/` — un écran par fichier. `lib/widgets/` — composants partagés
  (`cards/`, `chat/`).
- `lib/l10n/` — voir i18n.
- `main.dart` → `ProviderScope(MaisonDuMiracleApp)` ; `app.dart` → `MaterialApp.router`.

### Navigation principale
`HomeShell` = `IndexedStack` de 4 onglets **Accueil · Annonces · Communauté ·
Profil** + `BottomAppBar` à encoche + **FAB central** (→ médiathèque, route
poussée). Le FAB n'est PAS un onglet.

### Composants réutilisables clés
- `BrandAppBar` — en-tête au dégradé bleu de marque (`gradientPrimary`), texte
  blanc. **Tous les écrans à app bar l'utilisent** (sauf accueil/médiathèque/
  lecteur qui ont un en-tête immersif propre).
- `AppCard` — carte **verre dépoli** (translucide + `BackdropFilter` + liseré).
- `AppBackground` — dégradé « glass » global, **posé par route** (les `Scaffold`
  sont transparents). Indispensable : peindre le fond par écran garde les
  transitions opaques (sinon on voit la page sortante à travers).
- `TeachingCover` — visuel d'un enseignement : image réseau **avec repli coloré**.
- `widgets/chat/` — `ChatAppBar`, `ChatBubble`, `ChatDatePill`,
  `ChatInfoBanner`, `MessageInputBar`.

## Conventions de code
- **État éphémère local** (onglet courant, champ de formulaire, lecteur) →
  `StatefulWidget` / `ConsumerStatefulWidget`. **Jamais** un `ValueNotifier`
  créé dans `build()` (bug historique corrigé), ni un provider global pour de
  l'état purement local. Riverpod = état **partagé** (thème, données, routeur).
- **Images réseau** : toujours `Image.network(..., errorBuilder: …)` avec repli
  (sinon échec hors-ligne **et** en test — `flutter test` renvoie 400 sur tout
  réseau).
- Couleurs/espacements/typo : passer par `AppColors` / `context.palette` /
  `AppSpacing` / `AppTypography`. Ne pas coder de couleurs en dur sauf habillage
  piloté par les données (ex. `Teaching.color`).
- Textes destinés à l'utilisateur : **toujours via l10n** (`context.l10n.xxx`),
  jamais en dur.

## i18n
- `gen-l10n` configuré (`l10n.yaml`). Langue **modèle = `app_fr.arb`**.
  `app_en.arb` complet ; `app_ee.arb` (éwé) **partiel** → repli français
  automatique pour les clés manquantes (délégués dans `l10n_setup.dart`).
- Workflow : éditer les `.arb` (au moins `fr`) → `flutter gen-l10n` → utiliser
  `context.l10n.maCle`. Ne pas éditer à la main les `app_localizations*.dart`
  (générés).

## Git
- **Commits canoniques** : un commit par fonctionnalité, atomique, préfixes
  conventionnels (`feat/fix/chore/refactor(scope)`), corps en français.
- **Ne PAS ajouter de trailer `Co-Authored-By`** (commits attribués à l'auteur).
- **Ne pas pousser à la place de l'utilisateur** : il fait `git push` lui-même
  (souvent `git push --force-with-lease`, la branche distante ayant divergé).

## Environnement (cette machine)
- **Android** : **OpenJDK 21** installé (`brew install openjdk@21`) et configuré
  via `flutter config --jdk-dir /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.
  Le JDK 26 (système) faisait échouer Gradle ; ne pas y revenir. Build OK.
- **Web (`flutter run -d chrome`)**, **simulateur iOS** et **émulateur Android**
  fonctionnent. Raccourcis dans le `Makefile` (`make ios` / `make android` / `make web`).
- Le premier build iOS/Android est long ; relances suivantes rapides.

## Statut
Maquette UI riche et cohérente, **données fictives** + **auth factice**.
Prochaines grandes étapes : backend + auth réels, dons/paiement, notifications,
finir d'habiller les écrans restants (onboarding, login/register, live, dons,
notes, nouvelle requête).
