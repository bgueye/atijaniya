// Section « À venir » de l'accueil (refonte du 2026-11-01) : bandeau d'un
// direct en cours, puis les prochains évènements en liste datée. Placée en
// bas de page, juste au-dessus du don, à la demande du porteur de projet.
// Remplace `home_khadara_teaser_card.dart`, dont la vignette sans image
// n'était qu'un carré vert.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/network_section.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/event_detail_screen.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../khadara/presentation/live_stream_providers.dart';
import '../../khadara/presentation/live_stream_screen.dart';

/// Nombre d'évènements montrés : assez pour voir ce qui vient, sans faire de
/// l'accueil un calendrier (le calendrier complet est dans l'onglet Zawiyas).
const _maxEvents = 3;

class HomeUpcomingSection extends ConsumerWidget {
  const HomeUpcomingSection({super.key, required this.eventsAsync, required this.onRetry, required this.now});

  final AsyncValue<List<KhadaraEvent>> eventsAsync;
  final VoidCallback onRetry;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Un direct visible par le disciple (RLS) : annoncé en tête, rien en cas
    // d'échec — ce n'est qu'un raccourci, l'onglet Zawiyas les liste tous.
    final live = ref.watch(allLiveStreamsProvider).valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live.isNotEmpty) ...[
            _LiveBanner(stream: live.first),
            const SizedBox(height: 10),
          ],
          NetworkSection<List<KhadaraEvent>>(
            value: eventsAsync,
            placeholderHeight: 72,
            errorMessage: l10n.homeEventsLoadError,
            onRetry: onRetry,
            builder: (events) => events.isEmpty
                ? Notice.info(l10n.homeEventsEmpty, icon: Icons.event_outlined)
                : _EventList(events: events.take(_maxEvents).toList(), now: now),
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.stream});

  final LiveStream stream;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = stream.eventTitle ?? stream.groupName ?? '';
    return Material(
      color: AppColors.goldSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.sensors, size: 18, color: AppColors.emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: ContentText(
                    l10n.homeLiveNow(title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.ink),
                  ),
                ),
                DirectionalChevron(color: AppColors.bronze),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.now});

  final List<KhadaraEvent> events;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.bronze.withValues(alpha: 0.18)),
            _EventRow(event: events[i], now: now),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.now});

  final KhadaraEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = event.isRecurring ? (nextOccurrence(event, from: now) ?? event.startsAt) : event.startsAt;
    final zawiya = event.zawiyaName;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Jour et mois : l'information principale d'un évènement. Une date
            // approximative est précédée de « ~ » et dite en clair dessous
            // (`formatKhadaraEventSchedule`).
            DateBlock(date: date, approximate: event.showsApproximateDate),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentText(event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  ContentText(
                    [if (zawiya != null && zawiya.isNotEmpty) zawiya, formatKhadaraEventSchedule(event, l10n)]
                        .join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryInk),
                  ),
                ],
              ),
            ),
            DirectionalChevron(color: AppColors.bronze),
          ],
        ),
      ),
    );
  }
}
