/// Carte d'un pilier dans le guide d'un wird : texte arabe, translittération,
/// traduction, formules de clôture, conditions, texte intégral et bouton de
/// lecture audio. Sortie de `wird_detail_screen.dart` (audit du 2026-10-25,
/// P3-8), sans changement de comportement.
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
    required this.availability,
    required this.isActive,
    required this.isPlaying,
    required this.isBuffering,
    required this.onTogglePlay,
  });

  final WirdPillar pillar;
  final PillarAudioAvailability availability;
  final bool isActive;
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: AppColors.goldOnDark, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AudioPillarButton(
                availability: availability,
                isPlaying: isPlaying,
                isBuffering: isBuffering,
                onPressed: onTogglePlay,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pillar.arabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.sacredText(fontSize: 22, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              _RepetitionBadge(count: pillar.repetitions),
            ],
          ),
          const SizedBox(height: 10),
          ContentText(
            pillar.transliteration,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              // Encre atténuée plutôt que bronze (4,09:1 sur blanc cassé,
              // sous l'AA) : la translittération se lit, ce n'est pas une
              // légende (audit du 2026-10-25, P2-6).
              color: AppColors.secondaryInk,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ContentText(
            pillar.translation,
            style: const TextStyle(color: AppColors.ink, fontSize: 16),
          ),
          if (pillar.note != null) ...[
            const SizedBox(height: 10),
            ContentText(
              pillar.note!,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryInk),
            ),
          ],
          if (pillar.closingFormulas != null)
            for (final formula in pillar.closingFormulas!) ...[
              const SizedBox(height: 10),
              _ClosingFormulaBlock(formula: formula),
            ],
          if (pillar.conditions != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.wirdDetailStrictConditions,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  for (final c in pillar.conditions!)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ContentText('• $c', style: const TextStyle(fontSize: 12, color: AppColors.ink)),
                    ),
                ],
              ),
            ),
          ],
          if (pillar.fullText != null) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              // `Material` transparent : sans lui, l'effet de toucher de la
              // ligne se peignait sous le fond blanc de la carte, donc
              // invisible, et Flutter le signalait à chaque reconstruction en
              // débogage (passe sur émulateur du 2026-10-25, P3-9).
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    AppLocalizations.of(context)!.wirdDetailFullText,
                    style: TextStyle(fontSize: 13, color: AppColors.emerald, fontWeight: FontWeight.w500),
                  ),
                  children: [
                    for (final p in pillar.fullText!) _ParagraphBlock(paragraph: p),
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

/// Une formule de clôture (`WirdPillar.closingFormulas`) — introduction
/// française, puis arabe (police Amiri, RTL) et translittération dans leur
/// propre bloc, jamais fondus dans la même phrase que le français (retour
/// du porteur de projet, 2026-08-17 : le mélange arabe/français dans
/// `note` empêchait une mise en forme correcte du texte arabe).
class _ClosingFormulaBlock extends StatelessWidget {
  const _ClosingFormulaBlock({required this.formula});

  final WirdClosingFormula formula;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentText(formula.intro, style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
        const SizedBox(height: 4),
        Text(
          formula.arabic,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: AppTheme.sacredText(fontSize: 17, color: AppColors.ink),
        ),
        if (formula.transliteration != null) ...[
          const SizedBox(height: 2),
          ContentText(
            formula.transliteration!,
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.secondaryInk),
          ),
        ],
      ],
    );
  }
}

/// Bouton de lecture individuel affiché sur chaque pilier — grisé et
/// désactivé tant qu'aucune récitation validée n'existe pour ce pilier ;
/// une icône de téléchargement quand elle existe mais n'est pas encore sur
/// l'appareil (docs/decision-gestion-audio-wirds.md §4).
///
/// `IconButton` de 48 × 48 avec `tooltip` : la version précédente (un
/// `InkWell` nu autour d'une icône de 22 à 26 px) n'avait ni libellé pour
/// TalkBack, qui annonçait seulement « bouton », ni la zone tactile minimale
/// d'Android (audits du 2026-10-04 et du 2026-10-25). Chaque état a son
/// propre libellé : écouter, mettre en pause, télécharger, réessayer.
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
      // Pas d'action possible : une simple image annoncée, même encombrement
      // que le bouton pour que le texte du pilier ne se décale pas.
      return Semantics(
        // Nœud propre : sans lui, le libellé se fondait dans celui du texte
        // du pilier voisin.
        container: true,
        label: l10n.wirdAudioPillarUnavailable,
        child: ConstrainedBox(
          constraints: _size,
          child: Center(child: Icon(Icons.music_off, color: AppColors.bronze, size: 22)),
        ),
      );
    }

    final String tooltip;
    final Widget icon;
    // `loadFailed` : la liste des récitations n'a pas pu être chargée ; même
    // geste qu'après un téléchargement en échec, retenter.
    if (availability == PillarAudioAvailability.error || availability == PillarAudioAvailability.loadFailed) {
      tooltip = l10n.wirdAudioPillarRetry;
      icon = Icon(Icons.error_outline, color: AppColors.bronze, size: 22);
    } else if (isBuffering) {
      tooltip = l10n.wirdAudioDownloading;
      icon = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
      );
    } else if (availability == PillarAudioAvailability.notDownloaded) {
      tooltip = l10n.wirdAudioPillarDownload;
      icon = Icon(Icons.download_for_offline_outlined, color: AppColors.emerald, size: 26);
    } else {
      tooltip = isPlaying ? l10n.wirdAudioPillarPause : l10n.wirdAudioPillarPlay;
      icon = Icon(
        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
        color: AppColors.emerald,
        size: 26,
      );
    }
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: _size,
      icon: icon,
      onPressed: onPressed,
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({required this.paragraph});

  final WirdParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            paragraph.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTheme.sacredText(fontSize: 18, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          ContentText(
            paragraph.transliteration,
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: AppColors.secondaryInk),
          ),
          const SizedBox(height: 4),
          ContentText(paragraph.translation, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _RepetitionBadge extends StatelessWidget {
  const _RepetitionBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.emeraldSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '×$count',
        // Toujours « ×100 » : en arabe le signe passait après le nombre.
        textDirection: TextDirection.ltr,
        style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
