/// Accès au contenu de « Rattraper son wird » (Supabase — tables
/// `wird_repair_cases` et `wird_repair_notes`, lecture seule).
///
/// IMPORTANT (contenu religieux) : la RLS (`wird_repair_*_read_valid_or_admin`)
/// ne renvoie déjà à un disciple que les lignes `content_status = 'valide'`.
/// Le filtre est répété ici côté client pour tout compte non admin, par
/// prudence — même défense en profondeur que `TariqaConditionsRepository` :
/// si une policy venait à être élargie par erreur, un brouillon ne serait
/// toujours pas montré à un disciple. L'admin, lui, reçoit aussi le
/// brouillon, pour relire dans l'app avant la validation par le moqaddam.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/wird_repair_models.dart';

class WirdRepairRepository {
  const WirdRepairRepository();

  Future<WirdRepairContent> fetchContent({required bool includeDrafts}) async {
    final client = SupabaseConfig.client;
    var casesQuery = client.from('wird_repair_cases').select();
    var notesQuery = client.from('wird_repair_notes').select();
    if (!includeDrafts) {
      casesQuery = casesQuery.eq('content_status', 'valide');
      notesQuery = notesQuery.eq('content_status', 'valide');
    }
    // Les deux tables sont indépendantes : chargées en parallèle.
    final results = await Future.wait([
      casesQuery.order('order_index', ascending: true),
      notesQuery.order('order_index', ascending: true),
    ]);
    return WirdRepairContent(
      cases: results[0].map(WirdRepairCase.fromRow).toList(),
      notes: results[1].map(WirdRepairNote.fromRow).toList(),
    );
  }
}
