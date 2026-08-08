/// Modèles du module Conditions de la Tariqa (chouroutes).
///
/// IMPORTANT (CLAUDE.md — contenu religieux ; docs/01-perimetre-fonctionnel.md
/// § 8) : contenu provenant de la table Supabase `tariqa_conditions`,
/// alimentée et validée par le porteur de projet directement en base (même
/// principe que le module Figures — voir `figure_models.dart`). La RLS
/// (`tariqa_conditions_public_read`) ne renvoie au client que les lignes
/// `content_status = 'valide'`. Aucune condition ne doit être inventée,
/// reformulée ou complétée par le modèle — seul un enregistrement marqué
/// `valide` en base fait foi.
library;

/// Les 5 catégories officielles de tidjaniya.com/ar (شروط صحة التلقين، شروط
/// الصحبة، الشروط العامة، شروط صحة الأوراد، الشروط المكملة) — voir
/// `database/schema.sql`, contrainte `check` sur `tariqa_conditions.category`.
enum TariqaConditionCategory {
  validiteTalqin,
  compagnonnage,
  conditionsGenerales,
  validiteRecitation,
  conditionsComplementaires,
}

TariqaConditionCategory _categoryFromDb(String value) {
  return TariqaConditionCategory.values.firstWhere(
    (c) => c.name == _camelCase(value),
    orElse: () => TariqaConditionCategory.conditionsGenerales,
  );
}

String _camelCase(String snakeCase) {
  final parts = snakeCase.split('_');
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

class TariqaCondition {
  const TariqaCondition({
    required this.orderIndex,
    required this.category,
    required this.textFr,
    this.textAr,
    this.sourceNote,
  });

  final int orderIndex;
  final TariqaConditionCategory category;
  final String textFr;
  final String? textAr;
  final String? sourceNote;

  factory TariqaCondition.fromRow(Map<String, dynamic> row) {
    return TariqaCondition(
      orderIndex: row['order_index'] as int,
      category: _categoryFromDb(row['category'] as String),
      textFr: row['text_fr'] as String,
      textAr: row['text_ar'] as String?,
      sourceNote: row['source_note'] as String?,
    );
  }
}
