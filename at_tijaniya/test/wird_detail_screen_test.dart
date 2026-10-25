// Accessibilité du guide d'un wird : les boutons audio des piliers doivent
// être annoncés et offrir la zone tactile minimale d'Android (audit du
// 2026-10-25). Sans Supabase dans les tests, aucune récitation n'est
// trouvée : chaque pilier affiche l'état « pas encore de récitation ».

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_detail_screen.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('fr')}) {
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
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    testWidgets('piliers sans récitation annoncés comme tels (${locale.languageCode})', (tester) async {
      final handle = tester.ensureSemantics();
      final lazim = validatedWirds.firstWhere((w) => w.id == 'lazim');
      await tester.pumpWidget(_wrap(WirdDetailScreen(wird: lazim), locale: locale));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(locale);
      expect(find.bySemanticsLabel(l10n.wirdAudioPillarUnavailable), findsWidgets);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }
}
