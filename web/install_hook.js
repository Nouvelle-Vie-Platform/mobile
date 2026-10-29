// L'installation, captée AVANT Flutter — et dans un fichier, pas en ligne.
//
// Chrome émet `beforeinstallprompt` pendant le chargement de la page, souvent
// avant que `main()` ne s'exécute, et **l'événement ne se rejoue jamais**. Un
// écouteur posé depuis Dart le raterait sur un téléphone lent, c'est-à-dire
// précisément sur le parc que l'app web existe pour servir.
//
// `preventDefault()` empêche l'invite spontanée du navigateur : on la garde
// pour notre propre bandeau, qui dit POURQUOI installer — sans installation,
// pas de téléchargement hors ligne et pas de stockage durable.
//
// ⚠️ **Ce code était en ligne dans `index.html`, et la CSP de l'origine l'a
// refusé en production** (`script-src 'self' 'wasm-unsafe-eval'`, posée par
// T0) : « Executing inline script violates… The action has been blocked. »
// Le bandeau d'installation ne pouvait donc jamais paraître. Un fichier servi
// depuis notre origine satisfait `'self'` sans relâcher quoi que ce soit —
// l'autre voie, un hash `sha256-…` dans la CSP, aurait lié un en-tête du dépôt
// `context` à un octet de ce dépôt-ci, à refaire à chaque virgule changée.
//
// Chargé **sans `defer`** : le fichier fait quelques lignes, et l'écouteur doit
// exister le plus tôt possible — c'est toute sa raison d'être.
//
// Rien de plus ici : la décision d'afficher appartient à Dart
// (`lib/data/install/browser_install_prompt.dart`), qui lit `nvInstall.event`.
window.nvInstall = { event: null };

window.addEventListener('beforeinstallprompt', function (e) {
  e.preventDefault();
  window.nvInstall.event = e;
  window.dispatchEvent(new Event('nv-install-available'));
});

window.addEventListener('appinstalled', function () {
  window.nvInstall.event = null;
  window.dispatchEvent(new Event('nv-install-available'));
});
