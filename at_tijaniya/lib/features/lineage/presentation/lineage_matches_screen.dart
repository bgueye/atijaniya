import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/message_page.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/notice.dart';
import '../../../l10n/app_localizations.dart';
import '../../moderation/domain/moderation_models.dart';
import '../../moderation/presentation/report_content_dialog.dart';
import '../../profil/presentation/profile_providers.dart';
import '../../settings/presentation/privacy_settings_providers.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../domain/lineage_models.dart';
import 'lineage_providers.dart';
import 'lineage_screen.dart';
import '../../../core/widgets/content_text.dart';

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
      // `SafeArea` : sans elle, le bas de l'écran passait sous la barre de
      // navigation Android (3 boutons) — même défaut que sur « Rattraper son
      // wird », Conditions, Bienfaits, Paramètres et « Comprendre la Zawiya ».
      body: SafeArea(
        child: lineageAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => _ErrorState(
            error: error,
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
              loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (error, stackTrace) => _ErrorState(
                error: error,
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
      return Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (matchesAsync.hasError || requestsAsync.hasError) {
      return _ErrorState(
        error: matchesAsync.error ?? requestsAsync.error!,
        message: l10n.lineageMatchesLoadError,
        onRetry: () {
          ref.invalidate(lineageMatchesProvider);
          ref.invalidate(myConnectionRequestsProvider);
        },
      );
    }

    final matches = matchesAsync.value ?? [];
    final requests = requestsAsync.value ?? [];
    final received =
        requests.where((r) => r.recipientId == currentUserId && r.status == LineageConnectionStatus.pending).toList();
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
        ],
        if (matches.isNotEmpty) ...[
          _SectionHeader(title: l10n.lineageMatchesResultsSection),
          for (final match in matches) _MatchCard(match: match, existingRequest: byOtherUserId[match.userId]),
        ],
      ],
    );
  }
}

/// Titre de section du kit (`SectionTitle`), annoncé comme titre au lecteur
/// d'écran (mise au thème du kit, 2026-11-04 ; c'était un texte en gras sans
/// rôle de titre). Pas d'écart au-dessus du premier titre de la page.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SectionTitle(title, padding: const EdgeInsetsDirectional.fromSTEB(2, 16, 2, 8));
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
                CircleAvatar(
                  backgroundColor: AppColors.emeraldSoft,
                  child: Icon(Icons.person_outline, color: AppColors.emerald),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ContentText(request.otherUserName ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(Icons.flag_outlined, size: 20, color: AppColors.bronze),
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
                  // Contour `danger` comme le texte (il restait émeraude, 2026-11-05).
                  style: AppButtonStyles.outlineDanger,
                  child: Text(l10n.lineageMatchesDecline),
                ),
                const SizedBox(width: 8),
                // Action principale d'une carte : pilule `primary` du kit
                // (`FilledButton`), à côté de « Refuser » (mise au thème du kit).
                FilledButton(
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
          // `ResizeImage` — même raison que profil_screen.dart, diamètre
          // par défaut de CircleAvatar (40 = 2 × radius 20 implicite).
          backgroundImage: match.avatarUrl != null
              ? ResizeImage(
                  NetworkImage(match.avatarUrl!),
                  width: (40 * MediaQuery.of(context).devicePixelRatio).round(),
                  height: (40 * MediaQuery.of(context).devicePixelRatio).round(),
                )
              : null,
          child: match.avatarUrl == null ? Icon(Icons.person_outline, color: AppColors.emerald) : null,
        ),
        title: ContentText(match.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: match.transmissionYear != null ? ContentText('${match.transmissionYear}') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingRequest != null)
              IconButton(
                icon: Icon(Icons.flag_outlined, size: 20, color: AppColors.bronze),
                tooltip: l10n.moderationReportAction,
                onPressed: () => showReportContentDialog(
                  context,
                  ref,
                  contentType: ReportableContentType.lineageConnectionRequest,
                  contentId: existingRequest!.id,
                ),
              ),
            if (statusLabel != null)
              // L'état de la demande en pastille du kit (texte bronze
              // auparavant, sous le seuil AA) : acceptée en « fait », les
              // autres neutres.
              StatePill(
                statusLabel,
                variant: existingRequest?.status == LineageConnectionStatus.accepted
                    ? StatePillVariant.done
                    : StatePillVariant.neutral,
              )
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

/// Page sans résultat ou bloquée (pas de lignée, lignée non visible, aucun
/// condisciple) : ce qui manque, puis l'action qui le règle, en page
/// partagée du kit (`MessagePage`, mise au thème du kit, 2026-11-04).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.body, this.ctaLabel, this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MessagePage(
      icon: icon,
      title: title,
      body: body,
      action: ctaLabel == null ? null : OutlinedButton(onPressed: onTap, child: ContentText(ctaLabel!)),
    );
  }
}

/// Erreur de chargement : la carte d'erreur du kit (`Notice`), hors ligne ou
/// non, avec « Réessayer ».
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.message, required this.onRetry});

  final Object error;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => NoticeBody(Notice.fromError(error, message: message, onRetry: onRetry));
}
