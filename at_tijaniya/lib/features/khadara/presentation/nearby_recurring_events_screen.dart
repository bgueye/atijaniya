import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'event_detail_screen.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';
import 'open_in_maps.dart';

/// "Trouver l'évènement récurrent le plus proche" — typiquement la
/// Hadratou-l-Jouma, mais couvre tout évènement Khadara récurrent
/// (proposition du 2026-09-27). Distance calculée depuis la position de
/// l'utilisateur jusqu'à la zawiya de chaque évènement récurrent
/// (`findNearbyRecurringEvents`, khadara_models.dart). Pas de carte
/// interactive — même décision que le reste du module, voir
/// `open_in_maps.dart`.
class NearbyRecurringEventsScreen extends ConsumerStatefulWidget {
  const NearbyRecurringEventsScreen({super.key});

  @override
  ConsumerState<NearbyRecurringEventsScreen> createState() => _NearbyRecurringEventsScreenState();
}

class _NearbyRecurringEventsScreenState extends ConsumerState<NearbyRecurringEventsScreen> {
  static const _locationService = LocationService();

  bool _loading = true;
  LocationFailure? _failure;
  List<NearbyRecurringEvent>? _results;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final locationResult = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (!locationResult.isSuccess) {
      setState(() {
        _loading = false;
        _failure = locationResult.failure;
      });
      return;
    }

    final repo = ref.read(khadaraRepositoryProvider);
    final events = await repo.fetchUpcomingEvents();
    final zawiyas = await repo.fetchZawiyas();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = findNearbyRecurringEvents(
        events: events,
        zawiyas: zawiyas,
        userLatitude: locationResult.position!.latitude,
        userLongitude: locationResult.position!.longitude,
      );
    });
  }

  String _failureMessage(LocationFailure failure, AppLocalizations l10n) {
    switch (failure) {
      case LocationFailure.serviceDisabled:
        return l10n.khadaraLocationServiceDisabled;
      case LocationFailure.permissionDenied:
        return l10n.khadaraLocationPermissionDenied;
      case LocationFailure.unknown:
        return l10n.khadaraLoadError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.khadaraNearbyRecurringTitle)),
      body: SafeArea(child: _buildBody(l10n)),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }
    if (_failure != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, color: AppColors.bronze, size: 32),
              const SizedBox(height: 12),
              Text(_failureMessage(_failure!, l10n), textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _search, child: Text(l10n.khadaraRetry)),
            ],
          ),
        ),
      );
    }

    final results = _results ?? const [];
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.khadaraNearbyRecurringEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.bronze)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final result = results[i];
        return Card(
          child: ListTile(
            leading: Icon(khadaraEventTypeIcon(result.event.type), color: AppColors.emerald),
            title: Text(result.event.title),
            isThreeLine: true,
            subtitle: Text(
              '${formatKhadaraEventSchedule(result.event, l10n)}\n'
              '${result.zawiya.name} · ${formatKhadaraDistance(result.distanceKm)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n.khadaraOpenInMaps,
              onPressed: () => openInMaps(
                context,
                latitude: result.zawiya.latitude,
                longitude: result.zawiya.longitude,
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EventDetailScreen(event: result.event)),
            ),
          ),
        );
      },
    );
  }
}
