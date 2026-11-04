import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/list_group.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
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
import 'zawiya_detail_screen.dart';
import '../../../core/widgets/content_text.dart';

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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.profileCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.khadaraDeleteEventConfirmAction, style: const TextStyle(color: AppColors.danger)),
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
          ..showSnackBar(SnackBar(content: ContentText(message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final event = _event;
    final canManage = canManageEvent(
      event,
      userId: ref.watch(currentUserIdProvider),
      isAdmin: ref.watch(isAdminProvider),
      managedZawiyaId: ref.watch(myManagedZawiyaIdProvider),
    );
    // La fiche du lieu, si la zawiya est connue (liste déjà chargée par
    // l'onglet Zawiyas ; sinon, le lieu reste une ligne sans lien).
    final zawiya = event.zawiyaId == null
        ? null
        : ref.watch(zawiyasProvider).valueOrNull?.where((z) => z.id == event.zawiyaId).firstOrNull;
    final address = event.addressText ?? zawiya?.addressText;
    final note = event.dateNote?.trim();
    const sectionPadding = EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8);

    return Scaffold(
      appBar: AppBar(
        actions: canManage
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.khadaraEditEventTooltip,
                  onPressed: _deleting ? null : _editEvent,
                ),
                IconButton(
                  icon: _deleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.khadaraDeleteEventTooltip,
                  onPressed: _deleting ? null : _confirmDelete,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _EventHero(event: event),
            if (event.imageUrl != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  event.imageUrl!,
                  cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (event.zawiyaName != null || address != null) ...[
              SectionTitle(l10n.eventDetailPlace, padding: sectionPadding),
              // Le lieu mène à sa fiche (refonte du 2026-11-02 : avant, le nom
              // de la zawiya n'était qu'un texte).
              ListGroup(items: [
                ListGroupItem(
                  icon: zawiya == null ? Icons.place_outlined : zawiyaKindIcon(zawiya.kind),
                  title: event.zawiyaName ?? address!,
                  subtitle: event.zawiyaName == null ? null : address,
                  onTap: zawiya == null
                      ? null
                      : () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => ZawiyaDetailScreen(zawiya: zawiya))),
                ),
              ]),
            ],
            // Coordonnées ou adresse de l'évènement, sinon celles de sa zawiya :
            // l'adresse affichée retombait déjà sur celle-ci, sans bouton
            // pour l'ouvrir (audit du 2026-11-03).
            if (event.hasMapsTarget || (zawiya != null && (zawiya.hasLocation || address != null))) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openInMaps(
                  context,
                  latitude: event.hasLocation ? event.latitude : zawiya?.latitude,
                  longitude: event.hasLocation ? event.longitude : zawiya?.longitude,
                  addressText: address,
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(l10n.khadaraOpenInMaps),
              ),
            ],
            if (event.description != null || (note != null && note.isNotEmpty)) ...[
              SectionTitle(l10n.eventDetailAbout, padding: sectionPadding),
              if (event.description != null)
                ContentText(
                    alignToContent: true,
                    event.description!,
                    style: const TextStyle(color: AppColors.ink, fontSize: 15.5, height: 1.5)),
              // La note qui explique comment la date est fixée, mise en avant
              // au lieu de se perdre dans la description.
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DateNote(note: note),
              ],
            ],
            SectionTitle(l10n.eventDetailLive, padding: sectionPadding),
            _LiveStreamSection(event: event, l10n: l10n, isPast: isEventPast(event)),
          ],
        ),
      ),
    );
  }
}

