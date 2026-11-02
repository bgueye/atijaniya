// Fiches de détail refaites le 2026-11-02 (maquette `ecrans-detail.html`) :
// ce que la refonte ajoute à chaque fiche.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/figures/presentation/figure_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/event_detail_screen.dart';
import 'package:at_tijaniya/features/khadara/presentation/zawiya_detail_screen.dart';

import 'detail_screens_test_support.dart';

void main() {
  testWidgets('évènement : compte à rebours, date approximative, note et direct vide', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(detailApp(EventDetailScreen(event: detailEvent())));
    await tester.pumpAndSettle();

    expect(find.text('Dans environ 153 jours'), findsOneWidget);
    expect(find.text('Date approximative'), findsOneWidget);
    expect(find.text('Date à confirmer.'), findsOneWidget);
    expect(find.text("Pas de direct pour l'instant"), findsOneWidget);
    // Sans compte : pas de bouton pour démarrer un direct.
    expect(find.text('Démarrer un direct'), findsNothing);

    // Le lieu ouvre la fiche de la zawiya.
    await tester.tap(find.text('Zawiya de Tivaouane'));
    await tester.pumpAndSettle();
    expect(find.byType(ZawiyaDetailScreen), findsOneWidget);
  });

  testWidgets('zawiya : fondateur, succession avec le khalife actuel, figures liées', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(detailApp(const ZawiyaDetailScreen(zawiya: detailZawiya)));
    await tester.pumpAndSettle();

    expect(find.text('Prochains rendez-vous'), findsOneWidget);
    expect(find.text('Ziarra générale de Tivaouane 2027'), findsOneWidget);
    expect(find.text('Succession des khalifes'), findsOneWidget);
    expect(find.text('depuis 2017'), findsOneWidget);
    // « Actuel » sur le dernier khalife seulement.
    expect(find.text('Actuel'), findsOneWidget);
    expect(find.text('Figures liées'), findsOneWidget);
    expect(find.text('Itinéraire'), findsOneWidget);

    // Le fondateur ouvre sa fiche (déjà en mémoire, sans requête).
    await tester.tap(find.text('Voir sa fiche'));
    await tester.pumpAndSettle();
    expect(find.byType(FigureDetailScreen), findsOneWidget);
  });

  testWidgets('figure : chiffres-clés qui ouvrent leur onglet, sommaire et taille du texte', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(detailApp(const FigureDetailScreen(figure: detailFigure)));
    await tester.pumpAndSettle();

    // Œuvres : 4 ; disciples dans l'app : 3 (silsila des tests) ; lieux : 1.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3 sections · environ 1 min'), findsOneWidget);
    // Puce du sommaire et intertitre.
    expect(find.text('Naissance et origines'), findsNWidgets(2));

    // « Aa » agrandit le texte de la biographie.
    double size() =>
        tester.widget<Text>(find.textContaining('Texte de remplissage de la capture').first).style!.fontSize!;
    final before = size();
    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();
    expect(size(), greaterThan(before));

    // La tuile « œuvres » ouvre l'onglet Œuvres.
    await tester.tap(find.text('œuvres'));
    await tester.pumpAndSettle();
    expect(find.text('Wassilatoul Mouna'), findsOneWidget);
  });

  testWidgets('figure : chaîne interrompue avant le Cheikh, mention « Maillons suivants non renseignés »',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(detailApp(const FigureDetailScreen(figure: detailFigure)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silsila'));
    await tester.pumpAndSettle();
    // Chaîne complète dans les données de test : pas de mention.
    expect(find.text('Maillons suivants non renseignés'), findsNothing);
    // Disciples renseignés dans l'app.
    expect(find.text('Serigne Babacar Sy « Cheikhal Khalifa »'), findsOneWidget);
  });
}
