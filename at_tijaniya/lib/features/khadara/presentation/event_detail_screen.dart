import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/khadara_models.dart';
import 'khadara_format.dart';
import 'live_stream_providers.dart';
import 'live_stream_screen.dart';
import 'open_in_maps.dart';
import 'start_live_stream_screen.dart';

/// Détail d'un évènement Khadara — lieu, date, description, et
/// rejoindre/démarrer un direct (P2, docs/03-architecture-ecrans.md :
/// écran "Direct") si l'évènement en a un.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: 24),
          _LiveStreamSection(event: event, l10n: l10n),
        ],
      ),
    );
  }
}

/// Rejoindre le direct en cours pour cet évènement, ou en démarrer un —
/// invisible tant que le direct n'est pas encore chargé ou en erreur (pas
/// de reprise dédiée ici, `khadaraLoadError` de l'onglet Directs couvre
/// déjà ce cas ailleurs) : ne bloque jamais la lecture du reste de la
/// fiche évènement.
class _LiveStreamSection extends ConsumerWidget {
  const _LiveStreamSection({required this.event, required this.l10n});

  final KhadaraEvent event;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(latestStreamForEventProvider(event.id));
    final myUserId = ref.watch(currentUserIdProvider);

    return streamAsync.maybeWhen(
      data: (stream) {
        final isActive = stream != null && stream.status != LiveStreamStatus.ended;
        if (isActive) {
          return FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)),
            ),
            icon: const Icon(Icons.podcasts),
            label: Text(l10n.khadaraJoinLive),
          );
        }
        if (myUserId == null) return const SizedBox.shrink();
        return OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StartLiveStreamScreen.forEvent(eventId: event.id, contextTitle: event.title)),
          ),
          icon: const Icon(Icons.podcasts_outlined),
          label: Text(l10n.khadaraStartLive),
        );
      },
      orElse: () => const SizedBox.shrink(),
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
