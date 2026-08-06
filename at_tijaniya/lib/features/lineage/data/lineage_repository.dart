/// Accès aux données de la lignée spirituelle (Supabase — table
/// `lineage_declarations`). Policy RLS `lineage_owner_only` : `for all
/// using (auth.uid() = user_id)` — chaque disciple ne voit et ne modifie
/// jamais que sa propre ligne, RLS l'impose déjà côté base. Une seule ligne
/// par utilisateur (clé primaire `user_id`), d'où l'usage d'`upsert` plutôt
/// que insert/update séparés.
///
/// `moqaddam_name_normalized` n'apparaît jamais dans les payloads envoyés
/// ici : c'est maintenu par le trigger serveur `normalize_moqaddam_name`
/// (CLAUDE.md).
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/lineage_models.dart';

class LineageRepository {
  const LineageRepository();

  /// `null` si le disciple n'a pas encore renseigné sa lignée.
  Future<LineageDeclaration?> fetchMyLineage() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    final row = await SupabaseConfig.client
        .from('lineage_declarations')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : LineageDeclaration.fromRow(row);
  }

  Future<void> saveMyLineage({
    required Foyer foyer,
    String? foyerAutreText,
    required String moqaddamNameText,
    int? transmissionYear,
    String? zawiyaText,
  }) async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('lineage_declarations').upsert({
      'user_id': userId,
      'foyer': foyerToDbValue(foyer),
      'foyer_autre_text': foyerAutreText,
      'moqaddam_name_text': moqaddamNameText,
      'transmission_year': transmissionYear,
      'zawiya_text': zawiyaText,
    });
  }

  Future<void> deleteMyLineage() async {
    final userId = SupabaseConfig.client.auth.currentUser!.id;
    await SupabaseConfig.client.from('lineage_declarations').delete().eq('user_id', userId);
  }
}
