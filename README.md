# Maison du Miracle — App mobile Flutter

Implémentation Flutter des maquettes de l'**Église Évangélique Nouvelle Vie –
Maison du Miracle**, fidèle au système de design fourni (couleurs, typographie
Montserrat, composants, écrans).

## Principes d'architecture

- **Thème centralisé** : toute la charte vit dans [`lib/theme/`](lib/theme/)
  (couleurs, typographie, espacements, rayons, ombres, `ThemeData`).
- **Composants réutilisables** : chaque élément du design system est un widget
  dédié dans [`lib/widgets/`](lib/widgets/) ; les écrans ne font que les
  composer.
- **Aucun `StatefulWidget`** : tout est `StatelessWidget`. L'état local
  (onglet courant, sélection de filtres/montants, switch) est porté par des
  `ValueNotifier` lus via `ValueListenableBuilder`.
- **Mode clair / sombre** : les couleurs de marque restent fixes ; les
  couleurs de surface/texte/bordure s'adaptent via un `ThemeExtension`
  ([`AppPalette`](lib/theme/app_palette.dart)), accédé par `context.palette`.
  Le basculement se fait via [`themeModeNotifier`](lib/theme/theme_controller.dart)
  (réglage dans l'onglet **Profil → Mode sombre**, suit le système par défaut).
- **Responsive** : marges fluides, contenus scrollables (`ListView` /
  `SingleChildScrollView`), `Expanded`/`Flexible` pour éviter les débordements,
  `SafeArea`, et l'onboarding bascule en défilement sur les petits écrans
  (`LayoutBuilder` + `ConstrainedBox`).

## Structure

```
lib/
├── main.dart                 # Point d'entrée + MaterialApp
├── routes.dart               # Table de routage
├── theme/                    # Charte graphique (thème dédié)
│   ├── app_colors.dart
│   ├── app_typography.dart   # Atkinson Hyperlegible (police embarquée)
│   ├── app_spacing.dart      # Espacements, rayons, ombres
│   └── app_theme.dart
├── models/models.dart        # Modèles de données immuables
├── data/sample_data.dart     # Contenu de démonstration
├── widgets/                  # Bibliothèque de composants
│   ├── app_button.dart       # Boutons (primaire/secondaire/accent/outline)
│   ├── app_text_field.dart   # Champs + barre de recherche
│   ├── app_chip.dart         # Chips, badges, LIVE, filtres
│   ├── app_card.dart         # Carte de base
│   ├── app_alert.dart        # Alertes (succès/info/attention/erreur)
│   ├── app_avatar.dart       # Avatar à initiales
│   ├── app_bottom_nav.dart   # Barre de navigation + FAB central
│   ├── segmented_tabs.dart   # Onglets segmentés
│   ├── selectable_option.dart# Radio / montant / paiement
│   ├── menu_tile.dart        # Lignes de menu + switch
│   ├── chat_bubble.dart      # Bulles de discussion
│   ├── media_thumbnail.dart  # Vignette média
│   └── cards/                # Cartes métier (événement, enseignement, …)
└── screens/                  # 16 écrans (composent les widgets ci-dessus)
    ├── splash_screen.dart        ├── groups_screen.dart
    ├── onboarding_screen.dart    ├── group_chat_screen.dart
    ├── login_screen.dart         ├── agenda_screen.dart
    ├── register_screen.dart      ├── prayer_requests_screen.dart
    ├── home_shell.dart           ├── new_request_screen.dart
    ├── home_screen.dart          ├── donations_screen.dart
    ├── media_library_screen.dart ├── profile_screen.dart
    ├── teaching_detail_screen.dart── notes_screen.dart
    └── live_screen.dart
```

## Charte (rappel)

| Rôle | Couleur |
|------|---------|
| Primaire | `#223B8C` |
| Secondaire | `#00A693` |
| Accent | `#F8D05E` |
| Neutre foncé | `#1A1A1A` |

Typographie : **Atkinson Hyperlegible** (embarquée, « highly legible
sans-serif ») — H1 32/40, H2 24/32, H3 20/28, H4 18/24, H5 16/24.
La famille fournit Regular (400) et Bold (700) ; les graisses intermédiaires
sont résolues vers la plus proche par Flutter.

## Compatibilité (portée maximale)

Versions minimales avec Flutter 3.44 :

| Plateforme | Minimum | Couverture parc |
|---|---|---|
| **Android** | **6.0 (API 23)** — `minSdk = 23` dans `android/app/build.gradle.kts` | ~98 % |
| **iOS** | **13.0** — `IPHONEOS_DEPLOYMENT_TARGET` dans le projet Xcode | ~98 % |

> Flutter 3.44 impose ces planchers (en dessous d'API 23, le build échoue ;
> iOS < 13 n'est plus supporté par le moteur). `minSdk 23` déclenche un simple
> avertissement Gradle — passer à `24` (Android 7.0) pour un build sans warning.

## Lancer le projet

```bash
flutter pub get
flutter run
```

> La police est déclarée dans `pubspec.yaml` (section `fonts`) et chargée
> depuis `assets/fonts/Atkinson_Hyperlegible/` — aucun téléchargement réseau,
> fonctionne hors-ligne.
