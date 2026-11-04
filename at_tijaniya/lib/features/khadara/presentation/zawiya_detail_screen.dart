import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/date_block.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/state_pill.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../figures/domain/figure_errors.dart';
import '../../figures/domain/figure_models.dart';
import '../../figures/presentation/figure_cards.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/contact_links.dart';
import '../domain/khadara_errors.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import '../../figures/presentation/figures_providers.dart';
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
      // Les évènements et la fiche d'une figure (lieux rattachés, supprimés
      // en cascade) montraient encore le lieu supprimé (audit Zawiyas du
      // 2026-10-25, P3-5).
      ref.invalidate(upcomingEventsProvider);
      ref.invalidate(linkedZawiyasForFigureProvider);
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
    final successions = ref.watch(successionsForZawiyaProvider(zawiya.id)).valueOrNull ?? const <ZawiyaSuccession>[];
    final linkedFigures = ref.watch(figuresForZawiyaProvider(zawiya.id)).valueOrNull ?? const <Figure>[];
    final founder = successions.isEmpty ? null : successions.first;
    final hasPlace = zawiya.hasLocation || zawiya.addressText != null;
    const sectionPadding = EdgeInsetsDirectional.fromSTEB(2, 24, 0, 8);

    return Scaffold(
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
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline),
                  tooltip: l10n.khadaraDeleteZawiyaTooltip,
                  onPressed: _deleting ? null : _confirmDelete,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // En-tête clair : une zawiya n'est pas un écran de pratique
            // (pas de zaytoune, CLAUDE.md § Design system).
            Eyebrow(zawiyaKindLabel(zawiya.kind, l10n)),
            const SizedBox(height: 2),
            Semantics(
              header: true,
              child:
                  ContentText(zawiya.name, style: AppTheme.titleText(fontSize: 28, color: AppColors.ink, height: 1.15)),
            ),
            if (zawiya.description != null) ...[
              const SizedBox(height: 10),
              ContentText(
                  alignToContent: true,
                  zawiya.description!,
                  style: const TextStyle(color: AppColors.ink, fontSize: 15.5, height: 1.5)),
            ],
            if (zawiya.addressText != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: AppColors.bronze),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Semantics(
                      label: '${l10n.khadaraAddressLabel}, ${zawiya.addressText}',
                      excludeSemantics: true,
                      child: ContentText(zawiya.addressText!,
                          style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.secondaryInk)),
                    ),
                  ),
                ],
              ),
            ],
            if (zawiya.hasLocation && zawiya.coordinatesApproximate) ...[
              const SizedBox(height: 8),
              Notice.info(l10n.khadaraApproximateLocation),
            ],
            if (hasPlace) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => openInMaps(
                      context,
                      latitude: zawiya.latitude,
                      longitude: zawiya.longitude,
                      addressText: zawiya.addressText,
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(l10n.khadaraOpenInMaps),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openInMaps(
                      context,
                      latitude: zawiya.latitude,
                      longitude: zawiya.longitude,
                      addressText: zawiya.addressText,
                      directions: true,
                    ),
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: Text(l10n.zawiyaDetailItinerary),
                  ),
                ],
              ),
            ],
            if (zawiya.contactInfo != null) ...[
              const SizedBox(height: 16),
              _InfoRow(icon: Icons.call_outlined, label: l10n.khadaraContactLabel, text: zawiya.contactInfo!),
              _ContactActions(links: extractContactLinks(zawiya.contactInfo!)),
            ],
            SectionTitle(l10n.zawiyaDetailUpcoming, padding: sectionPadding),
            upcoming.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              ),
              // Message selon la cause et « Réessayer » (audit Zawiyas du
              // 2026-10-25, P3-3).
              error: (err, st) => Notice.fromError(
                err,
                message: l10n.khadaraLoadError,
                onRetry: () => ref.invalidate(upcomingEventsProvider),
              ),
              data: (events) => events.isEmpty
                  ? Notice.info(l10n.khadaraNoUpcomingEventsAtZawiya)
                  : Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < events.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
                            _EventRow(event: events[i]),
                          ],
                        ],
                      ),
                    ),
            ),
            // Fondateur, succession et figures liées : en lecture seule, les
            // liens se gèrent depuis la fiche d'une figure, par l'admin
            // (décision validée du 2026-11-02). Une section vide n'apparaît
            // pas.
            if (founder != null) ...[
              SectionTitle(l10n.zawiyaDetailFounder, padding: sectionPadding),
              _FounderCard(succession: founder),
            ],
            for (final succession in successions)
              if (succession.links.isNotEmpty) ...[
                SectionTitle(
                  l10n.zawiyaDetailSuccessionTitle(_roleLabel(succession.role, l10n)),
                  padding: sectionPadding,
                ),
                _SuccessionList(succession: succession),
              ],
            if (linkedFigures.isNotEmpty) ...[
              SectionTitle(l10n.zawiyaDetailLinkedFigures, padding: sectionPadding),
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: linkedFigures.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _FigureFace(figure: linkedFigures[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rôle d'une succession, en minuscules dans le titre (« Succession des
/// khalifes ») ; l'arabe n'a pas de casse.
String _roleLabel(SuccessionRole role, AppLocalizations l10n) {
  final label = switch (role) {
    SuccessionRole.khalife => l10n.figureSuccessionRoleKhalife,
    SuccessionRole.mokaddem => l10n.figureSuccessionRoleMokaddem,
    SuccessionRole.imam => l10n.figureSuccessionRoleImam,
  };
  return label.toLowerCase();
}

/// Ouvre la fiche d'une figure connue par son identifiant : prise dans la
/// liste déjà chargée, sinon lue en base.
///
/// Hors ligne, ou pour une fiche dépubliée depuis le chargement, la lecture
/// échoue : un message le dit, comme sur la fiche d'une figure (audit du
/// 2026-11-03 : le toucher ne faisait rien, et l'erreur n'était pas
/// rattrapée).
Future<void> _openFigureById(BuildContext context, WidgetRef ref, String figureId) async {
  final l10n = AppLocalizations.of(context)!;
  final known = ref.read(figuresProvider).valueOrNull?.where((f) => f.id == figureId).firstOrNull;
  final Figure figure;
  try {
    figure = known ?? await ref.read(figuresRepositoryProvider).fetchFigureById(figureId);
  } catch (error) {
    if (context.mounted) {
      showErrorSnackBar(context, isFigureUnavailableError(error) ? l10n.figureUnavailable : l10n.figuresLoadError);
    }
    return;
  }
  if (!context.mounted) return;
  openFigure(context, figure);
}

/// Un rendez-vous de la zawiya : bloc date (« ~ » si approximatif), titre et
/// horaire. Ouvre l'évènement.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = event.isRecurring ? (nextOccurrence(event) ?? event.startsAt) : event.startsAt;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            DateBlock(date: date, approximate: event.showsApproximateDate),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentText(event.title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  ContentText(formatKhadaraEventSchedule(event, l10n),
                      style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                ],
              ),
            ),
            DirectionalChevron(color: AppColors.bronze),
          ],
        ),
      ),
    );
  }
}

