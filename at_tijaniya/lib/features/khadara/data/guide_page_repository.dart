/// Accès à la table `guide_pages` (Supabase) — pages pédagogiques statiques
/// type "Comprendre la Khadara". RLS (`guide_pages_read_valid_or_admin`) ne
/// laisse remonter une page `content_status = 'brouillon'` qu'à un compte
/// admin : pas de filtre à dupliquer côté client, un disciple recevra
/// simplement zéro ligne tant que la page n'est pas `valide`.
library;

import '../../../core/supabase/supabase_config.dart';

class GuidePage {
  const GuidePage({
    required this.title,
    required this.bodyMarkdown,
    required this.contentStatus,
  });

  factory GuidePage.fromRow(Map<String, dynamic> row) => GuidePage(
        title: row['title'] as String,
        bodyMarkdown: row['body_markdown'] as String,
        contentStatus: row['content_status'] as String,
      );

  final String title;
  final String bodyMarkdown;
  final String contentStatus;
}

class GuidePageRepository {
  const GuidePageRepository();

  Future<GuidePage?> fetchBySlug(String slug) async {
    final rows = await SupabaseConfig.client.from('guide_pages').select().eq('slug', slug).limit(1);
    if (rows.isEmpty) return null;
    return GuidePage.fromRow(rows.first);
  }
}
