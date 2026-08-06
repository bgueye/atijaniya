/// Modèle de la lignée spirituelle du disciple — table Supabase
/// `lineage_declarations`. Priorité P1 (docs/03-architecture-ecrans.md,
/// "Renseigner ma lignée spirituelle").
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1) : donnée personnelle
/// strictement privée. La policy RLS déployée (`lineage_owner_only`,
/// `for all using (auth.uid() = user_id)`) n'autorise aucune lecture
/// inter-utilisateurs — ce modèle et son repository ne doivent donc jamais
/// exposer de requête cross-utilisateur (ex. suggestions de noms saisis par
/// d'autres disciples : nécessiterait une fonction Postgres dédiée,
/// inexistante dans le schéma actuel).
///
/// `moqaddam_name_normalized` est volontairement absent de ce modèle :
/// maintenu par trigger serveur (`normalize_moqaddam_name`), jamais lu ni
/// écrit depuis le client (CLAUDE.md).
library;

enum Foyer { tivaouane, kaolack, medinaBaye, autre }

Foyer foyerFromString(String value) {
  return switch (value) {
    'tivaouane' => Foyer.tivaouane,
    'kaolack' => Foyer.kaolack,
    'medina_baye' => Foyer.medinaBaye,
    _ => Foyer.autre,
  };
}

String foyerToDbValue(Foyer foyer) {
  return switch (foyer) {
    Foyer.tivaouane => 'tivaouane',
    Foyer.kaolack => 'kaolack',
    Foyer.medinaBaye => 'medina_baye',
    Foyer.autre => 'autre',
  };
}

class LineageDeclaration {
  const LineageDeclaration({
    required this.foyer,
    this.foyerAutreText,
    required this.moqaddamNameText,
    this.transmissionYear,
    this.zawiyaText,
  });

  final Foyer foyer;
  final String? foyerAutreText;
  final String moqaddamNameText;
  final int? transmissionYear;
  final String? zawiyaText;

  factory LineageDeclaration.fromRow(Map<String, dynamic> row) {
    return LineageDeclaration(
      foyer: foyerFromString(row['foyer'] as String),
      foyerAutreText: row['foyer_autre_text'] as String?,
      moqaddamNameText: row['moqaddam_name_text'] as String,
      transmissionYear: row['transmission_year'] as int?,
      zawiyaText: row['zawiya_text'] as String?,
    );
  }
}
