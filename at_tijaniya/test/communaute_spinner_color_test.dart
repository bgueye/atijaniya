// Audit Communauté du 2026-10-26 (P3-5) : l'indicateur d'envoi d'un bouton
// désactivé était blanc, invisible sur le gris du bouton.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';

import 'communaute_test_helpers.dart';

void main() {
  testWidgets("publication en cours d'envoi : indicateur émeraude", (tester) async {
    final gate = Completer<void>();
    final repo = FakeCommunityRepository()..gate = gate.future;
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen()), community: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Salam');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Publier'));
    await tester.pump();

    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(of: find.byType(ElevatedButton), matching: find.byType(CircularProgressIndicator)),
    );
    expect(spinner.color, AppColors.emerald);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
