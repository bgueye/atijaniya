// Vérifie l'écran "Historique" d'un wird (présentation revue le 2026-10-06) :
// invitation claire tant qu'aucune récitation n'existe, série et "N sur M"
// ensuite — sans pourcentage —, et variante hebdomadaire de Hadratou-l-Jouma.
// Les wirds viennent du corpus validé ; aucun texte religieux n'est écrit ici.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/calendar_days.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_history_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Wird wird, {Locale locale = const Locale('fr')}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: WirdHistoryScreen(wird: wird),
    ),
  );
}

String _format(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Enregistre des récitations sous la clé du compte "invité" (Supabase n'est
/// pas initialisé dans les tests, voir `user_scoped_prefs.dart`).
void _seed(Wird wird, List<DateTime> dates) {
  SharedPreferences.setMockInitialValues({
    'wird_completions_${wird.id}::guest': dates.map(_format).toList(),
  });
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Écran de téléphone, assez haut pour que la liste construise tout son
  // contenu (une `ListView` ne construit que ce qui est visible).
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(400, 1400);
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  });

  testWidgets("sans aucune récitation, explique comment marquer une journée", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text(lazim.nameArabic), findsOneWidget);
    expect(find.text("Aucune récitation enregistrée pour l'instant"), findsOneWidget);
    expect(find.text("Terminez le wird au Tasbih pour qu'il soit marqué ici."), findsOneWidget);
    // Ni série à zéro ni taux tant qu'il n'y a rien à compter.
    expect(find.text("jours d'affilée"), findsNothing);
    expect(find.text('Jours pratiqués'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trois premiers jours faits : série de 3 et « 3 sur 3 », sans pourcentage', (tester) async {
    // Les annonces des cases ne sont calculées que si un lecteur d'écran est actif.
    final semantics = tester.ensureSemantics();
    _seed(lazim, [addDays(today, -2), addDays(today, -1), today]);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    expect(find.text("jours d'affilée"), findsOneWidget);
    expect(find.text('Jours pratiqués'), findsOneWidget);
    expect(find.text('3 sur 3'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    // 5 semaines entières : 35 cases, plus la série et le total.
    expect(find.bySemanticsLabel(RegExp(r', Fait$')), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets("un jour manqué et la journée en cours sont annoncés différemment", (tester) async {
    // Les annonces des cases ne sont calculées que si un lecteur d'écran est actif.
    final semantics = tester.ensureSemantics();
    _seed(lazim, [addDays(today, -2)]);
    await tester.pumpWidget(_wrap(lazim));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r', Manqué$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r', Pas encore fait$')), findsOneWidget);
    expect(find.text('1 sur 2'), findsOneWidget);
    // Série rompue par la veille manquée : singulier.
    expect(find.text("jour d'affilée"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Hadratou-l-Jouma : huit vendredis et libellés hebdomadaires', (tester) async {
    final lastFriday = addDays(today, -((today.weekday - DateTime.friday) % 7));
    // Les annonces des cases ne sont calculées que si un lecteur d'écran est actif.
    final semantics = tester.ensureSemantics();
    _seed(hadratouJouma, [addDays(lastFriday, -7), lastFriday]);
    await tester.pumpWidget(_wrap(hadratouJouma));
    await tester.pumpAndSettle();

    expect(find.text("vendredis d'affilée"), findsOneWidget);
    expect(find.text('Vendredis pratiqués'), findsOneWidget);
    expect(find.text('2 sur 2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^vendredi .*, Fait$')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets("s'affiche en arabe, de droite à gauche, sans débordement sur un petit écran", (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    _seed(hadratouJouma, [addDays(today, -((today.weekday - DateTime.friday) % 7))]);
    await tester.pumpWidget(_wrap(hadratouJouma, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    _seed(lazim, [addDays(today, -40), today]);
    await tester.pumpWidget(_wrap(lazim, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l10n.wirdHistoryHeading), findsOneWidget);
    expect(find.text(l10n.wirdHistoryDaysPractised), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
