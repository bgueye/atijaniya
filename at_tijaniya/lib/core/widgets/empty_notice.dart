import 'package:flutter/material.dart';

import 'notice.dart';

/// Notice compacte pour un état vide sur fond clair (ivoire parchemin).
/// Introduite après l'audit design pré-publication Play Store : les états
/// vides étaient jusque-là traités différemment selon l'écran (texte brut
/// sans mise en forme sur certains, pill avec bordure sur d'autres).
///
/// Depuis le kit de composants (2026-11-02), simple raccourci vers
/// [Notice.info], qui porte le style : gardé pour ne pas retoucher les
/// écrans qui l'utilisent. Pour un nouvel écran, utiliser [Notice]
/// directement.
class EmptyNotice extends StatelessWidget {
  const EmptyNotice({super.key, required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Notice.info(text, icon: icon);
}
