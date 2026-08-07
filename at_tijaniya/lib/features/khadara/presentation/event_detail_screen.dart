import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'khadara_format.dart';
import 'open_in_maps.dart';

/// Détail d'un évènement Khadara — lieu, date, description. Priorité P1
/// (docs/03-architecture-ecrans.md). "Rejoindre/démarrer un direct" (P2)
/// n'est pas dans ce périmètre : voir docs/03, module Khadara, écran
/// "Direct".
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Chip(
            avatar: Icon(khadaraEventTypeIcon(event.type), size: 18, color: AppColors.emerald),
            label: Text(khadaraEventTypeLabel(event.type, l10n)),
            backgroundColor: AppColors.emeraldSoft,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.schedule,
            text: event.endsAt == null
                ? formatKhadaraDateTime(event.startsAt)
                : '${formatKhadaraDateTime(event.startsAt)} → ${formatKhadaraDateTime(event.endsAt!)}',
          ),
          if (event.zawiyaName != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.mosque_outlined, text: event.zawiyaName!),
          ],
          if (event.description != null) ...[
            const SizedBox(height: 20),
            Text(
              event.description!,
              style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
            ),
          ],
          if (event.hasLocation) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => openInMaps(context, latitude: event.latitude!, longitude: event.longitude!),
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.khadaraOpenInMaps),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.bronze),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.ink))),
      ],
    );
  }
}
