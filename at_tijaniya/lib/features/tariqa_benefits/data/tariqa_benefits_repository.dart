/// Accès au contenu de « Bienfaits de la Tijaniyya » (Supabase — tables
/// `tariqa_benefit_sections` et `tariqa_benefit_cards`, lecture seule).
///
/// IMPORTANT (contenu religieux) : la RLS (`tariqa_benefit_*_read_valid_or_admin`)
/// ne renvoie déjà à un disciple que les lignes `content_status = 'valide'`.
/// Le filtre est répété ici côté client pour tout compte non admin, par
/// prudence — même défense en profondeur que `WirdRepairRepository` : si une
/// policy venait à être élargie par erreur, un brouillon ne serait toujours
/// pas montré à un disciple. L'admin, lui, reçoit aussi le brouillon, pour
/// relire dans l'app avant la validation par le moqaddam.
library;

import '../../../core/supabase/supabase_config.dart';

/// Lignes brutes des deux tables. Le choix entre français et arabe se fait à
/// l'affichage (`TariqaBenefitsContent.fromRows`), selon la langue de l'app.
typedef TariqaBenefitsRows = ({List<Map<String, dynamic>> sections, List<Map<String, dynamic>> cards});

class TariqaBenefitsRepository {
  const TariqaBenefitsRepository();

  Future<TariqaBenefitsRows> fetchRows({required bool includeDrafts}) async {
    final client = SupabaseConfig.client;
    // Colonnes listées plutôt qu'un `select()` nu : l'app ne reçoit que ce
    // qu'elle affiche.
    var sectionsQuery = client
        .from('tariqa_benefit_sections')
        .select('slug, order_index, number, title_fr, title_ar, intro_fr, intro_ar, content_status');
    var cardsQuery = client.from('tariqa_benefit_cards').select(
        'section_slug, order_index, group_fr, group_ar, title_fr, title_ar, blocks_fr, blocks_ar, evidence_fr, evidence_ar, content_status');
    if (!includeDrafts) {
      sectionsQuery = sectionsQuery.eq('content_status', 'valide');
      cardsQuery = cardsQuery.eq('content_status', 'valide');
    }
    // Les deux tables sont indépendantes : chargées en parallèle.
    final results = await Future.wait([
      sectionsQuery.order('order_index', ascending: true),
      cardsQuery.order('order_index', ascending: true),
    ]);
    return (sections: results[0], cards: results[1]);
  }
}
