import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
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
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.emerald,
            unselectedLabelColor: AppColors.bronze,
            indicatorColor: AppColors.emerald,
            tabs: [
              Tab(text: l10n.khadaraEventsTab),
              Tab(text: l10n.khadaraZawiyasTab),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _EventsTab(),
                _ZawiyasTab(),
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

    return _AsyncSection<KhadaraEvent>(
      value: events,
      emptyMessage: l10n.khadaraNoEvents,
      onRetry: () => ref.invalidate(upcomingEventsProvider),
      itemBuilder: (context, event) => Card(
        child: ListTile(
          leading: Icon(khadaraEventTypeIcon(event.type), color: AppColors.emerald),
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

/// Chargement/erreur (avec reprise)/vide/données — factorisé pour les deux
/// onglets (Évènements, Zawiyas), qui partagent exactement la même forme.
class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.value,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.onRetry,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final VoidCallback onRetry;

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
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) => itemBuilder(context, items[i]),
            ),
    );
  }
}
