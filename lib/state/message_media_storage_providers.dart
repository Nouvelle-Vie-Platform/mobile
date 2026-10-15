/// **Les providers de l'écran « Stockage »** (T4, #226).
///
/// Un fichier à part — même raison que `chat_media_providers.dart` : les
/// tranches des médias de la messagerie avancent en parallèle et n'écrivent pas
/// dans le même fichier.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/messaging/media/message_media_usage.dart';
import 'sync_providers.dart';

/// Le peseur / videur du magasin. Remplacé par le test d'écran, dont la zone
/// d'`async` ne fait aboutir ni isolat ni entrée-sortie réelle.
final messageMediaStorageProvider = Provider<MessageMediaStorage>(
  (ref) => MessageMediaStorage(ref.watch(groupDaoProvider)),
);

/// **Ce que la messagerie occupe**, pesé sur le disque.
///
/// Un `FutureProvider` et non un `StreamProvider` : la pesée coûte un `stat`
/// par fichier, et un flux la relancerait à chaque écriture de la
/// synchronisation — pour un écran qu'on ouvre, qu'on lit et qu'on quitte.
/// L'écran le relit à la main (`ref.invalidate`) après une purge, le seul
/// moment où le chiffre change sous les yeux de quelqu'un.
final messageMediaUsageProvider = FutureProvider<MessageMediaUsage>(
  (ref) => ref.watch(messageMediaStorageProvider).weigh(),
);
