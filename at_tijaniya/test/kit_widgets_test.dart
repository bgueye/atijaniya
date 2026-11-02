// Composants communs du kit (docs/kit/, lib/core/widgets/, 2026-11-02) :
// vérifie les règles de chaque fiche qui se testent sans regarder l'écran —
// titres annoncés, cibles de 48 dp, état « choisi » lu par le lecteur
// d'écran, coche et nombre des pastilles, « ~ » d'une date approximative,
// sens de lecture en arabe, couleurs fixes des bandeaux de wird.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/theme/app_theme.dart';
import 'package:at_tijaniya/core/widgets/app_buttons.dart';
import 'package:at_tijaniya/core/widgets/content_sheet.dart';
import 'package:at_tijaniya/core/widgets/date_block.dart';
import 'package:at_tijaniya/core/widgets/eyebrow.dart';
import 'package:at_tijaniya/core/widgets/filter_chips.dart';
import 'package:at_tijaniya/core/widgets/list_group.dart';
import 'package:at_tijaniya/core/widgets/network_section.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/core/widgets/segmented_switch.dart';
import 'package:at_tijaniya/core/widgets/stat_tile.dart';
import 'package:at_tijaniya/core/widgets/state_pill.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_band.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('fr')}) {
  return MaterialApp(
    theme: AppTheme.standard,
    locale: locale,
    supportedLocales: const [Locale('fr'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('Eyebrow', () {
    testWidgets('met le texte en capitales, en encre secondaire sur fond clair, en or sur zaytoune', (tester) async {
      await tester
          .pumpWidget(_wrap(const Column(children: [Eyebrow('Prochaine étape'), Eyebrow('Fondateur', onDark: true)])));

      expect(find.text('PROCHAINE ÉTAPE'), findsOneWidget);
      final light = tester.widget<Text>(find.text('PROCHAINE ÉTAPE'));
      final dark = tester.widget<Text>(find.text('FONDATEUR'));
      expect(light.style!.color, AppColors.secondaryInk);
      expect(dark.style!.color, AppColors.goldOnDark);
      expect(light.style!.fontSize, 10.5);
    });
  });

  group('SectionTitle', () {
    testWidgets('est annoncé comme titre et son lien fait 48 dp de haut', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(SectionTitle('À venir', actionLabel: 'Tout voir', onAction: () => tapped = true)));

      expect(tester.getSemantics(find.text('À venir')), isSemantics(isHeader: true));
      expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Tout voir'));
      expect(tapped, isTrue);
    });

    testWidgets('sans action, pas de lien', (tester) async {
      await tester.pumpWidget(_wrap(const SectionTitle('À venir', actionLabel: 'Tout voir')));
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('FilterChips', () {
    testWidgets('choix unique, état « choisi » annoncé, cible de 48 dp, nombre facultatif', (tester) async {
      var selected = 'all';
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => FilterChips<String>(
          items: const [
            FilterChipItem(value: 'all', label: 'Tous'),
            FilterChipItem(value: 'zawiya', label: 'Zawiyas', count: 34),
          ],
          selected: selected,
          onSelected: (value) => setState(() => selected = value),
        ),
      )));

      expect(find.text('Zawiyas 34'), findsOneWidget);
      expect(tester.getSemantics(find.text('Tous')), isSemantics(isSelected: true, isButton: true));
      expect(tester.getSize(find.byType(FilterPill).first).height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Zawiyas 34'));
      await tester.pumpAndSettle();
      expect(selected, 'zawiya');
      expect(tester.getSemantics(find.text('Tous')), isSemantics(isSelected: false));
    });
  });

  group('DateBlock', () {
    testWidgets('jour, mois abrégé en capitales et « ~ » pour une date approximative', (tester) async {
      await tester.pumpWidget(_wrap(DateBlock(date: DateTime(2026, 12, 25), approximate: true)));
      await tester.pumpAndSettle();

      expect(find.text('~25'), findsOneWidget);
      expect(find.text('DÉC.'), findsOneWidget);
      expect(tester.getSemantics(find.byType(DateBlock)).label, '~25 DÉC.');
    });

    testWidgets('en arabe, le « ~ » reste devant le jour, en chiffres latins', (tester) async {
      await tester
          .pumpWidget(_wrap(DateBlock(date: DateTime(2026, 12, 25), approximate: true), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final day = tester.widget<Text>(find.text('~25'));
      expect(day.textDirection, TextDirection.ltr);
    });
  });

  group('StatePill', () {
    testWidgets('« done » porte une coche, « count » affiche le nombre avec ce qu\'il compte', (tester) async {
      await tester.pumpWidget(_wrap(const Row(children: [
        StatePill('Fait ce matin', variant: StatePillVariant.done),
        StatePill.count(2, semanticsLabel: '2 messages non lus'),
        StatePill('Privée'),
      ])));

      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.bySemanticsLabel('2 messages non lus'), findsOneWidget);
      expect(find.text('Privée'), findsOneWidget);
    });
  });

  group('StatTile', () {
    testWidgets('lit le nombre et sa légende d\'un seul tenant', (tester) async {
      await tester.pumpWidget(_wrap(const StatTile(value: '7', label: 'jours de suite', dark: true)));
      expect(find.bySemanticsLabel('7 jours de suite'), findsOneWidget);
      expect(tester.widget<Text>(find.text('7')).style!.color, AppColors.goldOnDark);
    });
  });

  group('SegmentedSwitch', () {
    testWidgets('bascule de vue, vue active annoncée, 48 dp avec la gouttière', (tester) async {
      var view = 0;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => SegmentedSwitch<int>(
          items: const [
            SegmentedSwitchItem(value: 0, label: 'Lieux', count: 34),
            SegmentedSwitchItem(value: 1, label: 'Agenda', count: 17),
            SegmentedSwitchItem(value: 2, label: 'Messages', unread: 2, unreadLabel: '2 messages non lus'),
          ],
          selected: view,
          onChanged: (value) => setState(() => view = value),
        ),
      )));

      expect(tester.getSize(find.byType(SegmentedSwitch<int>)).height, greaterThanOrEqualTo(48));
      // Le nombre de non-lus est lu avec la vue qui le porte, pas « 2 » seul.
      expect(find.bySemanticsLabel(RegExp('Messages.*2 messages non lus', dotAll: true)), findsOneWidget);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(view, 1);
      expect(tester.getSemantics(find.text('Agenda')), isSemantics(isSelected: true, isButton: true));
    });

    test('refuse plus de trois vues', () {
      expect(
        () => SegmentedSwitch<int>(
          items: [for (var i = 0; i < 4; i++) SegmentedSwitchItem(value: i, label: '$i')],
          selected: 0,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });
  });

  group('ListGroup', () {
    testWidgets('lignes de 48 dp au moins, chevron quand la ligne mène quelque part', (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrap(ListGroup(items: [
        ListGroupItem(
          icon: Icons.account_tree_outlined,
          title: 'Ma lignée spirituelle',
          subtitle: 'Renseignée',
          tone: ListGroupTone.sacred,
          trailing: const StatePill('Privée'),
          onTap: () => opened = true,
        ),
        ListGroupItem(icon: Icons.contrast, title: 'Contraste renforcé', tone: ListGroupTone.neutral, onTap: () {}),
      ])));

      expect(tester.getSize(find.byType(InkWell).first).height, greaterThanOrEqualTo(48));
      // Une seule ligne sans élément de fin : un seul chevron.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('Ma lignée spirituelle'));
      expect(opened, isTrue);
    });
  });

  group('Notice', () {
    testWidgets('information en émeraude doux, erreur hors ligne avec « Réessayer »', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(Column(children: [
        const Notice.info('Aucun évènement annoncé pour le moment.'),
        Notice.error('Impossible de charger.', offline: true, onRetry: () => retried = true),
      ])));

      expect(find.text('Aucun évènement annoncé pour le moment.'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      // Hors ligne : le message commun prime sur celui de la section.
      expect(find.text('Impossible de charger.'), findsNothing);
      expect(find.textContaining('Pas de connexion internet'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retried, isTrue);
    });

    testWidgets('NetworkSection garde le dernier contenu reçu, avec une mention', (tester) async {
      // Erreur d'une mise à jour après un premier contenu reçu.
      final failed = const AsyncValue<String>.error(SocketException('hors ligne'), StackTrace.empty)
          .copyWithPrevious(const AsyncValue<String>.data('Contenu'));
      await tester.pumpWidget(_wrap(NetworkSection<String>(
        value: failed,
        placeholderHeight: 40,
        errorMessage: 'Erreur',
        onRetry: () {},
        builder: (value) => Text(value),
      )));

      expect(find.text('Contenu'), findsOneWidget);
      expect(find.text('Hors ligne : dernières informations reçues.'), findsOneWidget);
    });
  });

  group('showContentSheet', () {
    testWidgets('montre étiquette, contenu et source ; « Ouvrir la page complète » ferme puis agit', (tester) async {
      var opened = false;
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => showContentSheet(
            context,
            eyebrow: 'Situation · Erreur',
            source: 'Source : Jawahir al-Maani',
            onOpenFullPage: () => opened = true,
            children: const [Text('Réponse entière')],
          ),
          child: const Text('ouvrir'),
        ),
      )));

      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('SITUATION · ERREUR'), findsOneWidget);
      expect(find.text('Réponse entière'), findsOneWidget);
      final source = tester.widget<Text>(find.text('Source : Jawahir al-Maani'));
      expect(source.style!.fontStyle, FontStyle.italic);

      await tester.tap(find.text('Ouvrir la page complète'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(find.text('Réponse entière'), findsNothing);
    });
  });

  group('Boutons', () {
    testWidgets('le thème donne 48 dp aux boutons plein, contour et texte', (tester) async {
      await tester.pumpWidget(_wrap(Wrap(children: [
        FilledButton(onPressed: () {}, child: const Text('Commencer')),
        OutlinedButton(onPressed: () {}, child: const Text('Guide')),
        TextButton(onPressed: () {}, child: const Text('Fermer')),
        DangerLinkButton(label: 'Supprimer mon compte', onPressed: () {}),
      ])));

      for (final type in [FilledButton, OutlinedButton]) {
        expect(tester.getSize(find.byType(type)).height, greaterThanOrEqualTo(48), reason: '$type');
      }
      expect(tester.getSize(find.widgetWithText(TextButton, 'Fermer')).height, greaterThanOrEqualTo(48));
      final danger = tester.widget<Text>(find.text('Supprimer mon compte'));
      final rendered = tester.renderObject<RenderParagraph>(find.text('Supprimer mon compte'));
      expect(danger.data, 'Supprimer mon compte');
      expect(rendered.text.style!.color, AppColors.danger);
    });
  });

  group('WirdBand', () {
    testWidgets('couleur fixe par wird et noms tirés du corpus validé', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [
        WirdBand(wird: lazim),
        WirdBand(wird: wazifa),
        WirdBand(wird: hadratouJouma),
      ])));

      expect(wirdBandColors(lazim.id).background, AppColors.zaytoune);
      expect(wirdBandColors(wazifa.id).background, AppColors.emerald);
      expect(wirdBandColors(hadratouJouma.id).background, AppColors.goldSoft);
      expect(wirdBandColors(hadratouJouma.id).foreground, AppColors.ink);
      for (final wird in [lazim, wazifa, hadratouJouma]) {
        expect(find.text(wird.nameFrench), findsOneWidget);
        expect(find.text(wird.nameArabic), findsOneWidget);
      }
      expect(find.text('Quotidien'), findsNWidgets(2));
      expect(find.text('Hebdomadaire — vendredi'), findsOneWidget);
    });
  });
}
