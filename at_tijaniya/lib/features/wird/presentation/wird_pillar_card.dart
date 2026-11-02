/// Un pilier dans le guide d'un wird. Refait le 2026-11-02 dans le langage de
/// l'écran de pratique (`docs/maquettes/ecran-pratique.html`), sur fond
/// zaytoune : numéro, nom court et nombre, arabe en Amiri or, translittération,
/// traduction et note, puis chaque formule de clôture dans son propre bloc,
/// en entier. Les piliers récités une fois (Fatiha) sont déroulés verset par
/// verset ; le texte long de Jawharatoul Kamal reste replié derrière « Texte
/// intégral ». Le bouton de lecture audio du pilier est inchangé.
///
/// Tous les textes viennent du corpus validé (`wirds_content.dart`).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/wird_models.dart';
import '../domain/wird_recitation.dart';

class WirdPillarCard extends StatelessWidget {
  const WirdPillarCard({
    super.key,
    required this.pillar,
    required this.number,
    required this.availability,
    required this.isActive,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTogglePlay,
    this.arabicSize = 26,
  });

  final WirdPillar pillar;

  /// Rang du pilier dans le wird, à partir de 1 (les piliers forment une
  /// suite ordonnée, d'où le numéro).
  final int number;
  final PillarAudioAvailability availability;

  /// Pilier en cours de lecture audio : filet or.
  final bool isActive;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTogglePlay;

