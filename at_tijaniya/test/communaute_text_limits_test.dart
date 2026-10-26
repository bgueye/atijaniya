// Audit Communauté du 2026-10-26 (P2-1) : les champs de publication et de
// groupe portent les mêmes plafonds que les contraintes posées en base.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/validation/text_limits.dart';
import 'package:at_tijaniya/features/communaute/presentation/communaute_screen.dart';

import 'communaute_test_helpers.dart';

List<int?> _maxLengths(WidgetTester tester) =>
    tester.widgetList<TextField>(find.byType(TextField)).map((field) => field.maxLength).toList();

void main() {
  testWidgets('feuille de publication : 5 000 caractères au plus', (tester) async {
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    expect(_maxLengths(tester), [TextLimits.post]);
  });

  testWidgets('feuille de création de groupe : nom, description et région plafonnés', (tester) async {
    await tester.pumpWidget(wrapCommunaute(const Scaffold(body: CommunauteScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Groupes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton).last);
    await tester.pumpAndSettle();

    expect(_maxLengths(tester), [TextLimits.groupName, TextLimits.groupDescription, TextLimits.groupRegion]);
  });
}
