// Vérifie la gestion des maillons manuels de « Ma silsila d'ijaza » (depuis
// le 2026-10-17 ; avant, un maillon enregistré ne pouvait plus être corrigé
// ni retiré) : lecture d'une ligne, liste des maillons saisis, modification
// (la marque « Cheikh Ahmed Tijani » réservée au dernier maillon) et retrait
// après confirmation — avec un dépôt factice, sans Supabase.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/mouqaddam/data/mouqaddam_repository.dart';
import 'package:at_tijaniya/features/mouqaddam/domain/mouqaddam_models.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/ijaza_chain_screen.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

/// Enregistre les appels au lieu de joindre Supabase.
class _FakeRepository extends MouqaddamRepository {
  final updates = <({String id, String nameText, String? yearText, bool isUltimateSource})>[];
  final deletions = <String>[];

  @override
  Future<void> updateManualChainLink(
    String id, {
    required String nameText,
    String? yearText,
    required bool isUltimateSource,
  }) async {
    updates.add((id: id, nameText: nameText, yearText: yearText, isUltimateSource: isUltimateSource));
  }

  @override
  Future<void> deleteManualChainLink(String id) async => deletions.add(id);
}

const _links = [
  ManualChainLink(id: 'l1', orderIndex: 1, nameText: 'Premier maillon', yearText: '1950', isUltimateSource: false),
  ManualChainLink(id: 'l2', orderIndex: 2, nameText: 'Doublon saisi', isUltimateSource: false),
];

Widget _wrap(_FakeRepository repository) {
  return ProviderScope(
    overrides: [
      mouqaddamRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('moi'),
      // Chaîne vide : le compte est au sommet de sa chaîne, donc gère son
      // complément manuel ; pas d'animation de révélation à jouer.
      myIjazaChainProvider.overrideWith((ref) async => const <IjazaChainLink>[]),
      myManualChainLinksProvider.overrideWith((ref) async => _links),
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
      home: IjazaChainScreen(),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester, int index) async {
  await tester.tap(find.byTooltip('Modifier ou retirer ce maillon').at(index));
  await tester.pumpAndSettle();
}

void main() {
  test('ManualChainLink.fromRow lit une ligne de la table', () {
    final link = ManualChainLink.fromRow({
      'id': 'x',
      'order_index': 3,
      'name_text': 'Nom',
      'year_text': null,
      'is_ultimate_source': true,
    });
    expect(link.id, 'x');
    expect(link.orderIndex, 3);
    expect(link.yearText, isNull);
    expect(link.isUltimateSource, isTrue);
  });

  testWidgets('liste les maillons saisis avec leur menu', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Maillons que vous avez saisis'), findsOneWidget);
    expect(find.text('Premier maillon'), findsOneWidget);
    expect(find.text('1950'), findsOneWidget);
    expect(find.byTooltip('Modifier ou retirer ce maillon'), findsNWidgets(2));

    await _openMenu(tester, 0);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Retirer'), findsOneWidget);
  });

  testWidgets('modifier un maillon qui n\'est pas le dernier : pas de case « Cheikh Ahmed Tijani »', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _openMenu(tester, 0);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget, reason: 'seule celle du formulaire d\'ajout');
    await tester.enterText(find.widgetWithText(TextFormField, 'Premier maillon'), 'Premier maillon corrigé');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updates, hasLength(1));
    expect(repository.updates.single.id, 'l1');
    expect(repository.updates.single.nameText, 'Premier maillon corrigé');
    expect(repository.updates.single.yearText, '1950');
    expect(repository.updates.single.isUltimateSource, isFalse);
    expect(find.text('Maillon modifié.'), findsOneWidget);
  });

  testWidgets('le dernier maillon peut être marqué « Cheikh Ahmed Tijani »', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _openMenu(tester, 1);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    final dialogCheckbox = find.descendant(of: find.byType(AlertDialog), matching: find.byType(CheckboxListTile));
    expect(dialogCheckbox, findsOneWidget);
    await tester.tap(dialogCheckbox);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updates.single.id, 'l2');
    expect(repository.updates.single.isUltimateSource, isTrue);
  });

  testWidgets('un nom vide est refusé', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _openMenu(tester, 0);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Premier maillon'), '  ');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updates, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('retirer demande confirmation, et annuler ne retire rien', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await _openMenu(tester, 1);
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    expect(find.text('Retirer ce maillon ?'), findsOneWidget);
    expect(find.textContaining('« Doublon saisi »'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repository.deletions, isEmpty);

    await _openMenu(tester, 1);
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Retirer')));
    await tester.pumpAndSettle();

    expect(repository.deletions, ['l2']);
    expect(find.text('Maillon retiré.'), findsOneWidget);
  });
}
