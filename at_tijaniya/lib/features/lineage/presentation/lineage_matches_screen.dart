import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/report_content_dialog.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../settings/presentation/privacy_settings_providers.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../domain/lineage_models.dart';
import 'lineage_providers.dart';
import 'lineage_screen.dart';

/// Retrouver mes condisciples — mise en relation par correspondance de lignée
/// spirituelle. Priorité P1 (docs/03-architecture-ecrans.md).
///
/// RAPPEL SENSIBILITÉ (CLAUDE.md, docs/01 § 5.4.1, confirmé validé par le
/// porteur de projet le 2026-08-08) : `search_lineage_matches()` (fonction
/// `SECURITY DEFINER`, voir `lineage_repository.dart`) ne renvoie jamais
/// qu'un aperçu minimal (prénom affiché, avatar, année) d'un disciple ayant
/// lui aussi activé la visibilité de sa lignée ET dont le foyer + nom du
/// moqaddam correspondent (trigram, tolérant aux variantes orthographiques)
/// — jamais un annuaire général, jamais le nom du moqaddam de l'autre
/// disciple. La mise en relation complète (ce que "complète" débloque : la
/// visibilité mutuelle du profil, déjà publique par ailleurs — les
/// lignées elles-mêmes restent strictement privées de part et d'autre)
/// n'a lieu qu'après acceptation explicite du destinataire.
class LineageMatchesScreen extends ConsumerWidget {
  const LineageMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lineageAsync = ref.watch(myLineageProvider);
    final privacyAsync = ref.watch(myPrivacySettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lineageMatchesTitle)),
      body: lineageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => _ErrorState(
          message: l10n.lineageMatchesLoadError,
          onRetry: () => ref.invalidate(myLineageProvider),
        ),
        data: (lineage) {
          if (lineage == null) {
            return _EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: l10n.lineageMatchesNoLineageTitle,
              body: l10n.lineageMatchesNoLineageBody,
              ctaLabel: l10n.lineageMatchesGoToLineageCta,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LineageScreen())),
            );
          }
          return privacyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
            error: (error, stackTrace) => _ErrorState(
              message: l10n.lineageMatchesLoadError,
              onRetry: () => ref.invalidate(myPrivacySettingsProvider),
            ),
            data: (privacy) {
              if (!privacy.lineageVisible) {
                return _EmptyState(
                  icon: Icons.visibility_off_outlined,
                  title: l10n.lineageMatchesNotVisibleTitle,
                  body: l10n.lineageMatchesNotVisibleBody,
                  ctaLabel: l10n.lineageMatchesGoToPrivacyCta,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                  ),
                );
              }
              return const _MatchesBody();
            },
          );
        },
      ),
    );
  }
}

class _MatchesBody extends ConsumerWidget {
  const _MatchesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchesAsync = ref.watch(lineageMatchesProvider);
    final requestsAsync = ref.watch(myConnectionRequestsProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    if (matchesAsync.isLoading || requestsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (matchesAsync.hasError || requestsAsync.hasError) {
      return _ErrorState(
        message: l10n.lineageMatchesLoadError,
        onRetry: () {
          ref.invalidate(lineageMatchesProvider);
          ref.invalidate(myConnectionRequestsProvider);
        },
      );
    }

    final matches = matchesAsync.value ?? [];
    final requests = requestsAsync.value ?? [];
    final received = requests.where((r) => r.recipientId == currentUserId && r.status == LineageConnectionStatus.pending).toList();
    final byOtherUserId = <String, LineageConnectionRequest>{
      for (final r in requests) (r.requesterId == currentUserId ? r.recipientId : r.requesterId): r,
    };

    if (received.isEmpty && matches.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline,
        title: l10n.lineageMatchesEmptyTitle,
        body: l10n.lineageMatchesEmptyBody,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (received.isNotEmpty) ...[
          _SectionHeader(title: l10n.lineageMatchesReceivedSection),
          for (final request in received) _ReceivedRequestCard(request: request),
          const SizedBox(height: 16),
        ],
        if (matches.isNotEmpty) ...[
          _SectionHeader(title: l10n.lineageMatchesResultsSection),
          for (final match in matches) _MatchCard(match: match, existingRequest: byOtherUserId[match.userId]),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
    );
  }
}

class _ReceivedRequestCard extends ConsumerWidget {
  const _ReceivedRequestCard({required this.request});

  final LineageConnectionRequest request;

  Future<void> _respond(BuildContext context, WidgetRef ref, AppLocalizations l10n, {required bool accept}) async {
    try {
      await ref.read(lineageRepositoryProvider).respondToConnectionRequest(requestId: request.id, accept: accept);
      ref.invalidate(myConnectionRequestsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.lineageMatchesRespondError)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
                  child: Text(request.otherUserName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.bronze),
                  tooltip: l10n.moderationReportAction,
                  onPressed: () => showReportContentDialog(
                    context,
                    ref,
                    contentType: ReportableContentType.lineageConnectionRequest,
                    contentId: request.id,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _respond(context, ref, l10n, accept: false),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: Text(l10n.lineageMatchesDecline),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _respond(context, ref, l10n, accept: true),
                  child: Text(l10n.lineageMatchesAccept),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.match, this.existingRequest});

  final LineageMatch match;
  final LineageConnectionRequest? existingRequest;

  Future<void> _sendRequest(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    try {
      await ref.read(lineageRepositoryProvider).sendConnectionRequest(match.userId);
      ref.invalidate(myConnectionRequestsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.lineageMatchesConnectError)));
      }
    }
  }

  String? _statusLabel(AppLocalizations l10n) {
    switch (existingRequest?.status) {
      case LineageConnectionStatus.pending:
        return l10n.lineageMatchesStatusPending;
      case LineageConnectionStatus.accepted:
        return l10n.lineageMatchesStatusAccepted;
      case LineageConnectionStatus.declined:
        return l10n.lineageMatchesStatusDeclined;
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statusLabel = _statusLabel(l10n);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.emeraldSoft,
          backgroundImage: match.avatarUrl != null ? NetworkImage(match.avatarUrl!) : null,
          child: match.avatarUrl == null ? const Icon(Icons.person_outline, color: AppColors.emerald) : null,
        ),
        title: Text(match.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: match.transmissionYear != null ? Text('${match.transmissionYear}') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingRequest != null)
              IconButton(
                icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.bronze),
                tooltip: l10n.moderationReportAction,
                onPressed: () => showReportContentDialog(
                  context,
                  ref,
                  contentType: ReportableContentType.lineageConnectionRequest,
                  contentId: existingRequest!.id,
                ),
              ),
            if (statusLabel != null)
              Text(statusLabel, style: const TextStyle(color: AppColors.bronze, fontSize: 13))
            else
              OutlinedButton(
                onPressed: () => _sendRequest(context, ref, l10n),
                child: Text(l10n.lineageMatchesConnectButton),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body, this.ctaLabel, this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.bronze, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
            if (ctaLabel != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(onPressed: onTap, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.bronze)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.lineageMatchesRetry)),
          ],
        ),
      ),
    );
  }
}
