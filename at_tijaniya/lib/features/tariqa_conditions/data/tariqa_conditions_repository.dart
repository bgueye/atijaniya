/// Accès aux données du module Conditions de la Tariqa (Supabase — table
/// `tariqa_conditions`).
///
/// IMPORTANT (contenu religieux) : même défense en profondeur que
/// `FiguresRepository.fetchFigures` — la RLS `tariqa_conditions_public_read`
/// ne renvoie déjà que les lignes `content_status = 'valide'`, mais le
/// filtre est répété explicitement côté client par prudence, au cas où une
/// future policy admin (comme `figures_read_valid_or_admin`) laisserait
/// passer des brouillons à un compte admin.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/tariqa_condition_models.dart';

class TariqaConditionsRepository {
  const TariqaConditionsRepository();

  Future<List<TariqaCondition>> fetchConditions() async {
    final rows = await SupabaseConfig.client
        .from('tariqa_conditions')
        .select()
        .eq('content_status', 'valide')
        .order('order_index', ascending: true);
    return rows.map((row) => TariqaCondition.fromRow(row)).toList();
  }

  /// Corrige le texte d'une condition existante — réservé admin par la RLS
  /// `tariqa_conditions_admin_update` (migration
  /// add_tariqa_conditions_admin_update_policy, `database/schema.sql`).
  /// `content_status`/`order_index`/`id` jamais dans le payload : une
  /// correction de coquille ne dépublie ni ne réordonne jamais une
  /// condition, même principe que `FiguresRepository.updateFigure`. Pas de
  /// `createCondition`/`deleteCondition` : le corpus reste figé aux 23
  /// chouroutes officielles (voir le commentaire de la table).
  Future<TariqaCondition> updateCondition(
    String id, {
    required TariqaConditionCategory category,
    required String textFr,
    String? textAr,
    String? sourceNote,
  }) async {
    final row = await SupabaseConfig.client
        .from('tariqa_conditions')
        .update({
          'category': categoryToDb(category),
          'text_fr': textFr,
          'text_ar': textAr,
          'source_note': sourceNote,
        })
        .eq('id', id)
        .select()
        .single();
    return TariqaCondition.fromRow(row);
  }
}
