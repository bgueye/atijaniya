// Vérifie le champ d'envoi partagé par la messagerie privée, la discussion
// de groupe et le chat d'un direct (`MessageComposer`) : les défauts relevés
// par l'audit du 2026-10-04 — double envoi, échec muet, texte perdu — ne
// doivent pas revenir.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/widgets/message_composer.dart';

Widget _wrap(Future<void> Function(String) onSend) {
  return MaterialApp(
    home: Scaffold(
      body: MessageComposer(
        hintText: 'Écrire un message',
        sendTooltip: 'Envoyer',
        errorMessage: "Le message n'a pas pu être envoyé.",
        onSend: onSend,
      ),
    ),
  );
}

void main() {
  testWidgets('envoie le texte sans les espaces autour et vide le champ', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_wrap((text) async => sent.add(text)));

    await tester.enterText(find.byType(TextField), '  Salam  ');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(sent, ['Salam']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets("n'envoie rien pour un message vide", (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_wrap((text) async => sent.add(text)));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  testWidgets("un second appui pendant l'envoi n'envoie pas deux fois", (tester) async {
    final sent = <String>[];
    final gate = Completer<void>();
    await tester.pumpWidget(_wrap((text) async {
      sent.add(text);
      await gate.future;
    }));

    await tester.enterText(find.byType(TextField), 'Salam');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    // Le bouton est inerte tant que le premier envoi n'est pas terminé.
    await tester.tap(find.byTooltip('Envoyer'), warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();
    expect(sent, ['Salam']);
  });

  testWidgets('en cas d\'échec, affiche l\'erreur et rend le texte', (tester) async {
    await tester.pumpWidget(_wrap((text) async => throw Exception('réseau')));

    await tester.enterText(find.byType(TextField), 'Salam');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.text("Le message n'a pas pu être envoyé."), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Salam');
  });
}