/// Le fondateur de la zawiya, tiré de sa succession : une carte qui ouvre sa
/// fiche.
class _FounderCard extends ConsumerWidget {
  const _FounderCard({required this.succession});

  final ZawiyaSuccession succession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final name = arabic
        ? (succession.founderNameAr ?? succession.founderNameFr ?? '')
        : (succession.founderNameFr ?? succession.founderNameAr ?? '');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openFigureById(context, ref, succession.founderFigureId),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_outlined, color: AppColors.ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.zawiyaDetailFounder),
                    ContentText(
                      name,
                      style: arabic
                          ? AppTheme.sacredText(fontSize: 18, color: AppColors.ink).copyWith(height: 1.4)
                          : AppTheme.titleText(fontSize: 20, color: AppColors.ink, height: 1.2),
                    ),
                    Text(l10n.zawiyaDetailSeeFiche, style: TextStyle(fontSize: 12.5, color: AppColors.emerald)),
                  ],
                ),
              ),
              DirectionalChevron(color: AppColors.bronze),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une succession, maillon par maillon : rang, nom et période (texte de la
/// base, « depuis 2017 » pour le khalife actuel). Chaque nom ouvre sa fiche.
class _SuccessionList extends ConsumerWidget {
  const _SuccessionList({required this.succession});

  final ZawiyaSuccession succession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final links = succession.links;
    // Titulaire actuel marqué en or comme dans la maquette, seulement si sa
    // période le dit (`isCurrentSuccessionHolder`) : avant l'audit du
    // 2026-11-03, le dernier khalife de la liste l'était toujours, y compris
    // quand sa période était close.
    bool isCurrent(int i) => isCurrentSuccessionHolder(links[i], isLast: i == links.length - 1);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < succession.links.length; i++) ...[
            // Maillon qui suit une lacune (`follows_gap`) : la liste est
            // incomplète à cet endroit, et le dire évite de lire une
            // succession continue (audit du 2026-11-03 ; la fiche d'une
            // figure le faisait déjà).
            if (links[i].followsGap) ...[
              if (i > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
              _SuccessionGapRow(text: l10n.figureSuccessionGapNotice),
            ],
            if (i > 0 && !links[i].followsGap)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 56),
                child: Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
              ),
            InkWell(
              onTap: () => _openFigureById(context, ref, succession.links[i].khalifaFigureId),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent(i) ? AppColors.goldSoft : AppColors.emeraldSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isCurrent(i) ? AppColors.ink : AppColors.emerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ContentText(
                              arabic ? succession.links[i].khalifaNameAr : succession.links[i].khalifaNameFr,
                              style: arabic
                                  ? AppTheme.sacredText(fontSize: 16, color: AppColors.ink).copyWith(height: 1.4)
                                  : const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink),
                            ),
                            if (succession.links[i].periodText != null)
                              ContentText(succession.links[i].periodText!,
                                  style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                          ],
                        ),
                      ),
                      if (isCurrent(i)) ...[
                        StatePill(l10n.zawiyaDetailCurrent, variant: StatePillVariant.gold),
                        const SizedBox(width: 6),
                      ],
                      DirectionalChevron(color: AppColors.bronze),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// « Liste incomplète : des noms manquent ici. », entre deux maillons d'une
