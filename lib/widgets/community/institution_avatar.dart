import 'package:flutter/material.dart';

import '../app_avatar.dart';

/// Avatar d'une **institution** : son logo (URL déjà résolue) si présent, sinon
/// les initiales du nom via [AppAvatar].
///
/// L'image réseau porte **toujours** un `errorBuilder` (repli sur les
/// initiales) : jamais d'échec réseau visible hors ligne ou en test.
class InstitutionAvatar extends StatelessWidget {
  const InstitutionAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 44,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null) return AppAvatar(name: name, size: size);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => AppAvatar(name: name, size: size),
        ),
      ),
    );
  }
}