  /// Taille de l'arabe, réglée par « Aa » (même réglage que le tasbih).
  final double arabicSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final arabicInterface = Localizations.localeOf(context).languageCode == 'ar';
    final fullText = pillar.fullText;
    // Fatiha : déroulée, verset par verset. Jawharatoul Kamal (long) : repliée.
    final expandedVerses = fullText != null && pillar.repetitions == 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.goldOnDark : AppColors.parchment.withValues(alpha: 0.12),
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : numéro, nom court et nombre, lecture audio.
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.6)),
                ),
                child: Text('$number', style: const TextStyle(fontSize: 12, color: AppColors.goldOnDark)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Flexible(
                        child: ContentText(
                          pillar.labelFor(arabic: arabicInterface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: arabicInterface
                              ? AppTheme.sacredText(fontSize: 17, color: AppColors.offWhite).copyWith(height: 1.4)
                              : const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.offWhite),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Toujours « ×100 », de gauche à droite.
                      Text(
                        '×${pillar.repetitions}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.goldOnDark),
                      ),
                    ],
                  ),
                ),
              ),
              _AudioPillarButton(
                availability: availability,
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                onPressed: onTogglePlay,
              ),
            ],
          ),
          // Référence dans les ouvrages (validée, `docs/14`) : discrète, sous
          // l'en-tête. En français dans les deux langues, comme les notes.
          if (pillar.source != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 36, end: 8, bottom: 2),
              child: Text(
                l10n.wirdRepairSource(pillar.source!),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontSize: 12, height: 1.35, fontStyle: FontStyle.italic, color: AppColors.secondaryOnDark),
              ),
            ),
          const SizedBox(height: 6),
          if (pillar.note != null && expandedVerses) ...[
            _Note(pillar.note!),
            const SizedBox(height: 8),
          ],
          if (expandedVerses)
            for (var i = 0; i < fullText.length; i++)
              _Verse(paragraph: fullText[i], number: i + 1, arabicSize: arabicSize)
          else ...[
            Text(
              pillar.arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.sacredText(fontSize: arabicSize, color: AppColors.goldOnDark).copyWith(height: 1.7),
            ),
            const SizedBox(height: 6),
            _Transliteration(pillar.transliteration),
            const SizedBox(height: 4),
            _Translation(pillar.translation),
            if (pillar.note != null) ...[
              const SizedBox(height: 10),
              _Note(pillar.note!),
            ],
          ],
          if (pillar.conditions != null) ...[
            const SizedBox(height: 12),
            // Conditions strictes (Jawharatoul Kamal) : avertissement, en or.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.wirdDetailStrictConditions,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  for (final c in pillar.conditions!)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child:
                          ContentText('• $c', style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink)),
                    ),
                ],
              ),
            ),
          ],
          if (pillar.closingFormulas != null)
            for (final formula in pillar.closingFormulas!) ...[
              const SizedBox(height: 10),
              _ClosingFormulaBlock(formula: formula, arabicSize: arabicSize - 4),
            ],
          if (fullText != null && !expandedVerses) ...[
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  iconColor: AppColors.goldOnDark,
                  collapsedIconColor: AppColors.goldOnDark,
                  title: Text(
                    l10n.wirdDetailFullText,
                    style: const TextStyle(fontSize: 14, color: AppColors.goldOnDark, fontWeight: FontWeight.w500),
                  ),
                  children: [
                    for (var i = 0; i < fullText.length; i++)
                      _Verse(paragraph: fullText[i], number: null, arabicSize: arabicSize - 4),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Transliteration extends StatelessWidget {
  const _Transliteration(this.text, {this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  // Caractères latins : toujours de gauche à droite.
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, height: 1.45, color: AppColors.parchment),
      );
}

class _Translation extends StatelessWidget {
  const _Translation(this.text, {this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.secondaryOnDark),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.secondaryOnDark),
      );
}

/// Un verset (Fatiha, numéroté) ou un paragraphe d'un texte long : arabe,
/// translittération, traduction.
class _Verse extends StatelessWidget {
  const _Verse({required this.paragraph, required this.number, required this.arabicSize});

  final WirdParagraph paragraph;
  final int? number;
  final double arabicSize;

  @override
  Widget build(BuildContext context) {
    final number = this.number;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: number == null || number == 1
            ? null
            : Border(top: BorderSide(color: AppColors.parchment.withValues(alpha: 0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsetsDirectional.only(end: 10, top: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.45)),
              ),
              child: Text('$number', style: const TextStyle(fontSize: 10.5, color: AppColors.goldOnDark)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  paragraph.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style:
                      AppTheme.sacredText(fontSize: arabicSize - 4, color: AppColors.goldOnDark).copyWith(height: 1.7),
                ),
                _Transliteration(paragraph.transliteration, align: TextAlign.left),
                const SizedBox(height: 2),
                _Translation(paragraph.translation, align: TextAlign.left),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formule de clôture : introduction, arabe en Amiri, translittération quand
/// le document source en fournit une — en entier, comme à l'étape de clôture
/// du tasbih (sans case à cocher : le guide se lit).
class _ClosingFormulaBlock extends StatelessWidget {
  const _ClosingFormulaBlock({required this.formula, required this.arabicSize});

  final WirdClosingFormula formula;
  final double arabicSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldOnDark.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            formula.intro,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.secondaryOnDark),
          ),
          const SizedBox(height: 4),
          Text(
            formula.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppTheme.sacredText(fontSize: arabicSize, color: AppColors.goldOnDark).copyWith(height: 1.7),
          ),
          if (formula.transliteration != null) ...[
            const SizedBox(height: 2),
            Text(
              formula.transliteration!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style:
                  const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, height: 1.45, color: AppColors.parchment),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lecture audio d'un pilier : jouer, mettre en pause, télécharger,
/// réessayer, ou « pas encore disponible ». Zone tactile de 48 dp.
class _AudioPillarButton extends StatelessWidget {
  const _AudioPillarButton({
    required this.availability,
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  final PillarAudioAvailability availability;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  static const _size = BoxConstraints.tightFor(width: 48, height: 48);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (availability == PillarAudioAvailability.noRecitation) {
      return Semantics(
        container: true,
        label: l10n.wirdAudioPillarUnavailable,
        child: ConstrainedBox(
          constraints: _size,
          child: Center(child: Icon(Icons.music_off, color: AppColors.secondaryOnDark, size: 20)),
        ),
      );
    }

    final String tooltip;
    final Widget icon;
    if (availability == PillarAudioAvailability.error || availability == PillarAudioAvailability.loadFailed) {
      tooltip = l10n.wirdAudioPillarRetry;
      icon = Icon(Icons.error_outline, color: AppColors.secondaryOnDark, size: 22);
    } else if (isBuffering) {
      tooltip = l10n.wirdAudioDownloading;
      icon = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldOnDark),
      );
    } else if (availability == PillarAudioAvailability.notDownloaded) {
      tooltip = l10n.wirdAudioPillarDownload;
      icon = const Icon(Icons.download_for_offline_outlined, color: AppColors.goldOnDark, size: 26);
    } else {
      tooltip = isPlaying ? l10n.wirdAudioPillarPause : l10n.wirdAudioPillarPlay;
      icon =
          Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.goldOnDark, size: 26);
    }
    return IconButton(tooltip: tooltip, padding: EdgeInsets.zero, constraints: _size, icon: icon, onPressed: onPressed);
  }
}
