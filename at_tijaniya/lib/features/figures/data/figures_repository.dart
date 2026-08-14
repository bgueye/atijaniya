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
import '../../lineage/domain/lineage_models.dart' show Foyer, foyerToDbValue;
import '../domain/figure_models.dart';

const _figuresSelect =
    '*, figure_quotes(text_ar, text_fr, source_note), figure_works(title, description, order_index)';

class FiguresRepository {
  const FiguresRepository();

  Future<List<Figure>> fetchFigures() async {
    final rows = await SupabaseConfig.client
        .from('figures')
        .select(_figuresSelect)
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
        .select(_figuresSelect)
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

  /// Enregistre l'URL publique d'un portrait déjà téléversé vers le bucket
  /// `figure-portraits` (voir `ImageUploadService`, appelé côté écran juste
  /// avant) — RLS `figures_admin_update`, même protection que
  /// `validateFigure`. `null` pour retirer le portrait existant.
  Future<void> updatePortrait(String figureId, String? portraitUrl) async {
    await SupabaseConfig.client.from('figures').update({'portrait_url': portraitUrl}).eq('id', figureId);
  }

  /// Création réservée par RLS (`figures_admin_write`) à un compte admin.
  /// `content_status` jamais envoyé : la colonne défaut à `brouillon` côté
  /// base — publier reste un geste séparé et explicite via
  /// `validateFigure()`/`FiguresReviewScreen`, pour garder intact le
  /// garde-fou éditorial déjà en place (voir la note "contenu religieux"
  /// en tête de `figure_models.dart`).
  Future<Figure> createFigure({
    required String nameArabic,
    required String nameFrench,
    required FigureCategory category,
    Foyer? foyer,
    int? birthYearHijri,
    String? bioText,
  }) async {
    final row = await SupabaseConfig.client
        .from('figures')
        .insert({
          'name_ar': nameArabic,
          'name_fr': nameFrench,
          'category': category == FigureCategory.founder ? 'founder' : 'family_lineage',
          'foyer': foyer != null ? foyerToDbValue(foyer) : null,
          'birth_year_hijri': birthYearHijri,
          'bio_text': bioText,
        })
        .select(_figuresSelect)
        .single();
    return Figure.fromRow(row);
  }

  /// `content_status` jamais dans le payload — une correction de coquille
  /// sur une figure déjà `valide` ne la dépublie jamais, même principe que
  /// `createFigure`.
  Future<Figure> updateFigure(
    String id, {
    required String nameArabic,
    required String nameFrench,
    required FigureCategory category,
    Foyer? foyer,
    int? birthYearHijri,
    String? bioText,
  }) async {
    final row = await SupabaseConfig.client
        .from('figures')
        .update({
          'name_ar': nameArabic,
          'name_fr': nameFrench,
          'category': category == FigureCategory.founder ? 'founder' : 'family_lineage',
          'foyer': foyer != null ? foyerToDbValue(foyer) : null,
          'birth_year_hijri': birthYearHijri,
          'bio_text': bioText,
        })
        .eq('id', id)
        .select(_figuresSelect)
        .single();
    return Figure.fromRow(row);
  }

  /// Peut lever une `PostgrestException` (code `23503`) si cette figure est
  /// encore référencée comme `parent_figure_id` dans la silsila historique
  /// d'une autre figure (`historical_silsila_links`, sans `on delete
  /// cascade` sur cette colonne précise — voir `database/schema.sql`) —
  /// volontairement non catchée ici, voir `classifyFigureDeleteError`
  /// (`figure_errors.dart`) côté appelant.
  Future<void> deleteFigure(String id) async {
    await SupabaseConfig.client.from('figures').delete().eq('id', id);
  }

  /// Silsila historique (généalogie spirituelle) depuis le fondateur
  /// jusqu'à [figureId], via la fonction Postgres `get_historical_silsila_chain`
  /// (`SECURITY DEFINER` — nécessaire pour résoudre les maillons
  /// intermédiaires encore en `brouillon`, voir le commentaire de la
  /// fonction dans `database/schema.sql`). Liste vide si cette figure n'a
  /// pas encore de silsila documentée.
  Future<List<HistoricalSilsilaLink>> fetchHistoricalSilsilaChain(String figureId) async {
    final rows = await SupabaseConfig.client.rpc(
      'get_historical_silsila_chain',
      params: {'p_figure_id': figureId},
    );
    return (rows as List).map((row) => HistoricalSilsilaLink.fromRow(row as Map<String, dynamic>)).toList();
  }
}
