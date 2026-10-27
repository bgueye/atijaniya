// En-tête de l'accueil : salutation, date et statut du jour.
// Extrait de `home_screen.dart` (audit de l'accueil du 2026-10-26, P3-5).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/home_dashboard.dart';
import '../../../core/widgets/content_text.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({super.key, required this.greeting, required this.dateLine, required this.statusPill});

  final String greeting;
  final String dateLine;
  final Widget? statusPill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.zaytoune,
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Motif signature du design system, une seule occurrence par
            // écran (design_tokens.yaml § iconography) — jamais utilisé sur
            // l'accueil jusqu'ici.
            Positioned(
              top: -28,
              right: -28,
              child: Opacity(
                opacity: 0.14,
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(painter: RosacePainter(color: AppColors.gold, strokeWidth: 1.6)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ContentText(
                    greeting,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: AppColors.offWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ContentText(
                    dateLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.offWhite.withValues(alpha: 0.55)),
                  ),
                  // La date hégirienne est calculée (calendrier tabulaire) et
                  // peut différer d'un jour de l'observation de la lune, que
                  // suit la communauté : on le dit plutôt que de l'afficher
                  // comme un fait (décision du porteur de projet du
                  // 2026-10-26, audit de l'accueil P2-4).
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.homeHijriApproximateNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.offWhite.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: 16),
                  if (statusPill != null) statusPill!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeStatusPill extends StatelessWidget {
  const HomeStatusPill({super.key, required this.status, required this.l10n});

  final HomeTodayStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final text = switch (status.kind) {
      HomeStatusKind.allDone => l10n.homeStatusAllDone,
      HomeStatusKind.noneDone => l10n.homeStatusNoneDone,
      HomeStatusKind.partial => l10n.homeStatusPartial(status.doneCount, status.totalCount),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.offWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(end: 10),
            decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
          Expanded(
            child: ContentText(text, style: const TextStyle(color: AppColors.offWhite, fontSize: 13.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
