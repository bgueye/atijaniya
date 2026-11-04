import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/url/safe_url.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/empty_notice.dart';
import '../../../core/widgets/justified_choice_chips.dart';
import '../../../core/widgets/list_search_field.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import '../domain/zawiya_countries.dart';
import '../domain/zawiya_search.dart';
import '../domain/zawiyas_overview.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'khadara_understanding_screen.dart';
import 'live_stream_providers.dart';
import 'live_stream_screen.dart';
import 'open_in_maps.dart';
import 'zawiya_detail_screen.dart';
import 'zawiya_form_screen.dart';
import 'zawiyas_schematic_map.dart';
import 'zawiyas_widgets.dart';

/// Onglet « Zawiyas » (module Khadara, nom de code inchangé), refait le
/// 2026-11-03 d'après sa maquette `docs/maquettes/ecran-zawiyas.html`, avec
/// les décisions validées du 2026-11-01 et du 2026-11-03 :
/// - le direct en cours en bandeau, seulement quand il existe (l'onglet
///   « Directs », vide presque tout le temps, disparaît) ;
/// - le prochain rendez-vous en tête ;
/// - deux vues au lieu de trois onglets : Lieux (ouverte par défaut) et
///   Agenda, dans le contrôle segmenté du kit, avec leur nombre ;
/// - Lieux : recherche, types, « Près de moi » (remplace la recherche de
///   l'évènement récurrent le plus proche, sans résultat faute d'évènement
///   récurrent), carte schématique par pays (`zawiyas.country`, migration du
///   2026-11-03), lieux groupés par pays avec leurs rendez-vous, succession
///   et figures, « Comprendre la Zawiya » en bas ;
/// - Agenda : frise par mois, type, date approximative et compte à rebours ;
///   rediffusions en bas, seulement s'il y en a.
///
/// Toujours pas de carte interactive : « Ouvrir dans Maps » reste l'outil de
/// navigation (`open_in_maps.dart`).
class KhadaraScreen extends ConsumerStatefulWidget {
  const KhadaraScreen({super.key});

  @override
  ConsumerState<KhadaraScreen> createState() => _KhadaraScreenState();
}

enum _View { places, agenda }

/// Au-delà, un groupe de pays est replié (le Sénégal compte 18 lieux : sans
/// cela, les autres pays étaient loin en bas de la liste). Décision du
/// porteur de projet du 2026-11-03.
const _collapsedGroupSize = 5;

class _KhadaraScreenState extends ConsumerState<KhadaraScreen> {
  _View _view = _View.places;

  /// `null` = tous les types.
  ZawiyaKind? _kind;

  /// Recherche dans les noms et les adresses (audit Zawiyas du 2026-10-25,
  /// P2-1), combinée au type et au pays ; voir `zawiya_search.dart`.
  final _searchController = TextEditingController();

  /// Pays choisi sur la carte. `null` = tous.
  String? _country;

  /// Groupes dépliés par « Voir les N autres » (code pays, `null` pour « pays
  /// non renseigné »).
  final Set<String?> _expanded = {};

