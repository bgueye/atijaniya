import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_errors.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'open_in_maps.dart';
import 'zawiya_form_screen.dart';

/// Fiche détail d'une zawiya/daara — annuaire des zawiyas, priorité P1
/// (docs/03-architecture-ecrans.md). Modifier/supprimer réservés à un admin
/// (`canManageZawiyasProvider`) — voir `zawiya_form_screen.dart`.
class ZawiyaDetailScreen extends ConsumerStatefulWidget {
  const ZawiyaDetailScreen({super.key, required this.zawiya});

  final Zawiya zawiya;

  @override
  ConsumerState<ZawiyaDetailScreen> createState() => _ZawiyaDetailScreenState();
}

class _ZawiyaDetailScreenState extends ConsumerState<ZawiyaDetailScreen> {
  late Zawiya _zawiya = widget.zawiya;
  bool _deleting = false;

  Future<void> _editZawiya() async {
    final updated = await Navigator.of(context).push<Zawiya>(
      MaterialPageRoute(builder: (_) => ZawiyaFormScreen(zawiya: _zawiya)),
    );
    if (updated != null && mounted) setState(() => _zawiya = updated);
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.khadaraDeleteZawiyaConfirmTitle),
        content: Text(l10n.khadaraDeleteZawiyaConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.khadaraDeleteZawiyaConfirmAction, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(khadaraRepositoryProvider).deleteZawiya(_zawiya.id);
      ref.invalidate(zawiyasProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      final kind = classifyZawiyaDeleteError(error);
      final message = kind == ZawiyaDeleteErrorKind.blockedByReferences
          ? l10n.khadaraDeleteZawiyaBlockedByReferences
          : l10n.khadaraDeleteZawiyaError;
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
    final zawiya = _zawiya;
    final canManage = ref.watch(canManageZawiyasProvider);
    final upcoming = ref.watch(eventsForZawiyaProvider(zawiya.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(zawiya.name),
        actions: canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.khadaraEditZawiyaTooltip,
                  onPressed: _deleting ? null : _editZawiya,
                ),
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.khadaraDeleteZawiyaTooltip,
                  onPressed: _deleting ? null : _confirmDelete,
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (zawiya.description != null) ...[
            Text(
              zawiya.description!,
              style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.4),
            ),
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
