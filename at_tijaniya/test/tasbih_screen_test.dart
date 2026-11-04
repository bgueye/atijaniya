// Vérifie l'écran de pratique (revu le 2026-10-06, refait le 2026-11-02
// d'après `docs/maquettes/ecran-pratique.html`) : le compteur reste visible
// sans défiler même sur un pilier au texte long et un petit écran, toute la
// partie basse compte une répétition, la clôture s'affiche en plein écran et
// n'enchaîne pas toute seule, les piliers récités une fois s'affichent en
// entier, « Réinitialiser » est dans le menu « ⋯ ». Les wirds viennent du
// corpus validé ; aucun texte religieux n'est écrit ici.

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

    expect(find.text('Pilier 4 / 5 · Salatoul Fatihi ×100'), findsOneWidget);
    for (final text in ['0', '/ 100', 'Toucher pour compter', 'Corriger -1', 'Concentré']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: '« $text » doit tenir dans l\'écran');
      expect(rect.top, greaterThan(screen.height / 3), reason: '« $text » appartient à la partie basse');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('la lecture prend la place de son texte : un texte court laisse plus de place au compteur',
      (tester) async {
    _seed(lazim, pillarIndex: 2); // Astaghfirullah, texte court
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    final shortTop = tester.getRect(find.text('Toucher pour compter')).top;

    _seed(lazim, pillarIndex: longPillar);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    final longRect = tester.getRect(find.text('Toucher pour compter'));
    expect(shortTop, lessThan(longRect.top));
    expect(longRect.bottom, lessThanOrEqualTo(screen.height));
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

    for (final text in ['0', '/ 100', 'Toucher pour compter', 'Corriger -1', 'Concentré']) {
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
    expect(tester.getRect(find.text('Corriger -1')).bottom, lessThanOrEqualTo(landscape.height));
  });

  testWidgets("avec une clôture à réciter, le pilier n'enchaîne pas tout seul", (tester) async {
    _seed(lazim, pillarIndex: longPillar, count: 99);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toucher pour compter'));
    await tester.pump();

    // Étape de clôture en plein écran : chaque formule en entier.
    expect(find.text('100 / 100 · récitez maintenant la clôture'), findsOneWidget);
    for (final formula in lazim.pillars[longPillar].closingFormulas!) {
      expect(find.text(formula.intro), findsOneWidget);
      expect(find.text(formula.arabic), findsOneWidget);
    }
    expect(find.text('Pilier suivant'), findsOneWidget);
    expect(find.text('Pilier suivant dans un instant…'), findsNothing);

    // Bien au-delà de l'ancien délai d'enchaînement.
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('Pilier 4 / 5'), findsOneWidget);

    await tester.tap(find.text('Pilier suivant'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pilier 5 / 5'), findsOneWidget);
  });

  testWidgets("sans clôture, le pilier suivant arrive après un instant", (tester) async {
    // Istighfar de la Wazifa (×30), sans formule de clôture.
    _seed(wazifa, pillarIndex: 2, count: 29);
    await tester.pumpWidget(_wrap(wazifa));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Toucher pour compter'));
    await tester.pump();
    expect(find.text('Pilier suivant dans un instant…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pilier 4 / 6'), findsOneWidget);
  });

  testWidgets('la Fatiha s\'affiche en entier, verset par verset, avec un seul bouton', (tester) async {
    _seed(lazim, pillarIndex: 1);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    final verses = lazim.pillars[1].fullText!;
    expect(find.text(verses.first.arabic), findsOneWidget);
    expect(find.text('Toucher pour compter'), findsNothing, reason: 'pas de compteur pour un seul toucher');
    expect(find.text('Ensuite : Istighfar ×100'), findsOneWidget);

    await tester.tap(find.text('Récitée · pilier suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Pilier 3 / 5 · Istighfar ×100'), findsOneWidget);
  });

  // Audit des écrans refaits du 2026-11-03 : l'intention et la Fatiha ont le
  // même bouton au même endroit ; un double toucher marquait la Fatiha
  // récitée sans retour possible. Les touchers sont ignorés un court instant
  // après chaque changement de pilier.
  testWidgets('un double toucher sur « Récitée » ne saute pas la Fatiha', (tester) async {
    _seed(lazim, pillarIndex: 0);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    expect(find.text('Récitée · pilier suivant'), findsOneWidget);

    await tester.tap(find.text('Récitée · pilier suivant'));
    await tester.pump();
    // Second toucher aussitôt, sur le bouton de la Fatiha : ignoré.
    await tester.tap(find.text('Récitée · pilier suivant'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(lazim.pillars[1].fullText!.first.arabic), findsOneWidget, reason: 'toujours sur la Fatiha');

    // Après le court délai, le bouton répond de nouveau.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Récitée · pilier suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Pilier 3 / 5 · Istighfar ×100'), findsOneWidget);
  });

  testWidgets('« Réinitialiser » est dans le menu « ⋯ », avec « Annuler »', (tester) async {
    _seed(lazim, pillarIndex: 2, count: 12);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    expect(find.text('Réinitialiser'), findsNothing);

    await tester.tap(find.byTooltip('Autres actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réinitialiser le pilier'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('mode concentré : ouvert par le bouton, tout l\'écran compte, « Afficher le texte » en sort',
      (tester) async {
    _seed(lazim, pillarIndex: 4, count: 10);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Concentré'));
    await tester.pumpAndSettle();
    expect(find.text('sur 100'), findsOneWidget);
    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
    expect(find.text('11'), findsOneWidget);

    await tester.tap(find.text('Afficher le texte'));
    await tester.pumpAndSettle();
    expect(find.text('/ 100'), findsOneWidget);
  });

  testWidgets('« Aa » : traduction masquée par défaut, affichée sur demande', (tester) async {
    _seed(lazim, pillarIndex: 2);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();
    final translation = lazim.pillars[2].translation;
    expect(find.text(translation), findsNothing);

    await tester.tap(find.bySemanticsLabel('Réglages de lecture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traduction'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 40)); // ferme la feuille
    await tester.pumpAndSettle();
    expect(find.text(translation), findsOneWidget);
  });

  testWidgets('fin du wird : titre, piliers récités, retour', (tester) async {
    _seed(lazim, pillarIndex: 4, count: 100);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terminer le Lazim'));
    await tester.pumpAndSettle();
    expect(find.text('Lazim accompli'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
    expect(find.text('Voir mon historique'), findsOneWidget);
  });
}
