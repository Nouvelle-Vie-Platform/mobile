# Traductions (i18n)

Les chaînes d'interface sont externalisées ici au format ARB et compilées par
`flutter gen-l10n` (config : [`l10n.yaml`](../../l10n.yaml)).

| Fichier | Langue | Statut |
|---|---|---|
| `app_fr.arb` | Français | ✅ Langue **modèle** — toutes les clés y sont définies |
| `app_en.arb` | Anglais | ✅ Traduit |
| `app_ee.arb` | Éwé (`ee`) | ⚠️ **Partiel — à relire par un locuteur natif** |

## Note sur l'éwé

`app_ee.arb` ne contient que des traductions partielles, faites au mieux. Les
clés absentes se **rabattent automatiquement sur le français** (comportement de
`gen-l10n`). Le vocabulaire religieux en particulier doit être validé par un
locuteur natif avant toute mise en production.

## Ajouter / modifier une chaîne

1. Ajouter la clé dans `app_fr.arb` (avec `@clé` pour la description / les
   placeholders si besoin).
2. La traduire dans `app_en.arb` (et `app_ee.arb` si possible).
3. `flutter gen-l10n` (ou un simple build) régénère `AppLocalizations`.
4. L'utiliser via `context.l10n.maCle` (voir `lib/l10n/l10n_extension.dart`).

## Contenu volontairement NON traduit

Les données métier (titres d'enseignements, noms, montants, dates des
`SampleData`) ne sont pas dans les ARB : elles proviendront du backend.
