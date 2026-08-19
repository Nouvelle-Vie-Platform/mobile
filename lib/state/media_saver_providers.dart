import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/media/gal_media_saver.dart';
import '../data/media/media_saver.dart';

/// Fournit l'enregistreur de médias. Réel ([GalMediaSaver]) en production ; les
/// tests le surchargent par un [InertMediaSaver].
final mediaSaverProvider = Provider<MediaSaver>((ref) => const GalMediaSaver());
