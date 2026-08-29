/// At-Tijaniya — modèle et parsing du contenu pédagogique "Comprendre la
/// Zawiya".
///
/// Source réelle du contenu : table Supabase `guide_pages` (slug
/// `comprendre-zawiya`), gérée par `GuidePageRepository` et gardée par la
/// RLS `guide_pages_read_valid_or_admin` — un disciple ne reçoit une ligne
/// que si `content_status = 'valide'`, un admin reçoit aussi les brouillons
/// (voir la bannière correspondante sur `KhadaraUnderstandingScreen`). Ce
/// fichier ne fait que découper le `body_markdown` reçu en sections
/// affichables ; il n'invente ni ne complète aucun texte (CLAUDE.md,
/// docs/01-perimetre-fonctionnel.md § 8).
library;

class KhadaraUnderstandingSection {
  const KhadaraUnderstandingSection({required this.title, required this.body});

  final String title;
  final String body;
}

/// Découpe un texte markdown en sections sur les titres `## ...`. Le texte
/// après un séparateur `---` (note de sources, métadonnée éditoriale) est
/// ignoré côté rendu — ce n'est pas du contenu pédagogique pour le disciple.
List<KhadaraUnderstandingSection> parseGuidePageSections(String markdown) {
  final content = markdown.split('\n---\n').first;
  final headings = RegExp(r'^## (.+)$', multiLine: true).allMatches(content).toList();

  final sections = <KhadaraUnderstandingSection>[];
  for (var i = 0; i < headings.length; i++) {
    final title = headings[i].group(1)!.trim();
    final start = headings[i].end;
    final end = i + 1 < headings.length ? headings[i + 1].start : content.length;
    final body = content.substring(start, end).trim();
    sections.add(KhadaraUnderstandingSection(title: title, body: body));
  }
  return sections;
}
