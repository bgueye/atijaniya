// Page entière qui remplace un contenu absent ou qui conclut un parcours :
// une icône, un titre, un texte, et au besoin l'action qui règle la situation
// (« Renseignez d'abord votre lignée » → « Renseigner ma lignée », « Merci
// pour votre don » → « Retour »).
//
// Sortie le 2026-11-04 (mise au thème du kit des écrans sans maquette) de
// trois copies presque identiques — condisciples, don, « Comprendre la
// Zawiya » — qui avaient toutes une icône bronze dans un rond or doux et un
// texte en bronze, sous le seuil AA. Construite avec les jetons du kit :
// icône `emerald` dans une puce `emerald_soft` (kit § Iconographie), titre de
// section (Cormorant, Amiri en arabe) annoncé comme titre, texte en encre.
//
// Pour un simple message dans le corps d'un écran (liste vide, erreur), le
// kit a `Notice` / `NoticeBody` : cette page-ci est pour les cas où il y a un
// titre et, souvent, une action.

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'content_text.dart';
import 'section_title.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Bouton qui règle la situation (`OutlinedButton` en général : l'action
  /// principale de l'écran, s'il y en a une, reste ailleurs).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Liste et non `Center` : le contenu reste lisible à 200 % sans
    // débordement, et défile si besoin.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.emeraldSoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.emerald, size: 28),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: ContentText(title, style: SectionTitle.styleFor(context), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        ContentText(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink, height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 24),
          Center(child: action),
        ],
      ],
    );
  }
}