  // « Près de moi » : demandé seulement au toucher du filtre, jamais à
  // l'ouverture de l'onglet (la permission se demande quand le disciple sait
  // pourquoi).
  bool _near = false;
  bool _locating = false;
  LocationFailure? _locationFailure;
  ({double latitude, double longitude})? _position;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleNear() async {
    if (_near) {
      setState(() => _near = false);
      return;
    }
    // Le pays choisi est retiré : la proximité classe tous les lieux.
    setState(() {
      _near = true;
      _country = null;
    });
    if (_position == null) await _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationFailure = null;
    });
    final result = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.isSuccess) {
        _position = (latitude: result.position!.latitude, longitude: result.position!.longitude);
      } else {
        _locationFailure = result.failure;
      }
    });
  }

  /// Tirer pour actualiser : tout ce que l'écran affiche. Les rediffusions et
  /// les comptes de liens sont relancés sans être attendus (leur échec ne
  /// bloque pas l'écran).
  Future<void> _refresh() async {
    ref.invalidate(allLiveStreamsProvider);
    ref.invalidate(streamReplaysProvider);
    ref.invalidate(zawiyaLinkCountsProvider);
    // En « Près de moi », la position est relue : après un déplacement, les
    // distances restaient celles du premier calcul (audit du 2026-11-03).
    if (_near) unawaited(_locate());
    await Future.wait([
      ref.refresh(zawiyasProvider.future).then((_) {}, onError: (_) {}),
      ref.refresh(upcomingEventsProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  void _openEvent(KhadaraEvent event) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));

  void _openPlace(Zawiya place) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZawiyaDetailScreen(zawiya: place)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final places = ref.watch(zawiyasProvider);
    final events = ref.watch(upcomingEventsProvider);
    // Direct et rediffusions : un échec ou une attente n'affichent rien, le
    // bandeau n'existant que pendant un direct.
    final liveStreams = ref.watch(allLiveStreamsProvider).valueOrNull ?? const <LiveStream>[];
    final canManagePlaces = ref.watch(canManageZawiyasProvider);
    final canCreateEvent = ref.watch(canCreateEventProvider);

    final allPlaces = places.valueOrNull ?? const <Zawiya>[];
    final allEvents = events.valueOrNull ?? const <KhadaraEvent>[];
    final nextEvent = allEvents.firstOrNull;
    Zawiya? nextPlace;
    if (nextEvent?.zawiyaId != null) {
      nextPlace = allPlaces.where((p) => p.id == nextEvent!.zawiyaId).firstOrNull;
    }

    final Widget? fab = switch (_view) {
      _View.places when canManagePlaces => FloatingActionButton.extended(
          heroTag: 'khadara_add_zawiya',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZawiyaFormScreen())),
          icon: const Icon(Icons.add),
          label: Text(l10n.khadaraAddZawiyaButton),
        ),
      _View.agenda when canCreateEvent => FloatingActionButton.extended(
          heroTag: 'khadara_add_event',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventFormScreen())),
          icon: const Icon(Icons.add),
          label: Text(l10n.khadaraCreateEventButton),
        ),
      _ => null,
    };

    return Scaffold(
      floatingActionButton: fab,
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: _refresh,
        child: ListView(
          // Défilable même court : sans cela, le geste d'actualisation ne
          // part pas.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, fab != null ? 96 : 24),
          children: [
            for (final stream in liveStreams.take(2)) ...[
              LiveNowBanner(
                stream: stream,
                placeName: allEvents.where((e) => e.id == stream.eventId).firstOrNull?.zawiyaName ?? stream.groupName,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream))),
              ),
              const SizedBox(height: 10),
            ],
            if (nextEvent != null) ...[
              NextEventCard(
                event: nextEvent,
                now: now,
                onOpen: () => _openEvent(nextEvent),
                onDirections: _directionsFor(nextEvent, nextPlace),
              ),
              const SizedBox(height: 16),
            ],
            SegmentedSwitch<_View>(
              items: [
                SegmentedSwitchItem(
                    value: _View.places, label: l10n.khadaraViewPlaces, count: places.valueOrNull?.length),
                SegmentedSwitchItem(
                    value: _View.agenda, label: l10n.khadaraViewAgenda, count: events.valueOrNull?.length),
              ],
              selected: _view,
              onChanged: (view) => setState(() => _view = view),
            ),
            if (_view == _View.places) ..._placesView(context, l10n, places, allEvents),
            if (_view == _View.agenda) ..._agendaView(context, l10n, events, now),
          ],
        ),
      ),
    );
  }

  /// « Itinéraire » vers le lieu du rendez-vous : coordonnées de l'évènement,
  /// sinon celles du lieu. Sans coordonnées, pas de bouton (une recherche
  /// sur l'adresse resterait possible depuis la fiche).
  VoidCallback? _directionsFor(KhadaraEvent event, Zawiya? place) {
    final (lat, lon) = event.hasLocation
        ? (event.latitude, event.longitude)
        : (place != null && place.hasLocation ? (place.latitude, place.longitude) : (null, null));
    if (lat == null || lon == null) return null;
    return () => openInMaps(context, latitude: lat, longitude: lon, directions: true);
  }

  // ---------------------------------------------------------------- Lieux --

  List<Widget> _placesView(
      BuildContext context, AppLocalizations l10n, AsyncValue<List<Zawiya>> places, List<KhadaraEvent> events) {
    final language = Localizations.localeOf(context).languageCode;
    final all = places.valueOrNull ?? const <Zawiya>[];
    final kindCounts = countByKind(all);
    final query = _searchController.text.trim();
    // Type et recherche s'appliquent à la carte comme à la liste ; le pays
    // ne filtre que la liste (la carte montre où se trouvent les autres).
    final byKind = _kind == null ? all : all.where((p) => p.kind == _kind).toList();
    final filtered = searchZawiyas(byKind, query);
    final counts = ref.watch(zawiyaLinkCountsProvider).valueOrNull ?? const ZawiyaLinkCounts();

    String chipLabel(String label, int count) => l10n.khadaraFilterWithCount(label, count);

    return [
      const SizedBox(height: 12),
      ListSearchField(
        controller: _searchController,
        onChanged: () => setState(() {}),
        hint: l10n.khadaraSearchHint,
        clearTooltip: l10n.khadaraSearchClear,
      ),
      const SizedBox(height: 12),
      // Une ligne justifiée, retour à la ligne si elle ne tient pas, plutôt
      // que la rangée défilante de la maquette : écartée par le porteur de
      // projet le 2026-10-01 (« Mosquées » dépassait du bord), puces de 48 dp
      // (audit Zawiyas du 2026-10-25, P2-7).
      JustifiedChoiceChips<ZawiyaKind?>(
        options: [
          (null, places.hasValue ? chipLabel(l10n.khadaraFilterAll, all.length) : l10n.khadaraFilterAll),
          for (final (kind, label) in [
            (ZawiyaKind.zawiya, l10n.khadaraFilterZawiyas),
            (ZawiyaKind.holyPlace, l10n.khadaraFilterHolyPlaces),
            (ZawiyaKind.mosque, l10n.khadaraFilterMosques),
          ])
            (kind, places.hasValue ? chipLabel(label, kindCounts[kind]!) : label),
        ],
        selected: _kind,
        onSelected: (kind) => setState(() => _kind = kind),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilterChip(
          selected: _near,
          showCheckmark: false,
          avatar: Icon(Icons.near_me_outlined, size: 18, color: _near ? AppColors.offWhite : AppColors.emerald),
          label: Text(l10n.khadaraFilterNearMe),
          labelStyle: TextStyle(color: _near ? AppColors.offWhite : AppColors.ink),
          selectedColor: AppColors.emerald,
          onSelected: (_) => _toggleNear(),
        ),
      ),
      ...places.when(
        loading: () => [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          ),
        ],
        error: (error, _) => [
          _LoadError(error: error, onRetry: () => ref.invalidate(zawiyasProvider)),
        ],
        data: (_) => _near
            ? _nearList(l10n, filtered, events, counts)
            : _countryList(context, l10n, language, filtered, events, counts),
      ),
      const SizedBox(height: 20),
      UnderstandingCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KhadaraUnderstandingScreen())),
      ),
    ];
  }

  List<Widget> _countryList(
    BuildContext context,
    AppLocalizations l10n,
    String language,
    List<Zawiya> filtered,
    List<KhadaraEvent> events,
    ZawiyaLinkCounts counts,
  ) {
    final points = countryPoints(filtered);
    final listed = _country == null ? filtered : filtered.where((p) => p.country == _country).toList();
    final groups = groupPlacesByCountry(listed, language);
    final query = _searchController.text.trim();
    // Une recherche ou un pays choisi montrent tout : le repli ne sert qu'à
    // parcourir l'annuaire entier.
    final collapsible = query.isEmpty && _country == null;

    return [
      const SizedBox(height: 8),
      if (points.inside.isNotEmpty || points.outside.isNotEmpty)
        Semantics(
          container: true,
          label: l10n.khadaraMapSemantics,
          child: ZawiyasSchematicMap(
            inside: points.inside,
            outside: points.outside,
            countryTotal: countryCount(filtered),
            selectedCountry: _country,
            onCountryTap: (code) => setState(() => _country = _country == code ? null : code),
          ),
        ),
      if (_country != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InputChip(
              label: Text(zawiyaCountryName(_country!, language)),
              selected: true,
              showCheckmark: false,
              selectedColor: AppColors.emeraldSoft,
              deleteIconColor: AppColors.emerald,
              deleteButtonTooltipMessage: l10n.khadaraMapClearCountry,
              onDeleted: () => setState(() => _country = null),
              onPressed: () => setState(() => _country = null),
            ),
          ),
        ),
      if (groups.isEmpty) _emptyPlaces(l10n, query),
      for (final group in groups) ...[
        GroupHeader(
          title:
              group.countryCode == null ? l10n.khadaraCountryUnknown : zawiyaCountryName(group.countryCode!, language),
          trailing: l10n.khadaraPlacesCount(group.places.length),
        ),
        for (final place
            in (collapsible && !_expanded.contains(group.countryCode) && group.places.length > _collapsedGroupSize + 1)
                ? group.places.take(_collapsedGroupSize)
                : group.places)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlaceCard(
              place: place,
              facts: placeFacts(place.id, events, counts),
              onTap: () => _openPlace(place),
            ),
          ),
        // « + 1 » plus haut : replier pour cacher un seul lieu ferait un
        // bouton aussi long que la carte cachée.
        if (collapsible && !_expanded.contains(group.countryCode) && group.places.length > _collapsedGroupSize + 1)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _expanded.add(group.countryCode)),
              child: Text(l10n.khadaraShowMorePlaces(group.places.length - _collapsedGroupSize)),
            ),
          ),
      ],
    ];
  }

  List<Widget> _nearList(
      AppLocalizations l10n, List<Zawiya> filtered, List<KhadaraEvent> events, ZawiyaLinkCounts counts) {
    final language = Localizations.localeOf(context).languageCode;
    if (_locating) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
              const SizedBox(width: 12),
              Text(l10n.khadaraNearestLocating, style: TextStyle(color: AppColors.secondaryInk)),
            ],
          ),
        ),
      ];
    }
    final failure = _locationFailure;
    if (failure != null || _position == null) {
      return [_LocationProblem(failure: failure ?? LocationFailure.unknown, onRetry: _locate)];
    }
    final result = sortPlacesByDistance(filtered, latitude: _position!.latitude, longitude: _position!.longitude);
    return [
      GroupHeader(title: l10n.khadaraNearestTitle, trailing: l10n.khadaraNearestFrom),
      if (result.sorted.isEmpty) _emptyPlaces(l10n, _searchController.text.trim()),
      for (final item in result.sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PlaceCard(
            place: item.place,
            facts: placeFacts(item.place.id, events, counts),
            onTap: () => _openPlace(item.place),
            // « ~ » devant une distance calculée sur des coordonnées
            // approximatives (audit Zawiyas du 2026-10-25, P2-2).
            distanceText: item.place.coordinatesApproximate
                ? l10n.khadaraNearestApproxDistance(formatKhadaraDistance(item.distanceKm, languageCode: language))
                : formatKhadaraDistance(item.distanceKm, languageCode: language),
          ),
        ),
      if (result.unlocatedCount > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(l10n.khadaraNearestUnlocated(result.unlocatedCount),
              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
        ),
    ];
  }

  /// Une recherche sans résultat le dit, avec la saisie, plutôt que de
  /// laisser croire que l'annuaire ou le type est vide.
  Widget _emptyPlaces(AppLocalizations l10n, String query) {
    final text = query.isNotEmpty
        ? l10n.khadaraSearchNoResult(query)
        : (_kind == null ? l10n.khadaraNoZawiyas : l10n.khadaraNoPlacesForFilter);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: ContentText(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
    );
  }

  // --------------------------------------------------------------- Agenda --

  List<Widget> _agendaView(
      BuildContext context, AppLocalizations l10n, AsyncValue<List<KhadaraEvent>> events, DateTime now) {
    final language = Localizations.localeOf(context).languageCode;
    final replays = ref.watch(streamReplaysProvider).valueOrNull ?? const <StreamReplay>[];
    return [
      ...events.when(
        loading: () => [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          ),
        ],
        error: (error, _) => [_LoadError(error: error, onRetry: () => ref.invalidate(upcomingEventsProvider))],
        data: (list) => list.isEmpty
            ? [
                const SizedBox(height: 16),
                EmptyNotice(text: l10n.khadaraNoEvents),
              ]
            : [
                for (final month in groupEventsByMonth(list, now)) ...[
                  GroupHeader(
                    title: agendaMonthTitle(month, language),
                    trailing: l10n.khadaraAgendaMonthCount(month.events.length),
                  ),
                  for (final event in month.events)
                    AgendaEventRow(event: event, now: now, onTap: () => _openEvent(event)),
                ],
              ],
      ),
      // Rediffusions : une section de l'Agenda, seulement quand il y en a
      // (aucune en base au 2026-11-03).
      if (replays.isNotEmpty) ...[
        SectionTitle(l10n.khadaraReplaysSection, padding: const EdgeInsetsDirectional.fromSTEB(2, 24, 2, 8)),
        for (final replay in replays)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.play_circle_outline, color: AppColors.emerald),
              title: Text(replay.displayTitle(l10n.khadaraLiveTab)),
              trailing: Icon(Icons.open_in_new, color: AppColors.bronze),
              onTap: () async {
                final uri = parseSafeHttpUrl(replay.videoUrl);
                final launched = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!launched && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.khadaraOpenReplayError)));
                }
              },
            ),
          ),
      ],
    ];
  }
}

