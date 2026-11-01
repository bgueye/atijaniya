import 'package:flutter/material.dart';

/// Icône par wird (liste des wirds, carte d'action de l'accueil), choisie sur son trait distinctif plutôt qu'une icône
/// générique répétée trois fois — voir les `conditionsNote` du corpus validé
/// (`wirds_content.dart`) : Lazim se distingue par son rythme matin/soir,
/// Wazifa par sa forme de récitation (idéalement en assemblée), Hadratou-
/// l-Jouma par son caractère collectif et hebdomadaire (vendredi).
IconData iconForWird(String id) {
  return switch (id) {
    'lazim' => Icons.wb_twilight,
    'wazifa' => Icons.auto_stories,
    'hadratou_jouma' => Icons.groups,
    _ => Icons.self_improvement,
  };
}

