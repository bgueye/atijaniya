import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import '../domain/zawiyas_overview.dart';
import 'khadara_format.dart';

// Morceaux de l'écran Zawiyas refait d'après sa maquette
// (`docs/maquettes/ecran-zawiyas.html`, 2026-11-03) : bandeau du direct,
// carte « Prochain rendez-vous », carte d'un lieu, en-tête de groupe et ligne
// de l'Agenda. Sans état ni fournisseur : l'écran (`khadara_screen.dart`)
// leur passe les données et les actions.

/// Bandeau d'un direct en cours, tout en haut de l'écran, et seulement
/// pendant le direct (il remplace l'onglet « Directs », vide presque tout le
/// temps). Zaytoune : permis pour la khadara en direct (CLAUDE.md).
///
/// Le point or reste fixe, sans la pulsation de la maquette : une animation
/// répétée sans fin attirerait l'œil en permanence, et le texte « En direct »
/// dit déjà l'état.
class LiveNowBanner extends StatelessWidget {
  const LiveNowBanner({super.key, required this.stream, required this.onTap, this.placeName});

  final LiveStream stream;
  final VoidCallback onTap;

  /// Lieu du rendez-vous (ou groupe) du direct, avant la plateforme, comme
  /// dans la maquette (« Zawiya de Tivaouane · YouTube »).
  final String? placeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = stream.displayTitle(l10n.khadaraLiveTab);
    return Material(
      color: AppColors.zaytoune,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.goldOnDark,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.goldOnDark.withValues(alpha: 0.45), spreadRadius: 4)],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(
                      l10n.khadaraLiveBannerTitle(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.offWhite),
                    ),
                    ContentText(
                      [
                        if (placeName != null && placeName!.isNotEmpty) placeName!,
                        liveStreamSourceLabel(stream.sourceType, l10n),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryOnDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.khadaraLiveWatch,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.goldOnDark),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Prochain rendez-vous », en tête de l'écran : la date en grand, le lieu,
/// la date approximative signalée (« ~ » et la mention en clair), le compte à
/// rebours, « Voir » et, si le lieu a des coordonnées, « Itinéraire ».
class NextEventCard extends StatelessWidget {
  const NextEventCard({
    super.key,
    required this.event,
    required this.now,
    required this.onOpen,
    this.onDirections,
  });

  final KhadaraEvent event;
  final DateTime now;
  final VoidCallback onOpen;

  /// `null` : lieu sans coordonnées (Taïba Niassène au 2026-11-03), pas de
  /// bouton.
  final VoidCallback? onDirections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = displayDateOf(event, now);
    final days = calendarDaysUntil(date, now);
    final approximate = event.showsApproximateDate;
    return Container(
      decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(18)),
      // Filet en avant-plan : en arrière-plan, la bande parchemin du bas le
      // recouvrait sur les côtés (vu sur capture). Sans ombre : rognée par le
      // cadre arrondi, elle dessinait une bande grise sous la carte.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateBlock(date: date, approximate: approximate),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(l10n.khadaraNextEyebrow),
                        const SizedBox(height: 2),
                        ContentText(
                          event.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500, height: 1.25, color: AppColors.ink),
                        ),
                        if (event.zawiyaName != null) ...[
                          const SizedBox(height: 3),
                          ContentText(event.zawiyaName!, style: TextStyle(fontSize: 13, color: AppColors.secondaryInk)),
                        ],
                        if (approximate) ...[
                          const SizedBox(height: 6),
                          StatePill(l10n.eventDetailDateApproximate, variant: StatePillVariant.todo),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.parchment,
              border: Border(top: BorderSide(color: AppColors.bronze.withValues(alpha: 0.22))),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    approximate ? l10n.eventDetailCountdown(days) : l10n.khadaraNextCountdown(days),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.emerald),
                  ),
                ),
                if (onDirections != null) TextButton(onPressed: onDirections, child: Text(l10n.khadaraNextDirections)),
                const SizedBox(width: 4),
                FilledButton(onPressed: onOpen, child: Text(l10n.khadaraNextSee)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette d'une carte de lieu (« 2 rendez-vous à venir »,
/// « Succession · 7 », « 8 figures »). Pas un `StatePill` : ce ne sont pas
/// des états, mais ce que le lieu contient ; la coche de la variante « fait »
/// n'aurait pas de sens ici.
class _FactTag extends StatelessWidget {
  const _FactTag(this.text, {required this.background, required this.foreground, this.bordered = false});

  final String text;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: bordered ? Border.all(color: AppColors.bronze.withValues(alpha: 0.25)) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: foreground, height: 1.4)),
    );
  }
}

