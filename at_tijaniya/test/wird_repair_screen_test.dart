// Vérifie l'écran « Rattraper son wird » et sa carte d'accès dans l'écran
// Wirds, avec un contenu fourni directement (sans Supabase) :
// - la carte n'existe que s'il y a du contenu (un disciple ne voit rien tant
//   que le moqaddam référent n'a pas validé), et rappelle le brouillon ;
// - l'écran affiche la réponse rapide du wird choisi, ses cas et les règles
//   communes, filtre par type de situation, et passe en lecture complète ;
// - le bandeau de brouillon n'apparaît que s'il reste du brouillon ;
// - en arabe, c'est le texte arabe de la base qui s'affiche.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/wird/domain/wird_repair_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_list_screen.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_repair_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child, {required WirdRepairContent content, Locale locale = const Locale('fr')}) {
  return ProviderScope(
    overrides: [
      wirdRepairContentProvider.overrideWith((ref) async => content),
      isAdminProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

WirdRepairCase _case(int order, RepairWird wird, RepairKind kind, String situation, {bool valid = true}) {
  return WirdRepairCase(
    id: 'case-$order',
    orderIndex: order,
    wird: wird,
    kind: kind,
    situationFr: situation,
    situationAr: 'حالة $order',
    actionFr: 'Action pour $situation',
    actionAr: 'عمل $order',
    sourceFr: 'Source $order',
    sourceAr: 'مصدر $order',
    isValid: valid,
  );
}

WirdRepairNote _note(RepairWird wird, RepairNoteType type, String textFr, {String textAr = 'نص', bool valid = true}) {
  return WirdRepairNote(
    id: 'note-${wird.name}-${type.name}',
    wird: wird,
    type: type,
    orderIndex: 1,
    textFr: textFr,
    textAr: textAr,
    isValid: valid,
  );
}

WirdRepairContent _content({bool withDraft = false}) {
  return WirdRepairContent(
    cases: [
      _case(1, RepairWird.all, RepairKind.erreur, 'Doute sur le nombre'),
      _case(2, RepairWird.lazim, RepairKind.manque, 'Lazim oublié', valid: !withDraft),
      _case(3, RepairWird.hadra, RepairKind.manque, 'Le temps est passé'),
    ],
    notes: [
      _note(RepairWird.all, RepairNoteType.intro, 'Intro commune'),
      _note(RepairWird.lazim, RepairNoteType.quickAnswer, 'Se rattrape', textAr: 'يُقضى'),
      _note(RepairWird.hadra, RepairNoteType.quickAnswer, 'Ne se rattrape pas'),
      _note(RepairWird.all, RepairNoteType.askMoqaddam, 'Une longue série de jours manqués.'),
    ],
  );
}

void main() {
  group('carte de l\'écran Wirds', () {
    testWidgets('absente sans contenu (disciple, rien de validé)', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: WirdListScreen()), content: WirdRepairContent(cases: const [], notes: const [])));
      await tester.pumpAndSettle();
      expect(find.text('Rattraper son wird'), findsNothing);
    });

    testWidgets('présente avec du contenu, et mentionne le brouillon', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: WirdListScreen()), content: _content(withDraft: true)));
      await tester.pumpAndSettle();
      expect(find.text('Rattraper son wird'), findsOneWidget);
      expect(find.text('Oubli, erreur ou interruption (Brouillon)'), findsOneWidget);
    });
  });

  group('écran', () {
    testWidgets('montre la réponse du Lazim, ses cas et les règles communes', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content()));
      await tester.pumpAndSettle();

      expect(find.text('Se rattrape'), findsOneWidget);
      expect(find.text('Lazim oublié'), findsOneWidget);
      expect(find.text('Doute sur le nombre'), findsOneWidget);
      expect(find.text('Vaut pour tous les wirds'), findsOneWidget);
      expect(find.text('Le temps est passé'), findsNothing);
      expect(find.textContaining('Brouillon en attente'), findsNothing);
      // En bas de page : la liste ne construit pas ce qui est hors écran.
      await tester.scrollUntilVisible(find.text('Une longue série de jours manqués.'), 200);
      expect(find.text('Une longue série de jours manqués.'), findsOneWidget);
    });

    testWidgets('changer de wird change la réponse et les cas', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hadratou-l-Jouma'));
      await tester.pumpAndSettle();

      expect(find.text('Ne se rattrape pas'), findsOneWidget);
      expect(find.text('Le temps est passé'), findsOneWidget);
      expect(find.text('Lazim oublié'), findsNothing);
    });

    testWidgets('le filtre par type de situation, et son message quand rien ne correspond', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content()));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Erreur de nombre ou d'ordre"));
      await tester.pumpAndSettle();
      expect(find.text('Doute sur le nombre'), findsOneWidget);
      expect(find.text('Lazim oublié'), findsNothing);

      await tester.tap(find.text('Interruption'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun cas dans les sources pour cette combinaison. Demandez à votre moqaddam.'),
        findsOneWidget,
      );
    });

    testWidgets('« Tout lire » affiche toutes les sections à la suite', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tout lire'));
      await tester.pumpAndSettle();

      expect(find.text('Principes communs de réparation'), findsOneWidget);
      expect(find.text('Intro commune'), findsOneWidget);
      expect(find.text('Lazim oublié'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Le temps est passé'), 200);
      expect(find.text('Le temps est passé'), findsOneWidget);
      // Chaque règle a sa section : pas de mention « tous les wirds ».
      expect(find.text('Vaut pour tous les wirds'), findsNothing);
      expect(find.text('Par situation'), findsOneWidget);
    });

    testWidgets('bandeau de brouillon quand il en reste', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content(withDraft: true)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Brouillon en attente'), findsOneWidget);
    });

    testWidgets('en arabe, affiche le texte arabe de la base', (tester) async {
      await tester.pumpWidget(_wrap(const WirdRepairScreen(), content: _content(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('تدارك الورد'), findsOneWidget);
      expect(find.text('يُقضى'), findsOneWidget);
      expect(find.text('حالة 2'), findsOneWidget);
      expect(find.text('Lazim oublié'), findsNothing);
    });
  });
}
