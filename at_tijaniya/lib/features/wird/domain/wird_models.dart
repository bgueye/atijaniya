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
    this.closingFormulas,
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

  /// Précision complémentaire éventuelle, en français uniquement (ex. la
  /// mise en garde "propre à la Tariqa Tijaniyya" de Salatoul Fatihi) — ne
  /// doit jamais contenir de texte arabe : voir [closingFormulas] pour ça.
  final String? note;

  /// Formule(s) arabe(s) à ajouter après les répétitions de ce pilier (ex.
  /// le verset de clôture de la Sourate As-Saffat) — toujours affichées
  /// dans leur propre bloc (arabe en police Amiri + translittération),
  /// jamais fondues dans la même phrase que [note] : mélanger arabe et
  /// français dans une seule chaîne empêchait une mise en forme correcte
  /// (RTL, police) du texte arabe (retour du porteur de projet, 2026-08-17).
  final List<WirdClosingFormula>? closingFormulas;

  /// Texte intégral, paragraphe par paragraphe, pour les piliers longs
  /// (ex. Jawharatoul Kamal) où [arabic]/[transliteration]/[translation]
  /// ne contiennent que le nom du pilier.
  final List<WirdParagraph>? fullText;

  /// Conditions de validité spécifiques à ce seul pilier (ex. conditions
  /// strictes de Jawharatoul Kamal), affichées comme un avertissement.
  final List<String>? conditions;
}

/// Une formule arabe complémentaire ajoutée après les répétitions d'un
/// pilier (ex. verset de clôture) — voir [WirdPillar.closingFormulas].
class WirdClosingFormula {
  const WirdClosingFormula({required this.intro, required this.arabic, this.transliteration});

  /// Phrase française d'introduction (ex. "Clôture après la 100ᵉ
  /// récitation (Sourate As-Saffat, 37:180-182) :").
  final String intro;

  final String arabic;

  /// `null` quand le document source ne fournit pas de translittération
  /// pour cette formule précise (ex. le rappel du nom du Prophète après
  /// La ilaha illAllah, dans la Wazifa) — jamais complétée par le modèle,
  /// même quand la même formule est translittérée ailleurs dans ce fichier
  /// pour un autre wird (règle "contenu religieux", CLAUDE.md).
  final String? transliteration;
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


enum WirdFrequency { daily, weekly }

class Wird {
  const Wird({
    required this.id,
    required this.nameArabic,
    required this.nameFrench,
    required this.frequency,
    required this.pillars,
    this.repetitionsNote,
    this.conditionsNote,
  });

  final String id;
  final String nameArabic;
  final String nameFrench;
  final WirdFrequency frequency;

  /// Piliers obligatoires, dans l'ordre impératif de récitation — inclut
  /// désormais l'intention d'ouverture et la Fatiha comme piliers à part
  /// entière (forme complète), les versets de clôture restant fondus dans
  /// le champ [WirdPillar.note] du pilier qu'ils suivent.
  final List<WirdPillar> pillars;

  /// Précision sur un nombre de répétitions variable selon le foyer.
  final String? repetitionsNote;

  /// Conditions de validité additionnelles propres à ce wird.
  final String? conditionsNote;
}
