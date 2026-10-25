// « La Hadra la plus proche » : échecs de localisation (audit Zawiyas du
// 2026-10-25, P2-8). Service de localisation factice, injecté par
// `locationServiceProvider` ; aucune position réelle, aucun réseau.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/location/location_service.dart';
import 'package:at_tijaniya/features/khadara/presentation/nearby_recurring_events_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.failure);

  final LocationFailure failure;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<LocationResult> getCurrentPosition() async => LocationResult(failure: failure);

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}

Widget _wrap(LocationService service) {
  return ProviderScope(
    overrides: [locationServiceProvider.overrideWithValue(service)],
    child: const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr'), Locale('ar')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: NearbyRecurringEventsScreen(),
    ),
  );
}

void main() {
  testWidgets('refus définitif : bouton vers les réglages de l\'app, en plus de « Réessayer »', (tester) async {
    final service = _FakeLocationService(LocationFailure.permissionDeniedForever);
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Ouvrir les réglages'));
    await tester.pump();
    expect(service.appSettingsOpened, 1);
    expect(find.text('Activer la localisation'), findsNothing);
  });

  testWidgets('localisation coupée : bouton vers les réglages de localisation', (tester) async {
    final service = _FakeLocationService(LocationFailure.serviceDisabled);
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activer la localisation'));
    await tester.pump();
    expect(service.locationSettingsOpened, 1);
    expect(find.text('Ouvrir les réglages'), findsNothing);
  });

  testWidgets('refus simple : « Réessayer » suffit, le système redemandera', (tester) async {
    await tester.pumpWidget(_wrap(_FakeLocationService(LocationFailure.permissionDenied)));
    await tester.pumpAndSettle();

    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Ouvrir les réglages'), findsNothing);
    expect(find.text('Activer la localisation'), findsNothing);
  });
}
