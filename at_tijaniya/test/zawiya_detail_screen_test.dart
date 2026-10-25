// Fiche d'un lieu de l'annuaire (onglet Zawiyas) — premier test d'écran,
// ajouté avec les corrections de l'audit Zawiyas du 2026-10-25. Lieux
// factices, locaux au test.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/khadara/domain/khadara_models.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/khadara/presentation/zawiya_detail_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

// `isAdminProvider` et `upcomingEventsProvider` surchargés : leurs valeurs
// par défaut appellent Supabase, non initialisé dans ce test.
Widget _wrap(
  Widget child, {
  double textScale = 1.0,
  Locale locale = const Locale('fr'),
  bool isAdmin = false,
  List<KhadaraEvent> events = const [],
}) {
  return ProviderScope(
    overrides: [
      isAdminProvider.overrideWithValue(isAdmin),
      upcomingEventsProvider.overrideWith((ref) async => events),
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
      home: child,
    ),
  );
}

const _zawiya = Zawiya(
  id: 'z1',
  name: 'Zawiya de test',
  latitude: 14.7,
  longitude: -17.4,
  addressText: 'Quartier de test, ville de test',
  contactInfo: '+221 00 000 00 00',
);

void main() {
  // Audit Zawiyas du 2026-10-25 (P1) : l'adresse et le contact passaient par
  // un `RichText`, qui ignorait la taille de texte des réglages.
  testWidgets('l\'adresse et le contact suivent la taille du texte', (tester) async {
    await tester.pumpWidget(_wrap(const ZawiyaDetailScreen(zawiya: _zawiya), textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final value in ['Quartier de test, ville de test', '+221 00 000 00 00', 'Adresse', 'Contact']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(value), matching: find.byType(RichText)),
      );
      expect(paragraph.textScaler, const TextScaler.linear(2.0), reason: value);
    }
  });
}
