/// Accès aux données Khadara (Supabase — `zawiyas`, `events`). Lecture
/// publique côté RLS (`zawiyas_read_all`, `events_read_all` : `using (true)`,
/// docs/06-architecture-backend.md) : fonctionne aussi bien en mode invité
/// que connecté, pas besoin d'authentification pour consulter.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/khadara_models.dart';

class KhadaraRepository {
  const KhadaraRepository();

  Future<List<Zawiya>> fetchZawiyas() async {
    final rows = await SupabaseConfig.client.from('zawiyas').select().order('name', ascending: true);
    return rows.map((row) => Zawiya.fromRow(row)).toList();
  }

  /// Évènements à venir (`starts_at >= maintenant`), triés du plus proche au
  /// plus lointain. Le nom de la zawiya est résolu en une seule requête via
  /// l'embedding PostgREST plutôt qu'un aller-retour supplémentaire.
  Future<List<KhadaraEvent>> fetchUpcomingEvents() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await SupabaseConfig.client
        .from('events')
        .select('*, zawiyas(name)')
        .gte('starts_at', nowIso)
        .order('starts_at', ascending: true);
    return rows.map((row) => KhadaraEvent.fromRow(row)).toList();
  }
}
