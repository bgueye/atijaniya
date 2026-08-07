import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/figure_models.dart';

/// Biographie détaillée d'une figure — en-tête immersif (rosace + noms) et
/// onglets Biographie/Silsila/Citations/Ziyaras. Priorité P1
/// (docs/03-architecture-ecrans.md), mise en page alignée sur la maquette
/// charte graphique (`docs/At-Tijaniya-Charte-Graphique-Maquettes-v2.html`,
/// bloc 07 « Biographie détaillée »).
///
/// Le contenu affiché ici provient exclusivement de la table Supabase
/// `figures` (voir `figure_models.dart`) — aucun texte religieux inventé.
/// Les onglets "Silsila" et "Ziyaras" n'ont aujourd'hui aucune source de
/// données réelle (aucune requête vers `historical_silsila_links`, aucune
/// colonne "ziyara" alimentée sur `figures` — `Figure.ziyaraNote` reste donc
/// toujours `null` pour une figure venant de la base) : ils affichent un
/// état honnête "pas encore disponible" plutôt qu'un contenu simulé, même
/// logique que "Comprendre la Khadara" (`khadara_understanding_screen.dart`).
class FigureDetailScreen extends StatelessWidget {
  const FigureDetailScreen({super.key, required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Column(
          children: [
            _FigureHero(figure: figure),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                border: Border(bottom: BorderSide(color: AppColors.bronze.withValues(alpha: 0.2))),
              ),
              child: TabBar(
                labelColor: AppColors.emerald,
                unselectedLabelColor: AppColors.bronze,
                indicatorColor: AppColors.gold,
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(text: l10n.figureBiographySectionTitle),
                  Tab(text: l10n.figureTabSilsila),
                  Tab(text: l10n.figureCitationsSectionTitle),
                  Tab(text: l10n.figureZiyaraSectionTitle),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BiographyTab(figure: figure),
                  _PendingTab(message: l10n.figureSilsilaPending),
                  _CitationsTab(figure: figure),
                  _ZiyarasTab(figure: figure),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureHero extends StatelessWidget {
  const _FigureHero({required this.figure});

  final Figure figure;

  /// Teinte du sous-titre français — spécifique à ce dégradé sombre, absente
  /// de `design_tokens.yaml` (qui ne couvre que la palette de marque, pas
  /// les variantes décoratives ponctuelles de la maquette).
  static const _subtitleColor = Color(0xFFCFE0D6);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.zaytoune, AppColors.emerald],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 176,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 8,
                child: Opacity(
                  opacity: 0.12,
                  child: SizedBox(width: 140, height: 140, child: CustomPaint(painter: _RosacePainter())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      figure.nameArabic,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: AppTheme.sacredText(fontSize: 24, color: AppColors.goldSoft),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      figure.nameFrench.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _subtitleColor, fontSize: 12, letterSpacing: 1.4),
                    ),
                  ],
                ),
              ),
              const PositionedDirectional(
                top: 4,
                start: 4,
                child: BackButton(color: AppColors.parchment),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rosace à huit branches — motif signature du design system (§03 de la
/// charte graphique), reproduit ici en trait fin pour servir de filigrane
/// derrière les noms de la figure. Un seul tracé, jamais répété en pattern
/// (règle du design system) : `CustomPainter` plutôt qu'un asset SVG, pour
/// obtenir exactement le tracé de la maquette (deux cercles + étoile à huit
/// pointes, sans le disque de fond ni le texte du logo d'app).
class _RosacePainter extends CustomPainter {
  const _RosacePainter();

  static const _starPoints = [
    Offset(100, 20),
    Offset(112, 80),
    Offset(172, 80),
    Offset(122, 112),
    Offset(140, 172),
    Offset(100, 132),
    Offset(60, 172),
    Offset(78, 112),
    Offset(28, 80),
    Offset(88, 80),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 92 * scale, paint);
    canvas.drawCircle(center, 78 * scale, paint);
    canvas.drawPath(
      Path()..addPolygon([for (final point in _starPoints) point * scale], true),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _BiographyTab extends StatelessWidget {
  const _BiographyTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final biography = figure.biography;
    if (biography == null || biography.isEmpty) {
      return _PendingTab(message: l10n.figureBiographyPending);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [for (final paragraph in biography) _BiographyParagraph(paragraph: paragraph)],
    );
  }
}

class _CitationsTab extends StatelessWidget {
  const _CitationsTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final citations = figure.citations;
    if (citations == null || citations.isEmpty) {
      return _PendingTab(message: l10n.figureCitationsEmpty);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [for (final citation in citations) _CitationCard(citation: citation)],
    );
  }
}

class _ZiyarasTab extends StatelessWidget {
  const _ZiyarasTab({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ziyaraNote = figure.ziyaraNote;
    if (ziyaraNote == null) {
      return _PendingTab(message: l10n.figureZiyarasPending);
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [Text(ziyaraNote, style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4))],
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
