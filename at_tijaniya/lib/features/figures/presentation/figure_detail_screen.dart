import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';

/// Biographie détaillée d'une figure — texte, citations, ziyara associée.
/// Priorité P1 (docs/03-architecture-ecrans.md).
///
/// Le contenu affiché ici provient exclusivement de
/// `lib/features/figures/data/figures_content.dart` (source unique) — voir
/// la règle impérative en tête de ce fichier de contenu. Tant qu'une figure
/// n'a pas de biographie validée, cet écran l'indique explicitement plutôt
/// que de rester silencieux.
class FigureDetailScreen extends StatelessWidget {
  const FigureDetailScreen({super.key, required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(figure.nameFrench)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            figure.nameArabic,
            textAlign: TextAlign.center,
            style: AppTheme.sacredText(fontSize: 30, color: AppColors.emerald),
          ),
          if (figure.summary != null) ...[
            const SizedBox(height: 16),
            Text(
              figure.summary!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.bronze, fontSize: 15),
            ),
          ],
          const SizedBox(height: 28),
          _SectionTitle(l10n.figureBiographySectionTitle),
          const SizedBox(height: 8),
          if (figure.biography == null || figure.biography!.isEmpty)
            _PendingNote(l10n.figureBiographyPending)
          else
            for (final paragraph in figure.biography!) _BiographyParagraph(paragraph: paragraph),
          if (figure.citations != null && figure.citations!.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionTitle(l10n.figureCitationsSectionTitle),
            const SizedBox(height: 8),
            for (final citation in figure.citations!) _CitationCard(citation: citation),
          ],
          if (figure.ziyaraNote != null) ...[
            const SizedBox(height: 28),
            _SectionTitle(l10n.figureZiyaraSectionTitle),
            const SizedBox(height: 8),
            Text(figure.ziyaraNote!, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink));
  }
}

class _PendingNote extends StatelessWidget {
  const _PendingNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, color: AppColors.bronze, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 13))),
        ],
      ),
    );
  }
}

class _BiographyParagraph extends StatelessWidget {
  const _BiographyParagraph({required this.paragraph});

  final FigureBiographyParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paragraph.arabic != null) ...[
            Text(
              paragraph.arabic!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
          ],
          if (paragraph.transliteration != null) ...[
            Text(
              paragraph.transliteration!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.bronze),
            ),
            const SizedBox(height: 4),
          ],
          Text(paragraph.translation, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
        ],
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  const _CitationCard({required this.citation});

  final FigureCitation citation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (citation.arabic != null) ...[
            Text(
              citation.arabic!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
          ],
          if (citation.transliteration != null) ...[
            Text(
              citation.transliteration!,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.bronze),
            ),
            const SizedBox(height: 4),
          ],
          Text(citation.translation, style: const TextStyle(color: AppColors.ink, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '— ${citation.source}',
            style: const TextStyle(color: AppColors.bronze, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
