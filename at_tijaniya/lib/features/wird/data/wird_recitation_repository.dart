/// Accès aux récitations audio des piliers (Supabase — `wird_recitations`,
/// docs/decision-gestion-audio-wirds.md).
///
/// Le corpus texte des wirds reste local (`wirds_content.dart`, source
/// unique — voir CLAUDE.md) : `WirdPillar` ne porte donc aucun identifiant
/// Supabase. La résolution vers `wird_recitations` se fait par position —
/// la place d'un pilier dans `Wird.pillars` (index + 1) correspond
/// exactement à `wird_steps.order_index` (vérifié sur les trois wirds au
/// moment de la préparation du plan, docs/decision-gestion-audio-wirds.md
/// §10) — jamais en faisant porter un UUID par le corpus local.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/wird_recitation.dart';

class WirdRecitationRepository {
  const WirdRecitationRepository();

  /// Récitation par défaut validée de chaque pilier de [wirdKey]
  /// (`Wird.id`), indexée par position dans `Wird.pillars`. Un pilier sans
  /// récitation validée est absent du résultat.
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async {
    final steps = await SupabaseConfig.client
        .from('wird_steps')
        .select('id, order_index, wirds!inner(key)')
        .eq('wirds.key', wirdKey)
        .order('order_index');
    final stepRows = (steps as List).cast<Map<String, dynamic>>();
    final stepIds = [for (final s in stepRows) s['id'] as String];
    if (stepIds.isEmpty) return const {};

    // content_status = 'valide' explicite en plus de la RLS
    // (wird_recitations_read_valid_or_admin) : défense en profondeur, même
    // principe que FiguresRepository — un compte admin ne doit jamais voir
    // de brouillon dans l'écran normal du disciple.
    final recitations = await SupabaseConfig.client
        .from('wird_recitations')
        .select('id, wird_step_id, audio_path, content_version, duration_seconds')
        .inFilter('wird_step_id', stepIds)
        .eq('is_default', true)
        .eq('content_status', 'valide');

    return buildRecitationsByPillarIndex(
      steps: stepRows,
      recitations: (recitations as List).cast<Map<String, dynamic>>(),
    );
  }

  /// Télécharge le fichier audio (bucket privé `wird-audio`) — passe par le
  /// client Supabase authentifié plutôt que par une URL signée
  /// intermédiaire : même résultat (accès respectant la RLS storage), sans
  /// gérer nous-mêmes l'expiration/régénération d'une URL.
  Future<List<int>> downloadAudioBytes(String audioPath) {
    return SupabaseConfig.client.storage.from('wird-audio').download(audioPath);
  }

  /// Récitations en `brouillon`, pour l'écran de review admin
  /// (`WirdRecitationsReviewScreen`). La RLS `wird_recitations_read_valid_or_admin`
  /// ne renvoie ces lignes qu'à un compte `is_admin` — un compte non-admin
  /// qui appellerait cette méthode par erreur obtient une liste vide, jamais
  /// les brouillons eux-mêmes. Embarque le wird et le pilier concernés
  /// (`wird_steps`/`wirds`) en un aller-retour, nécessaires pour identifier
  /// la récitation à l'écran.
  Future<List<WirdRecitationDraft>> fetchDraftRecitations() async {
    final rows = await SupabaseConfig.client
        .from('wird_recitations')
        .select(
          'id, reciter_name, audio_path, content_version, duration_seconds, '
          'wird_steps!inner(order_index, transliteration, arabic_text, wirds!inner(name_fr))',
        )
        .eq('content_status', 'brouillon')
        .order('created_at');
    return (rows as List)
        .map((row) => WirdRecitationDraft.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Fait passer une récitation de "brouillon" à "valide" — la RLS
  /// `wird_recitations_admin_update` exige `is_admin` côté serveur, donc
  /// échoue pour tout autre compte même si cette méthode était appelée par
  /// erreur. Renseigne `validated_by`/`validated_at` (trace d'audit, colonnes
  /// dédiées du schéma — §2 du document de décision).
  Future<void> validateRecitation(String recitationId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    await SupabaseConfig.client.from('wird_recitations').update({
      'content_status': 'valide',
      'validated_by': userId,
      'validated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', recitationId);
  }
}

/// Logique pure (sans réseau, testée dans `test/wird_recitation_repository_test.dart`) :
/// associe à chaque pilier (par position) sa récitation par défaut, si elle
/// existe.
Map<int, WirdRecitation> buildRecitationsByPillarIndex({
  required List<Map<String, dynamic>> steps,
  required List<Map<String, dynamic>> recitations,
}) {
  final recitationByStepId = {
    for (final r in recitations) r['wird_step_id'] as String: WirdRecitation.fromRow(r),
  };
  final result = <int, WirdRecitation>{};
  for (final step in steps) {
    final recitation = recitationByStepId[step['id'] as String];
    if (recitation == null) continue;
    final orderIndex = step['order_index'] as int;
    result[orderIndex - 1] = recitation;
  }
  return result;
}
