// Audit de l'authentification du 2026-10-27 (P1-2) : la feuille « Modifier
// le profil » débordait avec le texte à 200 % sur 360 dp, et le bouton
// Enregistrer sortait de l'écran clavier ouvert.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';
import 'package:at_tijaniya/features/profil/presentation/edit_profile_sheet.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _app(Locale locale, double keyboard) {
  return ProviderScope(
    overrides: [attachableZawiyasProvider.overrideWith((ref) async => const [])],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2.0),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showEditProfileSheet(
                context,
                const Profile(userId: 'u', displayName: 'Bocar', locale: 'fr', bio: 'Une bio'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final locale in const [Locale('fr'), Locale('ar')]) {
    for (final keyboard in const [0.0, 300.0]) {
      testWidgets('texte à 200 % sur 360 dp (${locale.languageCode}, clavier $keyboard) : Enregistrer atteignable',
          (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(locale, keyboard));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final save = find.byType(ElevatedButton);
        await tester.scrollUntilVisible(save, 100, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
        final rect = tester.getRect(save);
        expect(rect.bottom, lessThanOrEqualTo(740 - keyboard));
      });
    }
  }
}
