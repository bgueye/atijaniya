import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_errors.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'open_in_maps.dart';
import 'zawiya_form_screen.dart';
import '../../../core/widgets/content_text.dart';

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
            child: Text(l10n.khadaraDeleteZawiyaConfirmAction, style: const TextStyle(color: AppColors.danger)),
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
          ..showSnackBar(SnackBar(content: ContentText(message)));
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
      // Pas de titre dans la barre : le nom est en tête de la fiche, en
      // entier (voir plus bas).
      appBar: AppBar(
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
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Nom du lieu en titre de la fiche, sur autant de lignes qu'il le
            // faut. Il n'était que dans la barre de titre, sur une ligne :
            // « Zawiya Tijaniyya d'El Maghrabilin, Le Caire (Égypte) » ne
            // tenait pas, et à 200 % même « Zawiya d'Aïn Madhi » était coupé,
            // sans aucun moyen de lire la suite (audit Zawiyas du 2026-10-25,
            // P2-5). Cormorant, police des titres et des noms de la charte.
            Semantics(
              header: true,
              child: ContentText(zawiya.name, style: AppTheme.titleText(fontSize: 26, color: AppColors.ink)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(zawiyaKindIcon(zawiya.kind), size: 18, color: AppColors.emerald),
                const SizedBox(width: 8),
                Text(
                  zawiyaKindLabel(zawiya.kind, l10n),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.secondaryInk),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (zawiya.description != null) ...[
              ContentText(
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
            // Bouton Maps avec des coordonnées, ou à défaut l'adresse (recherche
            // texte, comme pour un évènement) : 6 lieux sur 34 n'ont pas de
            // coordonnées mais tous ont une adresse, et n'avaient aucun bouton
            // (audit Zawiyas du 2026-10-25, P2-3).
            if (zawiya.hasLocation || zawiya.addressText != null) ...[
              const SizedBox(height: 12),
              // Juste au-dessus du bouton : c'est en suivant l'itinéraire que
              // l'approximation compte (audit Zawiyas du 2026-10-25, P2-2).
              if (zawiya.hasLocation && zawiya.coordinatesApproximate) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.bronze),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.khadaraApproximateLocation,
                        style: TextStyle(color: AppColors.secondaryInk, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => openInMaps(
                  context,
                  latitude: zawiya.latitude,
                  longitude: zawiya.longitude,
                  addressText: zawiya.addressText,
                ),
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
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              ),
              error: (err, st) => Text(l10n.khadaraLoadError, style: TextStyle(color: AppColors.secondaryInk)),
              data: (events) => events.isEmpty
                  ? Text(l10n.khadaraNoUpcomingEventsAtZawiya, style: TextStyle(color: AppColors.secondaryInk))
                  : Column(
                      children: [
                        for (final event in events)
                          Card(
                            child: ListTile(
                              leading: Icon(khadaraEventTypeIcon(event.type), color: AppColors.emerald),
                              title: ContentText(event.title),
                              subtitle: Text(formatKhadaraEventSchedule(event, l10n)),
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
      ),
    );
  }
}

/// Une information de la fiche (adresse, contact) : libellé traduit, puis
/// la valeur dessous.
///
/// Avant l'audit Zawiyas du 2026-10-25 (P1), un `RichText` réunissait les
/// deux sur une ligne : il n'appliquait pas la taille de texte choisie dans
/// les réglages (`TextScaler.noScaling` par défaut) ni la police du thème,
/// si bien qu'à 200 % l'adresse restait petite, en police système. Deux
/// `Text` ordinaires héritent des deux ; la valeur, souvent en français, passe
/// par `ContentText` pour son sens d'écriture, et le libellé n'a plus besoin
/// d'une ponctuation « : » figée à la française.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.text});

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Lu d'un seul tenant par TalkBack : « Adresse, Aïn Madhi… ».
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.bronze),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: const TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                ContentText(text, style: const TextStyle(color: AppColors.ink, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
