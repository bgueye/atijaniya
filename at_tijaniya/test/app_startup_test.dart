// Audit de l'accueil du 2026-10-26 (P2-1) : la langue est enregistrée, et
// l'écran de choix de langue n'apparaît plus qu'au premier lancement ; le
// splash n'impose plus d'attente fixe de 1,6 s.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/app.dart';
import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/core/theme/locale_controller.dart';
import 'package:at_tijaniya/features/auth/presentation/auth_screen.dart';
import 'package:at_tijaniya/features/figures/presentation/figures_providers.dart';
import 'package:at_tijaniya/features/home/presentation/home_shell.dart';
import 'package:at_tijaniya/features/khadara/presentation/khadara_providers.dart';
import 'package:at_tijaniya/features/onboarding/presentation/language_selection_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';

Widget _app({Locale? savedLocale, String? userId}) {
  return ProviderScope(
    overrides: [
      initialLocaleProvider.overrideWithValue(savedLocale),
      currentUserIdProvider.overrideWithValue(userId),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 26, 9, 0)),
      upcomingEventsProvider.overrideWith((ref) async => const []),
      featuredFigureProvider.overrideWith((ref) async => null),
    ],
    child: const AtTijaniyaApp(),
  );
}

void main() {
  test('la langue choisie est enregistrée et relue', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await LocaleStore.load(), isNull);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(localeControllerProvider.notifier).setLocale(const Locale('ar'));
    await Future<void>.delayed(Duration.zero);
    expect(await LocaleStore.load(), const Locale('ar'));
  });

  test('valeur enregistrée inconnue : ignorée', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    expect(await LocaleStore.load(), isNull);
  });

  testWidgets('premier lancement : écran de langue après un splash court', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
  });

  testWidgets('langue connue, invité : connexion directement, sans écran de langue', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await tester.pumpWidget(_app(savedLocale: const Locale('fr')));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('langue connue, compte connecté : accueil directement', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    await tester.pumpWidget(_app(savedLocale: const Locale('ar'), userId: 'me'));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSelectionScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