/// succession, à la place du filet.
class _SuccessionGapRow extends StatelessWidget {
  const _SuccessionGapRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.parchment,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 28, child: Icon(Icons.more_vert, size: 16, color: AppColors.bronze)),
          const SizedBox(width: 14),
          Expanded(
            child: ContentText(text,
                style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.secondaryInk)),
          ),
        ],
      ),
    );
  }
}

/// Une figure liée : portrait rond (ou nom arabe) et nom. Ouvre sa fiche.
class _FigureFace extends StatelessWidget {
  const _FigureFace({required this.figure});

  final Figure figure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Semantics(
        button: true,
        label: figureDisplayName(context, figure),
        excludeSemantics: true,
        onTap: () => openFigure(context, figure),
        child: InkWell(
          onTap: () => openFigure(context, figure),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              ClipOval(child: SizedBox(width: 64, height: 64, child: FigureImage(figure: figure, arabicSize: 11))),
              const SizedBox(height: 6),
              ContentText(
                figureDisplayName(context, figure),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.ink),
              ),
            ],
          ),
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

/// Boutons « Appeler le … » et « Écrire à … » sous le contact d'un lieu.
/// Liens `tel:`/`mailto:` construits par `extractContactLinks`, jamais repris
/// tels quels du texte ; échec d'ouverture géré par un message traduit.
class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.links});

  final List<ContactLink> links;

  Future<void> _open(BuildContext context, Uri uri) async {
    final message = AppLocalizations.of(context)!.khadaraContactOpenError;
    bool launched;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 26, top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final link in links)
            TextButton.icon(
              onPressed: () => _open(context, link.uri),
              icon: Icon(link.kind == ContactLinkKind.phone ? Icons.call_outlined : Icons.mail_outline, size: 18),
              label: Text(
                link.kind == ContactLinkKind.phone
                    ? l10n.khadaraContactCall(link.label)
                    : l10n.khadaraContactWrite(link.label),
              ),
            ),
        ],
      ),
    );
  }
}