/// Carte d'un lieu : icône du type, nom, type et adresse, et ce que le lieu
/// contient, tiré des tables existantes. [distanceText] : en mode « Près de
/// moi » seulement.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.facts, required this.onTap, this.distanceText});

  final Zawiya place;
  final PlaceFacts facts;
  final VoidCallback onTap;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Couleurs du type, celles de la maquette prises dans la palette : vert
    // pour une zawiya, or doux pour un lieu saint, parchemin pour une mosquée.
    final (tileBackground, tileForeground) = switch (place.kind) {
      ZawiyaKind.zawiya => (AppColors.emeraldSoft, AppColors.emerald),
      ZawiyaKind.holyPlace => (AppColors.goldSoft, AppColors.ink),
      ZawiyaKind.mosque => (AppColors.parchment, AppColors.bronze),
    };
    final subtitle = [
      zawiyaKindLabel(place.kind, l10n),
      if (place.addressText != null && place.addressText!.trim().isNotEmpty) place.addressText!.trim(),
    ].join(' · ');
    return Material(
      color: AppColors.offWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tileBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: place.kind == ZawiyaKind.mosque
                      ? Border.all(color: AppColors.bronze.withValues(alpha: 0.25))
                      : null,
                ),
                child: Icon(zawiyaKindIcon(place.kind), size: 20, color: tileForeground),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContentText(place.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500, height: 1.25, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    // Deux lignes au plus : une adresse longue se coupait en
                    // pleine parenthèse sur une seule (audit pré-publication).
                    ContentText(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.secondaryInk)),
                    if (!facts.isEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (facts.upcoming > 0)
                            _FactTag(l10n.khadaraPlaceUpcoming(facts.upcoming),
                                background: AppColors.emeraldSoft, foreground: AppColors.emerald),
                          if (facts.succession > 0)
                            _FactTag(l10n.khadaraPlaceSuccession(facts.succession),
                                background: AppColors.goldSoft, foreground: AppColors.ink),
                          if (facts.figures > 0)
                            _FactTag(l10n.khadaraPlaceFigures(facts.figures),
                                background: AppColors.parchment, foreground: AppColors.secondaryInk, bordered: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (distanceText != null) ...[
                const SizedBox(width: 8),
                Text(
                  distanceText!,
                  // Distance en chiffres latins, gauche-droite même en arabe
                  // (« ~12 km » deviendrait « km 12~ »).
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.emerald),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête d'un groupe (pays, mois) : le titre à la façon d'une section du
/// kit, un nombre discret à l'autre bout.
class GroupHeader extends StatelessWidget {
  const GroupHeader({super.key, required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final style = SectionTitle.styleFor(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 20, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: style.copyWith(fontSize: (style.fontSize ?? 22) - 2)),
            ),
          ),
          Text(trailing, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
        ],
      ),
    );
  }
}

/// Nom du mois d'une ligne de l'Agenda (« Décembre 2026 », « ديسمبر 2026 »).
String agendaMonthTitle(AgendaMonth month, String languageCode) {
  final text = DateFormat.yMMMM(languageCode).format(DateTime(month.year, month.month));
  // `intl` écrit le mois en minuscule en français : majuscule en tête de
  // titre. Sans effet en arabe.
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Une ligne de la frise de l'Agenda : la date à gauche (le début en arabe),
/// la carte du rendez-vous à côté, avec son type, la mention de date
/// approximative et le compte à rebours.
class AgendaEventRow extends StatelessWidget {
  const AgendaEventRow({super.key, required this.event, required this.now, required this.onTap});

  final KhadaraEvent event;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = displayDateOf(event, now);
    final days = calendarDaysUntil(date, now);
    final approximate = event.showsApproximateDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBlock(date: date, approximate: approximate),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: AppColors.offWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.22)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ContentText(event.title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.ink)),
                      if (event.zawiyaName != null) ...[
                        const SizedBox(height: 2),
                        ContentText(event.zawiyaName!, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                      ],
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                _FactTag(khadaraEventTypeLabel(event.type, l10n),
                                    background: AppColors.emeraldSoft, foreground: AppColors.emerald),
                                if (approximate)
                                  StatePill(l10n.eventDetailDateApproximate, variant: StatePillVariant.todo),
                              ],
                            ),
                          ),
                          if (days >= 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              approximate ? l10n.khadaraAgendaInDaysApprox(days) : l10n.khadaraAgendaInDays(days),
                              style: TextStyle(fontSize: 12, color: AppColors.emerald),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Comprendre la Zawiya », en bas des Lieux (il était caché dans le menu
/// ⋮ de l'ancien écran).
class UnderstandingCard extends StatelessWidget {
  const UnderstandingCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.goldSoft,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.khadaraUnderstandingTitle,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                    Text(l10n.khadaraUnderstandingCardBody,
                        style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                  ],
                ),
              ),
              Text(l10n.khadaraUnderstandingCardAction,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.emerald)),
            ],
          ),
        ),
      ),
    );
  }
}
