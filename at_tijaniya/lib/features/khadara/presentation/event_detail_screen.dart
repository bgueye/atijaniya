import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/khadara_errors.dart';
import '../domain/khadara_models.dart';
import 'event_form_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'live_stream_providers.dart';
import 'live_stream_screen.dart';
import 'open_in_maps.dart';
import 'start_live_stream_screen.dart';

/// Détail d'un évènement Khadara — lieu, date, description, et
/// rejoindre/démarrer un direct (P2, docs/03-architecture-ecrans.md :
/// écran "Direct") si l'évènement en a un. Modifier/supprimer réservés à
/// l'auteur ou à un admin (`canManageEvent`) — voir `event_form_screen.dart`.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final KhadaraEvent event;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late KhadaraEvent _event = widget.event;
  bool _deleting = false;

  Future<void> _editEvent() async {
    final updated = await Navigator.of(context).push<KhadaraEvent>(
      MaterialPageRoute(builder: (_) => EventFormScreen(event: _event)),
    );
    if (updated != null && mounted) setState(() => _event = updated);
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.khadaraDeleteEventConfirmTitle),
        content: Text(l10n.khadaraDeleteEventConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.khadaraDeleteEventConfirmAction,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(khadaraRepositoryProvider).deleteEvent(_event.id);
      ref.invalidate(upcomingEventsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      final kind = classifyEventDeleteError(error);
      final message = kind == EventDeleteErrorKind.blockedByLiveStream
          ? l10n.khadaraDeleteEventBlockedByLiveStream
          : l10n.khadaraDeleteEventError;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canManage = canManageEvent(
      _event,
      userId: ref.watch(currentUserIdProvider),
      isAdmin: ref.watch(isAdminProvider),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.title),
        actions: canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.khadaraEditEventTooltip,
                  onPressed: _deleting ? null : _editEvent,
                ),
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.khadaraDeleteEventTooltip,
                  onPressed: _deleting ? null : _confirmDelete,
                ),
              ]
            : null,
      ),
      // `SafeArea` : évite que le bouton Démarrer un direct se retrouve
      // masqué sous la barre de navigation Android (3 boutons).
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_event.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _event.imageUrl!,
                  // Pas de hauteur fixe : la largeur remplit l'écran et la
                  // hauteur s'ajuste au ratio réel de la photo, plutôt que de
                  // recadrer/deviner une hauteur qui coupe une partie de
                  // l'image selon son orientation.
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Chip(
              avatar: Icon(khadaraEventTypeIcon(_event.type),
                  size: 18, color: AppColors.emerald),
              label: Text(khadaraEventTypeLabel(_event.type, l10n)),
              backgroundColor: AppColors.emeraldSoft,
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.schedule,
              text: _event.endsAt == null
                  ? formatKhadaraDateTime(_event.startsAt)
                  : '${formatKhadaraDateTime(_event.startsAt)} → ${formatKhadaraDateTime(_event.endsAt!)}',
            ),
            if (_event.zawiyaName != null) ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.mosque_outlined, text: _event.zawiyaName!),
            ],
            if (_event.description != null) ...[
              const SizedBox(height: 20),
              Text(
                _event.description!,
                style: const TextStyle(
                    color: AppColors.ink, fontSize: 16, height: 1.4),
              ),
            ],
            if (_event.hasLocation) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => openInMaps(context,
                    latitude: _event.latitude!, longitude: _event.longitude!),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.khadaraOpenInMaps),
              ),
            ],
            const SizedBox(height: 24),
            _LiveStreamSection(event: _event, l10n: l10n),
          ],
        ),
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
        final isActive =
            stream != null && stream.status != LiveStreamStatus.ended;
        if (isActive) {
          return FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => LiveStreamScreen(stream: stream)),
            ),
            icon: const Icon(Icons.podcasts),
            label: Text(l10n.khadaraJoinLive),
          );
        }
        if (myUserId == null) return const SizedBox.shrink();
        return OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => StartLiveStreamScreen.forEvent(
                    eventId: event.id, contextTitle: event.title)),
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
        Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.ink))),
      ],
    );
  }
}
