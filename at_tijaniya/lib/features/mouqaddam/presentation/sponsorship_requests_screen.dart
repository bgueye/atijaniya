import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mouqaddam_models.dart';
import 'mouqaddam_providers.dart';

/// Demandes de parrainage — côté mouqaddam vérifié : demandes reçues,
/// accepter/refuser. Priorité P2 (docs/03-architecture-ecrans.md).
///
/// Accessible depuis `ProfilScreen` uniquement quand `isVerifiedMouqaddamProvider`
/// vaut `true` ; la RLS `sponsorship_participants_only` refuse de toute
/// façon de renvoyer la moindre demande à un compte qui n'en est pas le
/// parrain sollicité. L'acceptation/le refus passent par la fonction
/// `SECURITY DEFINER` `respond_to_sponsorship` (jamais d'écriture directe
/// sur `mouqaddam_status`, qui n'a aucune policy UPDATE cliente).
class SponsorshipRequestsScreen extends ConsumerWidget {
  const SponsorshipRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(receivedSponsorshipRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mouqaddamRequestsTitle)),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.mouqaddamRequestsLoadError, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(receivedSponsorshipRequestsProvider),
                  child: Text(l10n.mouqaddamRetry),
                ),
              ],
            ),
          ),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.mouqaddamRequestsEmpty, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _RequestCard(request: requests[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.l10n});

  final SponsorshipRequest request;
  final AppLocalizations l10n;

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? l10n.mouqaddamRequestsAcceptConfirmTitle : l10n.mouqaddamRequestsRejectConfirmTitle),
        content: Text(accept ? l10n.mouqaddamRequestsAcceptConfirmBody : l10n.mouqaddamRequestsRejectConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.mouqaddamRequestsConfirmAction,
              style: TextStyle(color: accept ? AppColors.emerald : Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(mouqaddamRepositoryProvider).respondToSponsorship(requestId: request.id, accept: accept);
      ref.invalidate(receivedSponsorshipRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(accept ? l10n.mouqaddamRequestsSuccessAccepted : l10n.mouqaddamRequestsSuccessRejected)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamRequestsError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.emeraldSoft,
                  child: Icon(Icons.person_outline, color: AppColors.emerald),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(request.candidateName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                ),
              ],
            ),
            if (request.ijazaYear != null) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.mouqaddamRequestsYearLabel} : ${request.ijazaYear}',
                style: const TextStyle(color: AppColors.bronze, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _respond(context, ref, accept: false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: Text(l10n.mouqaddamRequestsReject),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _respond(context, ref, accept: true),
                  child: Text(l10n.mouqaddamRequestsAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
