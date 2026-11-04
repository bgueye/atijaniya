// Chemin spirituel mis au thème du kit le 2026-11-04 :
// - « Retrouver mes condisciples » : titres de section du kit, état d'une
//   demande en pastille (`StatePill`) et non en texte bronze, erreur en
//   `Notice` avec « Réessayer » ;
// - « Ma silsila d'ijaza » : nom en Cormorant s'il est en écriture latine, en
//   Amiri s'il est en arabe ; « Vous » en émeraude et non en or ;
// - aucun texte de ces écrans en bronze (sous le seuil AA).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/core/widgets/state_pill.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_matches_screen.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_providers.dart';
import 'package:at_tijaniya/features/mouqaddam/domain/mouqaddam_models.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/ijaza_chain_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

/// Aucun texte en bronze : il est sous le seuil AA (kit § Couleurs).
void _expectNoBronzeText(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style?.color, isNot(AppColors.bronze), reason: 'texte en bronze : « ${text.data ?? text.textSpan} »');
  }
}

/// Lignée et visibilité réglées : la page affiche les correspondances.
List<Override> _matchesOverrides({
  Future<List<LineageMatch>> Function()? matches,
  List<LineageConnectionRequest> requests = const [],
}) =>
    [
      currentUserIdProvider.overrideWithValue('moi'),
      myLineageProvider.overrideWith(
        (ref) async => const LineageDeclaration(foyer: Foyer.tivaouane, moqaddamNameText: 'exemple'),
      ),
      myPrivacySettingsProvider.overrideWith((ref) async => const PrivacySettings(lineageVisible: true)),
      lineageMatchesProvider.overrideWith((ref) => (matches ?? () async => const <LineageMatch>[])()),
      myConnectionRequestsProvider.overrideWith((ref) async => requests),
    ];

void main() {
  group('Retrouver mes condisciples', () {
    testWidgets("titres du kit et état de la demande en pastille", (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        const LineageMatchesScreen(),
        _matchesOverrides(
          matches: () async => const [LineageMatch(userId: 'a', displayName: 'Condisciple A')],
          requests: [
            LineageConnectionRequest(
              id: 'r1',
              requesterId: 'moi',
              recipientId: 'a',
              status: LineageConnectionStatus.pending,
              createdAt: DateTime(2026, 11, 1),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SectionTitle, 'Condisciples correspondants'), findsOneWidget);
      expect(tester.getSemantics(find.text('Condisciples correspondants')), isSemantics(isHeader: true));
      expect(find.widgetWithText(StatePill, 'Demande envoyée'), findsOneWidget);
      _expectNoBronzeText(tester);
      semantics.dispose();
    });

    testWidgets("erreur de chargement : la carte du kit, qui relance", (tester) async {
      var calls = 0;
      await tester.pumpWidget(_app(
        const LineageMatchesScreen(),
        _matchesOverrides(matches: () async {
          calls++;
          if (calls == 1) throw StateError('panne');
          return const [LineageMatch(userId: 'a', displayName: 'Condisciple A')];
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Notice), findsOneWidget);
      _expectNoBronzeText(tester);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Condisciple A'), findsOneWidget);
    });
  });

  testWidgets("silsila : noms en Cormorant ou en Amiri selon l'écriture, « Vous » en émeraude", (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const chain = [
      IjazaChainLink(depth: 0, userId: 'moi', isManual: false, resolvedName: 'Nom latin'),
      IjazaChainLink(depth: 1, isManual: true, nameText: 'اسم عربي', isUltimateSource: true),
    ];
    await tester.pumpWidget(_app(const IjazaChainScreen(), [
      currentUserIdProvider.overrideWithValue('moi'),
      myIjazaChainProvider.overrideWith((ref) async => chain),
      myManualChainLinksProvider.overrideWith((ref) async => const <ManualChainLink>[]),
    ]));
    // La révélation de la chaîne s'anime maillon par maillon : on la laisse
    // finir.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    String? family(String text) => tester.widget<Text>(find.text(text)).style?.fontFamily;
    expect(family('Nom latin'), contains('Cormorant'));
    expect(family('اسم عربي'), contains('Amiri'));
    expect(tester.widget<Text>(find.text('Vous')).style?.color, AppColors.emerald);
    _expectNoBronzeText(tester);
  });
}
