import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'khadara_understanding_screen.dart';
import 'live_stream_providers.dart';
import 'live_stream_screen.dart';
import 'zawiya_detail_screen.dart';

/// Module Khadara — calendrier des évènements et annuaire des zawiyas.
/// Priorité P1 (docs/03-architecture-ecrans.md).
///
/// Contrairement aux modules Wirds/Figures, ce contenu vient des tables
/// Supabase `zawiyas`/`events` (lecture publique, docs/06-architecture-backend.md)
/// et non d'un fichier de contenu statique : les listes sont donc vides tant
/// qu'aucun évènement/zawiya n'a été saisi par un administrateur, ce qui est
/// le cas actuellement (base fraîchement provisionnée).
///
/// Portée volontairement réduite pour cette itération (voir
/// `open_in_maps.dart`) : liste uniquement, pas de carte interactive
/// intégrée — un bouton "Ouvrir dans Maps" couvre le besoin de
/// géolocalisation en s'appuyant sur l'app de plans du téléphone.
class KhadaraScreen extends StatelessWidget {
  const KhadaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  labelColor: AppColors.emerald,
                  unselectedLabelColor: AppColors.bronze,
                  indicatorColor: AppColors.emerald,
                  tabs: [
                    Tab(text: l10n.khadaraEventsTab),
                    Tab(text: l10n.khadaraZawiyasTab),
                    Tab(text: l10n.khadaraLiveTab),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.bronze),
                tooltip: l10n.khadaraUnderstandingTooltip,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KhadaraUnderstandingScreen()),
                ),
              ),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _EventsTab(),
                _ZawiyasTab(),
                _LiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final events = ref.watch(upcomingEventsProvider);
    final canCreate = ref.watch(canCreateEventProvider);

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.khadaraCreateEventButton),
            )
          : null,
      body: _AsyncSection<KhadaraEvent>(
        value: events,
        emptyMessage: l10n.khadaraNoEvents,
        onRetry: () => ref.invalidate(upcomingEventsProvider),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemBuilder: (context, event) => Card(
          child: ListTile(
            leading: event.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      event.imageUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      // alignment: topCenter — le sujet d'une photo d'évènement est
                      // rarement centré verticalement ; un centrage strict coupe
                      // souvent la partie utile sur une miniature aussi petite.
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(khadaraEventTypeIcon(event.type), color: AppColors.emerald),
                    ),
                  )
                : Icon(khadaraEventTypeIcon(event.type), color: AppColors.emerald),
            title: Text(event.title),
            subtitle: Text(
              event.zawiyaName != null
                  ? '${formatKhadaraDateTime(event.startsAt)} · ${event.zawiyaName}'
                  : formatKhadaraDateTime(event.startsAt),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZawiyasTab extends ConsumerWidget {
  const _ZawiyasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final zawiyas = ref.watch(zawiyasProvider);

    return _AsyncSection<Zawiya>(
      value: zawiyas,
      emptyMessage: l10n.khadaraNoZawiyas,
      onRetry: () => ref.invalidate(zawiyasProvider),
      itemBuilder: (context, zawiya) => Card(
        child: ListTile(
          leading: const Icon(Icons.mosque_outlined, color: AppColors.emerald),
          title: Text(zawiya.name),
          subtitle: zawiya.addressText != null
              ? Text(zawiya.addressText!, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ZawiyaDetailScreen(zawiya: zawiya)),
          ),
        ),
      ),
    );
  }
}

/// Directs en cours + rediffusions — regroupe les deux écrans "Direct" et
/// "Rediffusions" du docs/03-architecture-ecrans.md dans un seul onglet
/// (même logique de sobriété d'arborescence que les onglets de
/// `FigureDetailScreen` : deux contenus liés plutôt que deux écrans
/// top-level séparés). Sections indépendantes (chacune son propre
/// chargement/erreur/vide) plutôt qu'un `_AsyncSection` unique : deux
/// providers différents à combiner sur un seul écran.
class _LiveTab extends ConsumerWidget {
  const _LiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final liveStreams = ref.watch(allLiveStreamsProvider);
    final replays = ref.watch(streamReplaysProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.khadaraLiveNowSection, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
        const SizedBox(height: 8),
        liveStreams.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => OutlinedButton(
            onPressed: () => ref.invalidate(allLiveStreamsProvider),
            child: Text(l10n.khadaraRetry),
          ),
          data: (streams) => streams.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.khadaraNoLiveNow, style: const TextStyle(color: AppColors.bronze)),
                )
              : Column(
                  children: streams
                      .map(
                        (stream) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.podcasts, color: AppColors.emerald),
                            title: Text(stream.displayTitle(l10n.khadaraLiveTab)),
                            subtitle: Text(l10n.khadaraLiveBadge),
                            trailing: const Icon(Icons.chevron_right, color: AppColors.bronze),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        Text(l10n.khadaraReplaysSection, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
        const SizedBox(height: 8),
        replays.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => OutlinedButton(
            onPressed: () => ref.invalidate(streamReplaysProvider),
            child: Text(l10n.khadaraRetry),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.khadaraNoReplays, style: const TextStyle(color: AppColors.bronze)),
                )
              : Column(
                  children: list
                      .map(
                        (replay) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.play_circle_outline, color: AppColors.emerald),
                            title: Text(replay.displayTitle(l10n.khadaraLiveTab)),
                            trailing: const Icon(Icons.open_in_new, color: AppColors.bronze),
                            onTap: () async {
                              final uri = Uri.tryParse(replay.videoUrl);
                              final launched = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!launched && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.khadaraOpenReplayError)),
                                );
                              }
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

/// Chargement/erreur (avec reprise)/vide/données — factorisé pour les deux
/// onglets (Évènements, Zawiyas), qui partagent exactement la même forme.
class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.value,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.onRetry,
    this.padding = const EdgeInsets.all(16),
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final VoidCallback onRetry;

  /// Padding de la liste de résultats — personnalisable pour laisser de la
  /// place à un FAB (voir `_EventsTab`) sans affecter les autres onglets.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(l10n.khadaraLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.khadaraRetry)),
            ],
          ),
        ),
      ),
      data: (items) => items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              ),
            )
          : ListView.builder(
              padding: padding,
              itemCount: items.length,
              itemBuilder: (context, i) => itemBuilder(context, items[i]),
            ),
    );
  }
}
