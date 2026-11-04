// Captures du chemin spirituel mis au thème du kit le 2026-11-04 (lignée,
// condisciples, Devenir Mouqaddam, demandes de parrainage, silsila d'ijaza),
// en français et en arabe, avec les vraies polices, plus un état d'erreur.
//
// Ignoré sans KIT_FONTS_DIR et KIT_CAPTURES_DIR (voir `capture_support.dart`).
// Noms et années d'exemple : aucune donnée réelle de lignée.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_matches_screen.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_providers.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/domain/mouqaddam_models.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/become_mouqaddam_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/ijaza_chain_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/sponsorship_requests_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'capture_support.dart';

void main() {
  final skip = captureSkipReason;

  setUpAll(() async {
    if (skip == null) await setUpCaptureFonts();
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Locale locale,
    Widget screen,
    List<Override> overrides, {
    double height = 1100,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(),
          locale: locale,
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Révélation animée de la silsila : on la laisse finir.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    await captureToFile(tester, find.byKey(key), '${name}_${locale.languageCode}');
  }

  final requests = [
    LineageConnectionRequest(
      id: 'r1',
      requesterId: 'b',
      recipientId: 'moi',
      status: LineageConnectionStatus.pending,
      createdAt: DateTime(2026, 11, 1),
      otherUserName: 'Disciple B',
    ),
    LineageConnectionRequest(
      id: 'r2',
      requesterId: 'moi',
      recipientId: 'a',
      status: LineageConnectionStatus.pending,
      createdAt: DateTime(2026, 11, 1),
    ),
  ];

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    final lang = locale.languageCode;

    testWidgets('capture lignée ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_lignee', locale, const LineageScreen(), [
        myLineageProvider.overrideWith(
          (ref) async => const LineageDeclaration(foyer: Foyer.tivaouane, moqaddamNameText: 'Nom d’exemple'),
        ),
      ]);
    });

    testWidgets('capture condisciples ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_condisciples', locale, const LineageMatchesScreen(), [
        currentUserIdProvider.overrideWithValue('moi'),
        myLineageProvider.overrideWith(
          (ref) async => const LineageDeclaration(foyer: Foyer.tivaouane, moqaddamNameText: 'Nom d’exemple'),
        ),
        myPrivacySettingsProvider.overrideWith((ref) async => const PrivacySettings(lineageVisible: true)),
        lineageMatchesProvider.overrideWith((ref) async => const [
              LineageMatch(userId: 'a', displayName: 'Disciple A', transmissionYear: 2010),
              LineageMatch(userId: 'c', displayName: 'Disciple C'),
            ]),
        myConnectionRequestsProvider.overrideWith((ref) async => requests),
      ]);
    });

    testWidgets('capture condisciples sans lignée ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_condisciples_vide', locale, const LineageMatchesScreen(), [
        currentUserIdProvider.overrideWithValue('moi'),
        myLineageProvider.overrideWith((ref) async => null),
        myPrivacySettingsProvider.overrideWith((ref) async => const PrivacySettings()),
      ]);
    });

    testWidgets('capture devenir mouqaddam ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_devenir', locale, const BecomeMouqaddamScreen(), [
        myLatestSponsorshipRequestProvider.overrideWith((ref) async => null),
      ]);
    });

    testWidgets('capture demandes de parrainage ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_demandes', locale, const SponsorshipRequestsScreen(), [
        receivedSponsorshipRequestsProvider.overrideWith((ref) async => [
              SponsorshipRequest(
                id: 's1',
                candidateUserId: 'b',
                sponsorUserId: 'moi',
                ijazaYear: 2015,
                status: SponsorshipRequestStatus.pending,
                requestedAt: DateTime(2026, 11, 1),
                candidateName: 'Candidat B',
              ),
            ]),
      ]);
    });

    testWidgets('capture demandes en erreur ($lang)', skip: skip != null, (tester) async {
      await capture(tester, 'chemin_demandes_erreur', locale, const SponsorshipRequestsScreen(),
          [receivedSponsorshipRequestsProvider.overrideWith((ref) async => throw StateError('panne'))],
          height: 500);
    });

    testWidgets('capture silsila ($lang)', skip: skip != null, (tester) async {
      // L'écran retient sur le téléphone si la révélation a déjà été vue.
      SharedPreferences.setMockInitialValues({});
      await capture(
        tester,
        'chemin_silsila',
        locale,
        const IjazaChainScreen(),
        [
          currentUserIdProvider.overrideWithValue('moi'),
          myIjazaChainProvider.overrideWith((ref) async => const [
                IjazaChainLink(depth: 0, userId: 'moi', isManual: false, resolvedName: 'Mon nom', ijazaYear: 2020),
                IjazaChainLink(
                    depth: 1, userId: 'p', isManual: false, resolvedName: 'Parrain d’exemple', ijazaYear: 1998),
                IjazaChainLink(depth: 2, isManual: true, nameText: 'اسم مثال', yearText: '1950'),
                IjazaChainLink(depth: 3, isManual: true, nameText: 'Cheikh (exemple)', isUltimateSource: true),
              ]),
          myManualChainLinksProvider.overrideWith((ref) async => const <ManualChainLink>[]),
        ],
        height: 1400,
        settle: false,
      );
    });
  }
}
