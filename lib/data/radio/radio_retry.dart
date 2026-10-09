/// **La reprise de l'antenne : réactive, et sans abandon** (#179, plan
/// `server-portal/docs/radio-adaptative-plan.md`, décisions 2, 8 et 9).
///
/// Nos auditeurs écoutent sur des réseaux instables, souvent en 2G/EDGE : la
/// coupure y est ordinaire, et l'auditeur ne doit rien avoir à faire pour
/// qu'elle se répare. Toutes les durées de la reprise sont écrites ici, une
/// seule fois :
///
/// | moment | ce qui se passe |
/// | --- | --- |
/// | tampon ≥ [kRadioUnstableAfter] après le premier son | « Connexion instable… » |
/// | tampon ≥ [kRadioStallRelaunchAfter] | relance immédiate, « Reconnexion… » |
/// | une tentative sans son au bout de [kRadioAttemptTimeout] | elle compte comme un échec |
/// | après un échec | tentative suivante à 1, 2, 4 s, puis toutes les [kRadioRetryInterval] |
///
/// **Aucune borne de fin** : seul l'arrêt de l'auditeur (le bouton, la ✕ du
/// mini-lecteur, la notification balayée) arrête la radio. L'ancienne règle
/// « six attentes, deux minutes, puis extinction » éteignait l'écoute sur une
/// coupure de trois minutes — c'est-à-dire là où la radio sert le plus.
///
/// **Toute relance repart du bord du direct** : nouvelle lecture de
/// `GET /radio/antenna`, nouveau pré-vol, nouvelle ouverture sans position.
/// Jamais `resume()` à l'ancienne position, jamais l'ancien cookie : la fenêtre
/// de l'antenne ne porte que quarante secondes, et une session MediaMTX expire.
///
/// ## Le réseau : un accélérateur, jamais un frein
///
/// `connectivity_plus` est **écouté** pendant un état instable ou une
/// reconnexion : un retour ou un changement de réseau déclenche un essai
/// immédiat et réarme la séquence (1, 2, 4, 5 s…). Il **ne suspend jamais** un
/// essai, et c'est toute la réserve qui reste de l'ancienne doctrine : ce
/// paquet ment dans le sens « pas de réseau » comme dans le sens « connecté »
/// (portail captif), donc « pas de réseau » n'est jamais lu. Un signal manqué
/// ne coûte que l'attente de la prochaine tentative.
library;

/// **Le tampon toléré avant de dire « Connexion instable… ».**
///
/// En deçà, un hoquet que l'auditeur n'entend presque pas : l'annoncer ferait
/// clignoter l'état à chaque changement de cellule.
const Duration kRadioUnstableAfter = Duration(seconds: 2);

/// **Le tampon au bout duquel on relance** au bord du direct.
///
/// Assez long pour laisser à l'ABR le temps de descendre sur le palier bas
/// avant de brutaliser ; assez court pour que l'auditeur n'ait pas rangé son
/// téléphone. Android **et** iOS : sur iOS, un décrochage ne remonte aucune
/// erreur, et c'est ce seuil qui le répare.
const Duration kRadioStallRelaunchAfter = Duration(seconds: 8);

/// **Le temps laissé à une tentative pour sortir un premier son.**
///
/// Compté depuis le début du démarrage — route d'antenne, pré-vol et ouverture
/// compris —, parce qu'une ouverture HLS peut rester pendue sans jamais lever
/// d'erreur (iOS) : sans cette borne, une tentative pendue resterait « en vol »
/// pour toujours, et plus rien ne partirait. Plus large que
/// [kRadioStallRelaunchAfter] : une ouverture à froid sur EDGE doit charger la
/// playlist et plusieurs segments avant de jouer — 7 à 9 s estimées, d'où
/// 3 à 5 s de marge. Ramenée de 20 à **12 s** le 09/10/2026 (décision
/// utilisateur) : sur émulateur, un essai parti au retour du réseau, avant
/// qu'il ne marche vraiment, restait pendu jusqu'à la borne — 27 s de silence
/// dans le pire cas mesuré. **Valeur à confirmer sur le terrain.**
const Duration kRadioAttemptTimeout = Duration(seconds: 12);

/// Les premières attentes après un échec, **comptées depuis cet échec**.
const List<Duration> kRadioRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

/// L'attente entre deux tentatives une fois [kRadioRetryDelays] consommées —
/// **sans fin**.
const Duration kRadioRetryInterval = Duration(seconds: 5);

/// L'attente avant la tentative n° [attempt] (0 pour la première après un
/// échec) : 1, 2, 4 s, puis 5 s indéfiniment.
Duration radioRetryDelay(int attempt) => attempt < kRadioRetryDelays.length
    ? kRadioRetryDelays[attempt]
    : kRadioRetryInterval;
