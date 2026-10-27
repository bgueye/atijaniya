// Carte « Figure de la semaine » de l'accueil, avec ou sans portrait.
// Extrait de `home_screen.dart` (audit de l'accueil du 2026-10-26, P3-5).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../../figures/domain/featured_figure.dart';
import '../../figures/domain/figure_models.dart' show FigureCitation;
import '../../figures/presentation/figure_detail_screen.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../../core/widgets/content_text.dart';

/// Carte "Figure de la semaine" — portrait plein cadre, nom + citation/date
/// de ziara superposés en bas sur un dégradé émeraude translucide (jamais
/// zaytoune ici : réservé aux écrans de pratique, voir `CLAUDE.md`), pour
/// que la photo reste lisible sous le texte plutôt que d'être masquée par
/// un bandeau opaque. Une figure sans portrait (admise dans la rotation
/// depuis le 2026-10-26, audit de l'accueil P2-3) a une carte sans photo :
/// voir `_FeaturedFigureTypographicCard`.
class HomeFeaturedFigureCard extends StatelessWidget {
  const HomeFeaturedFigureCard({super.key, required this.featured});

  final FeaturedFigure featured;

  @override
  Widget build(BuildContext context) {
    final figure = featured.figure;
    final citation = featured.citation;
    final nextZiyara = featured.nextZiyara;
    if (figure.portraitUrl == null) return _FeaturedFigureTypographicCard(featured: featured);
    // Interface arabe (P3-4) : le nom arabe passe en titre et le nom français
    // en dessous ; la citation est donnée dans son texte arabe quand il existe.
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final frenchName = ContentText(
      figure.nameFrench,
      style: AppTheme.titleText(
        fontWeight: FontWeight.w700,
        fontSize: isArabic ? 17 : 26,
        height: 1.05,
        color: isArabic ? AppColors.goldSoft : AppColors.offWhite,
      ),
    );
    final arabicName = Text(
      figure.nameArabic,
      textDirection: TextDirection.rtl,
      style: AppTheme.sacredText(
        fontSize: isArabic ? 26 : 19,
        color: isArabic ? AppColors.offWhite : AppColors.goldSoft,
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
        ),
        // 3:4 (portrait) plutôt que 4:3 : carte plus grande, format proche
        // des portraits en base (sujet proche du haut de la photo, comme
        // `figure_detail_screen.dart`) et assez de hauteur pour que le
        // dégradé + le texte n'empiètent que sur le tiers bas de l'image.
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                figure.portraitUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.zaytoune),
                // Fond et indicateur pendant le téléchargement : la carte était
                // un rectangle vide jusqu'à l'arrivée du portrait (P2-2).
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : ColoredBox(
                        color: AppColors.emeraldSoft,
                        child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
                      ),
                // Voir la même note dans event_detail_screen.dart.
                cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      AppColors.emerald.withValues(alpha: 0.25),
                      AppColors.emerald.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cormorant Garamond pour le nom français : voir
                      // `AppTheme.titleText` (le `fontFamily` d'avant n'était
                      // jamais appliqué).
                      if (isArabic) arabicName else frenchName,
                      const SizedBox(height: 2),
                      if (isArabic) frenchName else arabicName,
                      if (citation != null) ...[
                        const SizedBox(height: 8),
                        _FeaturedCitation(citation: citation),
                      ],
                      if (nextZiyara != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 14, color: AppColors.goldSoft),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${nextZiyara.title} · ${formatKhadaraEventSchedule(nextZiyara, AppLocalizations.of(context)!)}',
                                style: const TextStyle(color: AppColors.goldSoft, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte "Figure de la semaine" sans photo (P2-3) : nom arabe en grand
/// (Amiri, texte religieux), nom français, citation et prochaine ziara, sur
/// fond émeraude avec la rosace de la charte. Hauteur selon le contenu, pas
/// de cadre 3:4 vide.
class _FeaturedFigureTypographicCard extends StatelessWidget {
  const _FeaturedFigureTypographicCard({required this.featured});

  final FeaturedFigure featured;

  @override
  Widget build(BuildContext context) {
    final figure = featured.figure;
    final citation = featured.citation;
    final nextZiyara = featured.nextZiyara;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.emerald,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FigureDetailScreen(figure: figure)),
        ),
        child: Stack(
          children: [
            const PositionedDirectional(
              top: -24,
              end: -24,
              child: Opacity(
                opacity: 0.18,
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.goldSoft, strokeWidth: 1.6)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    figure.nameArabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: AppTheme.sacredText(fontSize: 30, color: AppColors.goldSoft),
                  ),
                  const SizedBox(height: 6),
                  ContentText(
                    figure.nameFrench,
                    textAlign: TextAlign.center,
                    style: AppTheme.titleText(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.offWhite),
                  ),
                  if (citation != null) ...[
                    const SizedBox(height: 12),
                    _FeaturedCitation(citation: citation, textAlign: TextAlign.center),
                  ],
                  if (nextZiyara != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: AppColors.goldSoft),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${nextZiyara.title} · ${formatKhadaraEventSchedule(nextZiyara, AppLocalizations.of(context)!)}',
                            style: const TextStyle(color: AppColors.goldSoft, fontSize: 11.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Citation de la figure de la semaine. En interface arabe, son texte arabe
/// d'origine quand il a été saisi (audit de l'accueil du 2026-10-26, P3-4),
/// en Amiri comme sur la fiche de la figure ; sinon la traduction, en
/// italique.
class _FeaturedCitation extends StatelessWidget {
  const _FeaturedCitation({required this.citation, this.textAlign});

  final FigureCitation citation;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final arabic = citation.arabic?.trim();
    if (Localizations.localeOf(context).languageCode == 'ar' && arabic != null && arabic.isNotEmpty) {
      return Text(
        '« $arabic »',
        textAlign: textAlign,
        textDirection: TextDirection.rtl,
        style: AppTheme.sacredText(fontSize: 16, color: AppColors.offWhite.withValues(alpha: 0.9)),
      );
    }
    return ContentText(
      '« ${citation.translation} »',
      textAlign: textAlign,
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: AppColors.offWhite.withValues(alpha: 0.9),
        fontSize: 12.5,
      ),
    );
  }
}
