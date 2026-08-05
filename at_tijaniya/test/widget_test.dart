// Smoke test de démarrage de l'app : vérifie que le Splash screen s'affiche
// bien en tout premier (fond zaytoune) sans lever d'exception, sans
// dépendre de l'initialisation Supabase (faite dans main(), pas dans
// AtTijaniyaApp).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/app.dart';
import 'package:at_tijaniya/core/theme/app_colors.dart';

void main() {
  testWidgets('Le Splash screen s\'affiche au démarrage', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AtTijaniyaApp()));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppColors.zaytoune);

    // Le Splash screen programme un Future.delayed(1600ms) pour avancer
    // automatiquement vers l'écran de langue : le vider évite un timer
    // encore pendant à la fin du test.
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
