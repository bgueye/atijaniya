import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'open_in_maps.dart';

/// Fiche détail d'une zawiya/daara — annuaire des zawiyas, priorité P1
/// (docs/03-architecture-ecrans.md).
class ZawiyaDetailScreen extends ConsumerWidget {
  const ZawiyaDetailScreen({super.key, required this.zawiya});

  final Zawiya zawiya;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final upcoming = ref.watch(eventsForZawiyaProvider(zawiya.id));

    return Scaffold(
      appBar: AppBar(title: Text(zawiya.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (zawiya.description != null) ...[
            Text(zawiya.description!, style: const TextStyle(color: AppColors.ink, height: 1.4)),
            const SizedBox(height: 16),
          ],
          if (zawiya.addressText != null) ...[
            _InfoRow(icon: Icons.place_outlined, label: l10n.khadaraAddressLabel, text: zawiya.addressText!),
            const SizedBox(height: 8),
          ],
          if (zawiya.contactInfo != null) ...[
            _InfoRow(icon: Icons.call_outlined, label: l10n.khadaraContactLabel, text: zawiya.contactInfo!),
            const SizedBox(height: 8),
          ],
          if (zawiya.hasLocation) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openInMaps(context, latitude: zawiya.latitude!, longitude: zawiya.longitude!),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.khadaraOpenInMaps),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            l10n.khadaraUpcomingEventsAtZawiya,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          upcoming.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            ),
            error: (err, st) => Text(l10n.khadaraLoadError, style: const TextStyle(color: AppColors.bronze)),
            data: (events) => events.isEmpty
                ? Text(l10n.khadaraNoUpcomingEventsAtZawiya, style: const TextStyle(color: AppColors.bronze))
                : Column(
                    children: [
                      for (final event in events)
                        Card(
                          child: ListTile(
                            leading: Icon(khadaraEventTypeIcon(event.type), color: AppColors.emerald),
                            title: Text(event.title),
                            subtitle: Text(formatKhadaraDateTime(event.startsAt)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.text});

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.bronze),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.ink, fontSize: 14),
              children: [
                TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
