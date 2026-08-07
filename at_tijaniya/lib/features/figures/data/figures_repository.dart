/// Accès aux données du module Figures (Supabase — table `figures`).
///
/// IMPORTANT (contenu religieux) : la RLS (`figures_read_valid_or_admin` :
/// `content_status = 'valide' OR is_admin(...)`, docs/06-architecture-backend.md)
/// laisse volontairement passer les lignes "brouillon" pour un compte admin
/// (nécessaire pour qu'un futur back-office puisse les relire avant
/// validation). Un disciple connecté avec un compte admin verrait donc les
/// brouillons si l'app ne filtrait que sur la RLS — d'où le filtre explicite
/// `content_status = 'valide'` ci-dessous, appliqué côté client en plus de
/// la RLS (défense en profondeur) : l'app ne doit JAMAIS afficher de
/// biographie non validée, y compris à un compte admin. Voir la règle
/// "contenu religieux" en tête de `figure_models.dart`.
library;

import '../../../core/supabase/supabase_config.dart';
import '../domain/figure_models.dart';

class FiguresRepository {
  const FiguresRepository();

  Future<List<Figure>> fetchFigures() async {
    final rows = await SupabaseConfig.client
        .from('figures')
        .select('*, figure_quotes(text_ar, text_fr, source_note)')
        .eq('content_status', 'valide')
        .order('category', ascending: true)
        .order('name_fr', ascending: true);
    return rows.map((row) => Figure.fromRow(row)).toList();
  }

  /// Figures en attente de validation ("brouillon"), pour l'écran de review
  /// admin (`FiguresReviewScreen`). La RLS `figures_read_valid_or_admin` ne
  /// renvoie ces lignes qu'à un compte `is_admin` — un compte non-admin qui
  /// appellerait cette méthode par erreur obtient simplement une liste vide,
  /// jamais les brouillons eux-mêmes.
  Future<List<Figure>> fetchDraftFigures() async {
    final rows = await SupabaseConfig.client
        .from('figures')
        .select('*, figure_quotes(text_ar, text_fr, source_note)')
        .eq('content_status', 'brouillon')
        .order('category', ascending: true)
        .order('name_fr', ascending: true);
    return rows.map((row) => Figure.fromRow(row)).toList();
  }

  /// Fait passer une figure de "brouillon" à "valide" — la RLS
  /// `figures_admin_update` exige `is_admin` côté serveur, donc échoue pour
  /// tout autre compte même si cette méthode était appelée par erreur.
  Future<void> validateFigure(String figureId) async {
    await SupabaseConfig.client.from('figures').update({'content_status': 'valide'}).eq('id', figureId);
  }
}
