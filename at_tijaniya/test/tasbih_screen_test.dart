// Vérifie la présentation du Tasbih revue le 2026-10-06 : le compteur reste
// visible sans défiler même sur un pilier au texte long et un petit écran,
// toute la partie basse compte une répétition, et un pilier suivi d'une
// formule de clôture n'enchaîne plus tout seul. Les wirds viennent du corpus
// validé ; aucun texte religieux n'est écrit ici.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/presentation/tasbih_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Wird wird) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TasbihScreen(wird: wird),
    ),
  );
}

/// Reprend une session au pilier et au compte voulus (clé du compte
/// "invité" : Supabase n'est pas initialisé dans les tests).
void _seed(Wird wird, {required int pillarIndex, int count = 0}) {
  SharedPreferences.setMockInitialValues({
    'tasbih_session_${wird.id}::guest': jsonEncode({
      'wirdId': wird.id,
      'pillarIndex': pillarIndex,
      'currentCount': count,
      'mode': 'manual',
      'updatedAt': DateTime(2026, 10, 6).toIso8601String(),
      'useAlternative': false,
    }),
  });
}

void main() {
  const screen = Size(360, 640); // petit téléphone

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = screen;
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  // Pilier du Lazim au texte long, 100 répétitions, suivi d'une clôture.
  const longPillar = 3;

  testWidgets('le compteur est visible sans défiler sur un pilier au texte long', (tester) async {
    _seed(lazim, pillarIndex: longPillar);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    expect(find.text('Pilier 4 / 5'), findsOneWidget);
    for (final text in ['0', '/ 100', 'Toucher pour compter', 'Corriger -1', 'Réinitialiser']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: '« $text » doit tenir dans l\'écran');
      expect(rect.top, greaterThan(screen.height / 3), reason: '« $text » appartient à la partie basse');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('le compteur garde la même place d\'un pilier court à un pilier long', (tester) async {
    _seed(lazim, pillarIndex: 1);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    final shortTop = tester.getRect(find.text('Toucher pour compter')).top;

    _seed(lazim, pillarIndex: longPillar);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Toucher pour compter')).top, shortTop);
  });

  testWidgets('toute la partie basse compte, pas seulement le cercle', (tester) async {
    _seed(lazim, pillarIndex: longPillar);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    // Bord gauche de l'écran, à la hauteur du décompte : hors du cercle.
    final counterY = tester.getCenter(find.text('/ 100')).dy;
    await tester.tapAt(Offset(12, counterY));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Corriger -1'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('en paysage, le compteur et ses commandes tiennent à côté de la lecture', (tester) async {
    // Téléphone couché : très peu de hauteur (retour du 2026-10-08, le socle
    // empilé y prenait tout l'écran et rognait les commandes).
    const landscape = Size(740, 340);
    tester.view.physicalSize = landscape;

    _seed(lazim, pillarIndex: longPillar);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final text in ['0', '/ 100', 'Toucher pour compter', 'Corriger -1', 'Réinitialiser']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.bottom, lessThanOrEqualTo(landscape.height), reason: "« $text » doit tenir dans l'écran");
      expect(rect.left, greaterThan(landscape.width / 2), reason: '« $text » est du côté du compteur');
    }

    await tester.tap(find.text('Toucher pour compter'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Mode voix, plus haut : rien ne déborde non plus.
    await tester.tap(find.byTooltip('Voix'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text("Démarrer l'écoute"), findsOneWidget);

    // Toucher le cercle ne lance pas l'écoute : seul le bouton le fait. (Sans
    // micro en test, un démarrage afficherait « Micro indisponible… ».)
    await tester.tap(find.text('/ 100'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Micro indisponible'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.getRect(find.text('Réinitialiser')).bottom, lessThanOrEqualTo(landscape.height));
  });

  testWidgets("avec une clôture à réciter, le pilier n'enchaîne pas tout seul", (tester) async {
    _seed(lazim, pillarIndex: longPillar, count: 99);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toucher pour compter'));
    await tester.pump();

    final closing = lazim.pillars[longPillar].closingFormulas!.first;
    expect(find.text(closing.intro), findsOneWidget);
    expect(find.text('Pilier suivant'), findsOneWidget);
    expect(find.text('Pilier suivant dans un instant…'), findsNothing);

    // Bien au-delà de l'ancien délai d'enchaînement.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Pilier 4 / 5'), findsOneWidget);

    await tester.tap(find.text('Pilier suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Pilier 5 / 5'), findsOneWidget);
  });

  testWidgets("sans clôture, le pilier suivant arrive après un instant", (tester) async {
    _seed(lazim, pillarIndex: 0);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toucher pour compter'));
    await tester.pump();
    expect(find.text('Pilier suivant dans un instant…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Pilier 2 / 5'), findsOneWidget);
  });
}
