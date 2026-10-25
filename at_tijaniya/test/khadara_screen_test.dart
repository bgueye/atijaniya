// Onglet Zawiyas, sous-onglet Annuaire — premier test d'écran, ajouté avec
// les corrections de l'audit Zawiyas du 2026-10-25. Lieux factices, locaux au
// test.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

const _zawiyas = [
  Zawiya(id: 'a', name: 'Zawiya de Médina Baye (Kaolack)', addressText: 'Médina Baye, Kaolack, Sénégal'),
  Zawiya(id: 'b', name: 'Zawiya de Ségou (Mali)', addressText: 'Ségou, Mali'),
  Zawiya(id: 'c', name: 'Lieu saint de test', kind: ZawiyaKind.holyPlace, addressText: 'Village de test, Sénégal'),
];

// `isAdminProvider` et `zawiyasProvider` surchargés : leurs valeurs par
// défaut appellent Supabase, non initialisé dans ce test.
Widget _wrap({Locale locale = const Locale('fr'), double textScale = 1.0}) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(false),
      zawiyasProvider.overrideWith((ref) async => _zawiyas),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: KhadaraScreen()),
    ),
  );
}

void main() {
  // Audit Zawiyas du 2026-10-25 (P2-1) : recherche par nom ou adresse,
  // combinée au filtre par type.
  testWidgets("la recherche filtre l'annuaire par nom ou par adresse", (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kaolack');
    await tester.pump();
    expect(find.text('Zawiya de Médina Baye (Kaolack)'), findsOneWidget);
    expect(find.text('Zawiya de Ségou (Mali)'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump();
    expect(find.text('Aucun lieu ne correspond à « introuvable ».'), findsOneWidget);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(find.text('Zawiya de Ségou (Mali)'), findsOneWidget);
  });

  testWidgets('la recherche se combine au filtre par type', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'senegal');
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lieux saints'));
    await tester.pump();
    expect(find.text('Lieu saint de test'), findsOneWidget);
    expect(find.text('Zawiya de Médina Baye (Kaolack)'), findsNothing);
  });
}
