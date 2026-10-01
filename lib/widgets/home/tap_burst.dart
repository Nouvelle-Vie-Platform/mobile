/// **Le premier double-appui de l'application** — et la raison pour laquelle il
/// ne s'écrit pas avec `GestureDetector.onDoubleTap`.
///
/// ⚠️ `onDoubleTap` **impose un délai au simple appui**. Le détecteur de Flutter
/// doit attendre `kDoubleTapTimeout` avant de pouvoir dire qu'il n'y aura pas de
/// second contact : tant que l'attente court, `onTap` ne part pas. Le bouton
/// d'antenne ne peut pas payer ce prix — « le flux part au premier contact » est
/// la première exigence du cadrage, et trois cents millisecondes d'attente avant
/// qu'il se passe quoi que ce soit se sentent à l'usage.
///
/// On renverse donc la logique : **chaque appui agit tout de suite**, et c'est son
/// *rang dans la rafale* qui dit lequel il est. Rien n'attend, rien n'est
/// programmé, il n'y a **aucune minuterie** — le rang se calcule après coup, en
/// comparant l'instant de cet appui à celui du précédent.
///
/// C'est ce qui permet de tenir ensemble les deux exigences que le cadrage met
/// côte à côte : « tout doit être réactif » et « le double clic navigue ».
library;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;

/// **La fenêtre d'une rafale** — celle du système, pas une valeur inventée.
///
/// `kDoubleTapTimeout` est l'écart maximal que Flutter lui-même tolère entre deux
/// contacts d'un double-appui (300 ms). La reprendre plutôt que d'en choisir une
/// fait que la paire de contacts qu'un auditeur produit « en double » est reconnue
/// ici exactement comme elle l'aurait été par le détecteur du framework — sans en
/// payer l'attente.
const Duration kTapBurstWindow = kDoubleTapTimeout;

/// Compte les appuis d'une rafale, **sans rien faire attendre**.
///
/// Un seul état : l'instant du dernier appui. Deux appuis séparés de plus de
/// [window] n'appartiennent pas à la même rafale, et le compte repart à un.
class TapBurst {
  TapBurst({this.window = kTapBurstWindow});

  /// L'écart au-delà duquel un appui ouvre une rafale neuve.
  final Duration window;

  DateTime? _last;
  int _rank = 0;

  /// Enregistre un appui survenu à [now] et rend son **rang** : 1 pour le
  /// premier, 2 pour le second, et ainsi de suite.
  ///
  /// L'horloge est **passée en paramètre** et non lue ici : la seule chose que ce
  /// compteur a à dire dépend du temps, et un appel à `DateTime.now()` enfoui
  /// dedans le rendrait intestable autrement qu'en attendant pour de vrai. Les
  /// appelants lisent `nowProvider`, l'horloge injectable du dépôt.
  int register(DateTime now) {
    final last = _last;
    final sameBurst = last != null && now.difference(last) <= window;
    _rank = sameBurst ? _rank + 1 : 1;
    _last = now;
    return _rank;
  }
}
