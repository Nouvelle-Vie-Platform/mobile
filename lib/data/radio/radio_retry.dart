/// **La reprise insiste en espaçant, et abandonne à deux minutes.**
///
/// Deux bornes, écrites ici une seule fois, et elles ne disent pas la même
/// chose — c'est tout l'intérêt d'en avoir deux :
///
/// - [kRadioRetryDelays] borne **l'insistance** : six tentatives, dont l'attente
///   double, pour ne pas marteler un réseau déjà à genoux ;
/// - [kRadioRetryDeadline] borne **le temps** : au bout de deux minutes, le bouton
///   s'éteint et dit pourquoi.
///
/// Les deux sont nécessaires parce qu'une tentative **prend du temps à échouer**.
/// Les six attentes ne font que 63 secondes cumulées ; une ouverture HLS qui part
/// dans le vide met dix à trente secondes à renoncer, et six de ces ouvertures
/// plus leurs attentes tombent très exactement autour de deux minutes. Celle des
/// deux bornes qui mord dépend donc du réseau, et c'est bien ainsi : sur une
/// coupure franche, ce sont les six tentatives ; sur un réseau qui fait attendre,
/// c'est l'horloge.
///
/// ⚠️ **Rien ici ne consulte le système.** « Reprise immédiate si le réseau
/// revient » a été écrit puis retiré du cadrage : ce n'est pas tenable sans
/// déroger à la doctrine du dépôt sur `connectivity_plus` (voir
/// `radio_failure.dart`). La reprise est **purement temporelle**.
///
/// Pourquoi pas trois tentatives rapides : elles abandonneraient sur une coupure
/// de dix secondes dont l'auditeur ne s'est pas aperçu — au Togo, c'est la coupure
/// ordinaire. Pourquoi pas indéfiniment : un bouton qui tourne sans fin **ment**,
/// et vide la batterie dans un tunnel.
library;

/// Les six attentes, **comptées depuis l'échec précédent**.
///
/// Cumulées, les tentatives tombent à 1 s, 3 s, 7 s, 15 s, 31 s et 63 s après le
/// premier échec — si chacune échoue instantanément.
const List<Duration> kRadioRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 32),
];

/// **Deux minutes depuis le premier échec**, et le bouton s'éteint avec un motif.
const Duration kRadioRetryDeadline = Duration(minutes: 2);