/// En-tête : la date d'abord. Grand bloc date (la prochaine occurrence pour
/// un évènement récurrent), type en pastille, titre, jour et heure, compte à
/// rebours et, si c'est le cas, « Date approximative ».
class _EventHero extends StatelessWidget {
  const _EventHero({required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final date = event.isRecurring ? (nextOccurrence(event, from: now) ?? event.startsAt) : event.startsAt;
    // Jours de calendrier comptés en UTC : en heure locale, un passage à
    // l'heure d'été donne 23 h de moins et `inDays` perdait un jour.
    final days =
        DateTime.utc(date.year, date.month, date.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    // Évènement terminé (audit du 2026-11-03) : « Passé » à la place du
    // compte à rebours, qui disparaissait sans rien dire.
    final past = isEventPast(event, now: now);
    final schedule = event.isRecurring || event.showsApproximateDate
        ? formatKhadaraEventSchedule(event, l10n)
        : (event.endsAt == null
            ? formatKhadaraDateTime(event.startsAt)
            : '${formatKhadaraDateTime(event.startsAt)} → ${formatKhadaraDateTime(event.endsAt!)}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bloc date en grand : jour, mois et année, chiffres latins.
              Semantics(
                label: DateFormat.yMMMMd(locale).format(date),
                excludeSemantics: true,
                child: Container(
                  width: 76,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Text(
                        '${event.showsApproximateDate ? '~' : ''}${date.day}',
                        textDirection: TextDirection.ltr,
                        style: AppTheme.titleText(fontSize: 38, color: AppColors.emerald, height: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMM(locale).format(date),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: AppColors.emerald),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatePill(khadaraEventTypeLabel(event.type, l10n), variant: StatePillVariant.todo),
                    const SizedBox(height: 6),
                    Semantics(
                      header: true,
                      child: ContentText(
                        event.title,
                        style: AppTheme.titleText(fontSize: 23, color: AppColors.ink, height: 1.15),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ContentText(schedule, style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.secondaryInk)),
                  ],
                ),
              ),
            ],
          ),
          if (days >= 0 || event.showsApproximateDate || past) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (past)
                  StatePill(l10n.eventDetailPast, variant: StatePillVariant.neutral)
                else if (days >= 0)
                  // « environ » seulement pour une date approximative (audit
                  // du 2026-11-03).
                  StatePill(
                    event.showsApproximateDate ? l10n.eventDetailCountdown(days) : l10n.khadaraNextCountdown(days),
                    variant: StatePillVariant.neutral,
                  ),
                if (event.showsApproximateDate)
                  StatePill(l10n.eventDetailDateApproximate, variant: StatePillVariant.todo),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// « Date à confirmer. » et le texte de la base qui explique comment la date
/// est fixée.
class _DateNote extends StatelessWidget {
  const _DateNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_note_outlined, size: 18, color: AppColors.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.eventDetailDateToConfirm,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 2),
                ContentText(
                    alignToContent: true,
                    note,
                    style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Direct : rejoindre s'il est en cours, le démarrer pour qui en a le droit
/// (mêmes règles qu'avant), sinon une place fixe qui dit qu'il apparaîtra ici.
class _LiveStreamSection extends ConsumerWidget {
  const _LiveStreamSection({required this.event, required this.l10n, required this.isPast});

  final KhadaraEvent event;
  final AppLocalizations l10n;

  /// Évènement terminé (`isEventPast`) : plus de « Il apparaîtra ici dès
  /// qu'il commence » ni de « Démarrer un direct » (audit du 2026-11-03 : un
  /// évènement passé s'ouvre depuis la fiche d'une figure, qui liste aussi
  /// les évènements anciens). Un direct encore en cours reste joignable.
  final bool isPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamAsync = ref.watch(latestStreamForEventProvider(event.id));
    // Lecture du direct impossible (hors ligne) : le dire, au lieu de « Pas de
    // direct pour l'instant », faux si un direct est en cours (audit du
    // 2026-11-03).
    if (streamAsync.hasError && !streamAsync.hasValue) {
      return Notice.fromError(
        streamAsync.error!,
        message: l10n.figuresLoadError,
        onRetry: () => ref.invalidate(latestStreamForEventProvider(event.id)),
      );
    }
    final stream = streamAsync.valueOrNull;
    final myUserId = ref.watch(currentUserIdProvider);
    if (stream != null && stream.status != LiveStreamStatus.ended) {
      return FilledButton.icon(
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream))),
        icon: const Icon(Icons.podcasts),
        label: Text(l10n.khadaraJoinLive),
      );
    }
    final managedZawiyaId = ref.watch(myManagedZawiyaIdProvider);
    final canStart = myUserId != null &&
        (ref.watch(isAdminProvider) ||
            myUserId == event.createdBy ||
            (managedZawiyaId != null && managedZawiyaId == event.zawiyaId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(items: [
          ListGroupItem(
            icon: Icons.podcasts_outlined,
            tone: ListGroupTone.sacred,
            title: isPast ? l10n.eventDetailPastNoLive : l10n.eventDetailNoLive,
            subtitle: isPast ? null : l10n.eventDetailNoLiveHint,
          ),
        ]),
        if (canStart && !isPast) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => StartLiveStreamScreen.forEvent(eventId: event.id, contextTitle: event.title)),
            ),
            icon: const Icon(Icons.podcasts_outlined, size: 18),
            label: Text(l10n.khadaraStartLive),
          ),
        ],
      ],
    );
  }
}
