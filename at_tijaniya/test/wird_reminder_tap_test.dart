// Audit de l'accueil du 2026-10-26 (P2-5) : toucher un rappel du wird ouvre
// le guide de ce wird, au lieu de l'app depuis son début.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/presentation/home_shell.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/wird/data/wird_notification_service.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_detail_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_pillar_audio_controller.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

class _NoRecitations implements WirdRecitationRepository {
  @override
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyManifest implements WirdRecitationAssetManifest {
  @override
  Future<Map<String, WirdRecitationAsset>> load() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _shell() {
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 0)),
      currentUserIdProvider.overrideWithValue(null),
      upcomingEventsProvider.overrideWith((ref) async => const []),
      featuredFigureProvider.overrideWith((ref) async => null),
      wirdPillarAudioProvider.overrideWith(
        (ref, wird) => WirdPillarAudioController(wird: wird, repository: _NoRecitations(), assetManifest: _EmptyManifest()),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: [Locale('fr'), Locale('ar')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeShell(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WirdNotificationService.instance.pendingWirdId.value = null;
  });

  test('chaque créneau de rappel mène à son wird ; identifiant inconnu : rien', () {
    expect(wirdIdForNotificationId(1101), 'lazim');
    expect(wirdIdForNotificationId(1102), 'lazim');
    expect(wirdIdForNotificationId(1201), 'wazifa');
    expect(wirdIdForNotificationId(1301), 'hadratou_jouma');
    expect(wirdIdForNotificationId(42), isNull);
    expect(wirdIdForNotificationId(null), isNull);
  });

  testWidgets("rappel ayant lancé l'app : guide du wird ouvert à l'arrivée sur les onglets", (tester) async {
    WirdNotificationService.instance.pendingWirdId.value = 'wazifa';
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byType(WirdDetailScreen), findsOneWidget);
    expect(WirdNotificationService.instance.pendingWirdId.value, isNull);

    // Retour arrière : l'accueil.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(WirdDetailScreen), findsNothing);
    expect(find.text('Accueil'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("rappel touché pendant l'utilisation : guide ouvert aussitôt", (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();
    expect(find.byType(WirdDetailScreen), findsNothing);

    WirdNotificationService.instance.pendingWirdId.value = 'lazim';
    await tester.pumpAndSettle();
    expect(find.byType(WirdDetailScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
