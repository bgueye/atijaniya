// Profil refait le 2026-11-02 (`docs/maquettes/ecran-profil.html`), décisions
// validées : chiffres de pratique masquables, confidentialité résumée sur le
// Profil, « Devenir Mouqaddam » discret en dernière ligne, Paramètres absorbé
// (langue et contraste sur le Profil, aussi sans compte), administration à
// part, suppression du compte en lien séparé. Le nom du moqaddam n'est jamais
// affiché, seulement l'état de la lignée.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_theme.dart';
import 'package:at_tijaniya/core/widgets/dashed_border.dart';
import 'package:at_tijaniya/features/profil/presentation/practice_stats.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_overview.dart';
import 'package:at_tijaniya/features/wird/domain/wird_progress_stats.dart';

import 'profil_test_support.dart';
import 'wird_overview_fixtures.dart';

void main() {
  setUp(setUpProfilMocks);

  /// Fenêtre haute : tout le Profil construit d'un coup.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('chiffres de pratique : plus courte série quotidienne, wirds du mois, vendredis', () {
    final evening = sundayEvening();
    final stats = computePracticeStats(evening.entries, evening.now);
    // Lazim 7 jours, Wazifa 3 jours : la journée entière n'est tenue que depuis 3.
    expect(stats.dailyStreak, 3);
    // Novembre : seul le Lazim du 1er est marqué.
    expect(stats.monthCount, 1);
    expect(stats.fridayStreak, 1);
    final empty = [
      for (final w in validatedWirds)
        WirdOverviewEntry(
          wird: w,
          stats: computeWirdProgressStats(frequency: w.frequency, completionDates: const [], now: evening.now),
        ),
    ];
    expect(computePracticeStats(empty, evening.now), (dailyStreak: 0, monthCount: 0, fridayStreak: 0));
  });

  testWidgets('sans compte : ce qu\'un compte apporte, et la langue et le contraste réglables', (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.guest, theme: AppTheme.standard));
    await tester.pumpAndSettle();

    expect(find.text('Créez votre compte'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Langue'), findsOneWidget);
    expect(find.text('Contraste renforcé'), findsOneWidget);
    expect(find.text('Ma pratique'), findsNothing);
    expect(find.textContaining('séries'), findsNothing, reason: 'aucune promesse de séries rattachées au compte');
  });

  testWidgets('disciple : zawiya à choisir, lignée à renseigner, tout privé, Devenir Mouqaddam en dernier',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.disciple, theme: AppTheme.standard));
    await tester.pumpAndSettle();

    expect(find.text('Choisir ma zawiya'), findsOneWidget);
    expect(find.text('À renseigner'), findsOneWidget);
    expect(find.text('Après avoir renseigné votre lignée'), findsOneWidget);
    expect(find.text('Devenir Mouqaddam'), findsOneWidget);
    expect(find.text('Parrainage confirmé'), findsNothing);
    expect(find.text('Correspondances'), findsOneWidget);
    expect(find.text('Ma pratique'), findsOneWidget);
    expect(find.text('Administration'), findsNothing);
    // Jamais le contenu de la lignée.
    expect(find.text('exemple'), findsNothing);
  });

  testWidgets('parrainage confirmé : badge, demandes, silsila, disponible comme parrain', (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.mouqaddam, theme: AppTheme.standard));
    await tester.pumpAndSettle();

    expect(find.text('Parrainage confirmé'), findsOneWidget);
    expect(find.text('Zawiya de Tivaouane'), findsOneWidget);
    expect(find.text('Renseignée'), findsOneWidget);
    expect(find.text('Visible des condisciples'), findsOneWidget);
    expect(find.text('2 correspondances'), findsOneWidget);
    expect(find.text('Demandes de parrainage'), findsOneWidget);
    expect(find.text('1 en attente'), findsOneWidget);
    expect(find.text("Ma silsila d'ijaza"), findsOneWidget);
    expect(find.text('Disponible comme parrain'), findsOneWidget);
    expect(find.text('Devenir Mouqaddam'), findsNothing);
    expect(find.textContaining('érifié'), findsNothing);
    expect(find.text('exemple'), findsNothing);
  });

  testWidgets('admin : cadre d\'administration avec le nombre de signalements', (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.admin, theme: AppTheme.standard));
    await tester.pumpAndSettle();

    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Signalements'), findsOneWidget);
    expect(find.descendant(of: find.byType(DashedBorder), matching: find.text('3')), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('masquer les chiffres de pratique', (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.disciple, theme: AppTheme.standard));
    await tester.pumpAndSettle();
    expect(find.text('Ma pratique'), findsOneWidget);

    final row = find.ancestor(of: find.text('Afficher mes chiffres de pratique'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(find.text('Ma pratique'), findsNothing);
  });

  testWidgets('en arabe : sections et états traduits', (tester) async {
    tall(tester);
    await tester.pumpWidget(profilApp(ProfilState.mouqaddam, locale: const Locale('ar'), theme: AppTheme.standard));
    await tester.pumpAndSettle();
    expect(find.text('طريقي الروحي'), findsOneWidget);
    expect(find.text('ممارستي'), findsOneWidget);
    expect(find.text('التطبيق'), findsOneWidget);
  });
}