/// Échec du chargement des lieux ou des rendez-vous. Hors ligne distingué
/// d'une autre erreur (audit Zawiyas du 2026-10-25, P3-3) : « impossible de
/// charger » laissait croire à un problème de l'app quand le téléphone
/// n'avait simplement pas de réseau.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final offline = isNetworkError(error);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(offline ? Icons.wifi_off : Icons.error_outline, color: AppColors.bronze, size: 32),
          const SizedBox(height: 12),
          Text(
            offline ? l10n.khadaraOfflineError : l10n.khadaraLoadError,
            textAlign: TextAlign.center,
            // Encre secondaire, pas le bronze (3,72:1 sur parchemin, sous le
            // seuil AA ; audit Zawiyas du 2026-10-25, P2-6).
            style: TextStyle(color: AppColors.secondaryInk),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.khadaraRetry)),
        ],
      ),
    );
  }
}

/// « Près de moi » sans position. Après un refus définitif ou avec la
/// localisation coupée, le système ne redemande plus : un bouton mène aux
/// réglages concernés, « Réessayer » reste pour le retour (audit Zawiyas du
/// 2026-10-25, P2-8, repris de l'ancien écran de recherche par proximité).
class _LocationProblem extends ConsumerWidget {
  const _LocationProblem({required this.failure, required this.onRetry});

  final LocationFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (failure) {
      LocationFailure.serviceDisabled => l10n.khadaraNearServiceDisabled,
      LocationFailure.permissionDenied || LocationFailure.permissionDeniedForever => l10n.khadaraNearPermissionDenied,
      // Délai dépassé, service qui refuse : il s'agit de la position, pas
      // du réseau (audit du 2026-11-03).
      LocationFailure.unknown => l10n.khadaraNearLocationUnknown,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Icon(Icons.location_off_outlined, color: AppColors.bronze, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk)),
          const SizedBox(height: 12),
          if (failure == LocationFailure.permissionDeniedForever) ...[
            FilledButton(
              onPressed: () => ref.read(locationServiceProvider).openAppSettings(),
              child: Text(l10n.khadaraLocationOpenSettings),
            ),
            const SizedBox(height: 8),
          ] else if (failure == LocationFailure.serviceDisabled) ...[
            FilledButton(
              onPressed: () => ref.read(locationServiceProvider).openLocationSettings(),
              child: Text(l10n.khadaraLocationEnableService),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(onPressed: onRetry, child: Text(l10n.khadaraRetry)),
        ],
      ),
    );
  }
}
