/// Modèles de contenu du module Wirds.
///
/// IMPORTANT (CLAUDE.md — contenu religieux) : les instances de ces modèles
/// ne doivent être construites qu'à partir du corpus validé
/// (`wirds_content.dart`, source unique). Ne jamais instancier ces classes
/// avec du texte de wird inventé ou non revu par un moqaddam.
library;

/// Un pilier obligatoire d'un wird (ex. Astaghfirullah, Salatoul Fatihi...).
class WirdPillar {
  const WirdPillar({
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.repetitions,
    this.note,
    this.fullText,
    this.conditions,
  });

  /// Texte arabe — à afficher avec la police Amiri (jamais Jost).
  final String arabic;
  final String transliteration;
  final String translation;

  /// Nombre de répétitions. Représenté en texte plutôt qu'en entier pur
  /// lorsque le nombre dépend du foyer (voir [Wird.repetitionsNote]).
  final int repetitions;

  /// Précision complémentaire éventuelle (ex. formule ajoutée après la
  /// dernière répétition).
  final String? note;

  /// Texte intégral, paragraphe par paragraphe, pour les piliers longs
  /// (ex. Jawharatoul Kamal) où [arabic]/[transliteration]/[translation]
  /// ne contiennent que le nom du pilier.
  final List<WirdParagraph>? fullText;

  /// Conditions de validité spécifiques à ce seul pilier (ex. conditions
  /// strictes de Jawharatoul Kamal), affichées comme un avertissement.
  final List<String>? conditions;
}

/// Un paragraphe d'un texte long (arabe + translittération + traduction).
class WirdParagraph {
  const WirdParagraph({
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });

  final String arabic;
  final String transliteration;
  final String translation;
}


/// Une étape du déroulé complet d'un wird (ouverture, clôture, du'a...),
/// distincte des piliers obligatoires : utile pour afficher la séquence
/// complète recommandée sans la confondre avec ce qui est strictement
/// obligatoire.
class WirdSequenceStep {
  const WirdSequenceStep({required this.label, this.repetitions});

  final String label;
  final int? repetitions;
}

enum WirdFrequency { daily, weekly }

class Wird {
  const Wird({
    required this.id,
    required this.nameArabic,
    required this.nameFrench,
    required this.frequency,
    required this.pillars,
    required this.sequence,
    this.repetitionsNote,
    this.conditionsNote,
  });

  final String id;
  final String nameArabic;
  final String nameFrench;
  final WirdFrequency frequency;

  /// Piliers obligatoires, dans l'ordre impératif de récitation.
  final List<WirdPillar> pillars;

  /// Déroulé complet recommandé (piliers + formules méritoires + du'a),
  /// donné à titre d'exemple — peut varier légèrement d'un foyer à l'autre.
  final List<WirdSequenceStep> sequence;

  /// Précision sur un nombre de répétitions variable selon le foyer.
  final String? repetitionsNote;

  /// Conditions de validité additionnelles propres à ce wird.
  final String? conditionsNote;
}
